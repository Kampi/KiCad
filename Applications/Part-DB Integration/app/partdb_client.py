# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Daniel Kampert <DanielKampert@kampis-elektroecke>
#
# This file is part of KiCad Part-DB Integration.
#
# KiCad Part-DB Integration is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# KiCad Part-DB Integration is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

"""HTTP client wrapper for the Part-DB REST API (API Platform / JSON-LD)."""

import base64
import logging
import os
from typing import Any, Dict, List, Optional

import requests

logger = logging.getLogger(__name__)

class PartDBError(Exception):
    """Raised when a Part-DB API call fails."""

class PartDBClient:
    """Thin client for the Part-DB REST API.

    Authentication is performed via a Bearer token which is included in
    every request header.  All write methods return the deserialized JSON
    response body.

    Args:
        base_url: Base URL of the Part-DB API, e.g.
            ``https://inventory.example.com/api``.
        api_key: API bearer token obtained from the Part-DB user settings.
    """

    def __init__(self, baseUrl: str, apiKey: str) -> None:
        self._base_url = baseUrl.rstrip("/")
        self._session = requests.Session()
        self._session.headers.update(
            {
                "Authorization": f"Bearer {api_key}",
                "Accept": "application/ld+json",
                "Content-Type": "application/ld+json",
            }
        )

    # ------------------------------------------------------------------
    # Low-level helpers
    # ------------------------------------------------------------------

    def _url(self, endpoint: str) -> str:
        return f"{self._base_url}{endpoint}"

    def _iriToUrl(self, iri: str) -> str:
        """Convert a full API IRI (e.g. /api/parts/1) to an absolute URL.

        self._base_url already contains the '/api' path segment.  Stripping
        it from the IRI avoids a duplicated '/api/api/…' path.
        """
        apiPrefix = "/api"
        if (iri.startswith(apiPrefix)):
            return f"{self._base_url}{iri[len(api_prefix):]}"
        return self._url(iri)

    def _get(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Any:
        try:
            response = self._session.get(self._url(endpoint), params = params)
            response.raise_for_status()
        except requests.HTTPError as exc:
            raise PartDBError(
                f"GET {endpoint} failed ({response.status_code}): {response.text}"
            ) from exc
        except requests.exceptions.ConnectionError as exc:
            raise PartDBError(
                f"GET {endpoint} failed: Cannot connect to Part-DB server. "
                f"Check 'api_url' in settings.json."
            ) from exc
        except requests.exceptions.RequestException as exc:
            raise PartDBError(f"GET {endpoint} failed: {exc}") from exc
        return response.json()

    def _postJson(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        try:
            response = self._session.post(self._url(endpoint), json = data)
            response.raise_for_status()
        except requests.HTTPError as exc:
            raise PartDBError(
                f"POST {endpoint} failed ({response.status_code}): {response.text}"
            ) from exc
        except requests.exceptions.ConnectionError as exc:
            raise PartDBError(
                f"POST {endpoint} failed: Cannot connect to Part-DB server. "
                f"Check 'api_url' in settings.json."
            ) from exc
        except requests.exceptions.RequestException as exc:
            raise PartDBError(f"POST {endpoint} failed: {exc}") from exc
        return response.json()

    def _postFileAsJson(
        self,
        endpoint: str,
        data: Dict[str, Any],
        filepath: str,
    ) -> Dict[str, Any]:
        """POST a file encoded as Base64 inside a JSON body.

        Part-DB expects file uploads via the ``upload`` field containing
        ``data`` (Base64-encoded file content) and ``filename``.
        """
        filename = os.path.basename(filepath)
        try:
            with open(filepath, "rb") as fh:
                encoded = base64.b64encode(fh.read()).decode("ascii")
        except OSError as exc:
            raise PartDBError(f"Could not read file '{filepath}': {exc}") from exc

        payload = {
            **data,
            "upload": {
                "data": encoded,
                "filename": filename,
            },
        }
        return self._postJson(endpoint, payload)

    def _getAll(
        self, endpoint: str, extraParams: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """Fetch all items from a paginated endpoint, following hydra pages."""
        params: Dict[str, Any] = {"page": 1, "itemsPerPage": 100}
        if (extraParams):
            params.update(extraParams)

        collected: List[Dict[str, Any]] = []
        while True:
            result = self._get(endpoint, params)

            if (isinstance(result, list)):
                collected.extend(result)
                break

            members = result.get("hydra:member", [])
            collected.extend(members)

            total = result.get("hydra:totalItems", len(collected))
            if (len(collected) >= total):
                break

            params["page"] += 1

        return collected

    # ------------------------------------------------------------------
    # Part categories
    # ------------------------------------------------------------------

    def getCategories(self) -> List[Dict[str, Any]]:
        """Return all existing part categories."""
        return self._getAll("/categories")

    def findOrCreateCategory(
        self, name: str, parentIri: Optional[str] = None
    ) -> str:
        """Return the IRI of a category, creating it if it does not exist.

        Args:
            name: Display name of the category.
            parent_iri: Optional IRI of a parent category.

        Returns:
            The ``@id`` IRI string of the category.
        """
        for cat in self.getCategories():
            if (cat.get("name", "").lower() == name.lower()):
                return cat["@id"]

        data: Dict[str, Any] = {"name": name}
        if (parentIri):
            data["parent"] = parentIri

        created = self._postJson("/categories", data)
        logger.debug("Created category '%s': %s", name, created["@id"])
        return created["@id"]

    # ------------------------------------------------------------------
    # Manufacturers
    # ------------------------------------------------------------------

    def getManufacturers(self) -> List[Dict[str, Any]]:
        """Return all existing manufacturers."""
        return self._getAll("/manufacturers")

    def findOrCreateManufacturer(self, name: str) -> str:
        """Return the IRI of a manufacturer, creating it if necessary.

        Args:
            name: Manufacturer name as it appears in the BOM.

        Returns:
            The ``@id`` IRI string.
        """
        for mfr in self.getManufacturers():
            if (mfr.get("name", "").lower() == name.lower()):
                return mfr["@id"]

        created = self._postJson("/manufacturers", {"name": name})
        logger.debug("Created manufacturer '%s': %s", name, created["@id"])
        return created["@id"]

    # ------------------------------------------------------------------
    # Footprints
    # ------------------------------------------------------------------

    def getFootprints(self) -> List[Dict[str, Any]]:
        """Return all existing footprints."""
        return self._getAll("/footprints")

    def findOrCreateFootprint(self, name: str) -> str:
        """Return the IRI of a footprint, creating it if necessary.

        Args:
            name: KiCad footprint name, e.g. ``C_0603_1608Metric``.

        Returns:
            The ``@id`` IRI string.
        """
        for fp in self.getFootprints():
            if (fp.get("name", "").lower() == name.lower()):
                return fp["@id"]

        created = self._postJson("/footprints", {"name": name})
        logger.debug("Created footprint '%s': %s", name, created["@id"])
        return created["@id"]

    # ------------------------------------------------------------------
    # Parts
    # ------------------------------------------------------------------

    def getParts(self) -> List[Dict[str, Any]]:
        """Return all existing parts."""
        return self._getAll("/parts")

    def createPart(
        self,
        name: str,
        description: str,
        categoryIri: str,
        manufacturerIri: Optional[str] = None,
        footprintIri: Optional[str] = None,
        mpn: Optional[str] = None,
        comment: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create a new part in Part-DB.

        Args:
            name: Part name (typically the manufacturer part number).
            description: Short description from the KiCad BOM.
            category_iri: IRI of the part category.
            manufacturer_iri: Optional IRI of the manufacturer.
            footprint_iri: Optional IRI of the KiCad footprint.
            mpn: Manufacturer part number stored in the
                ``manufacturerProductNumber`` field.
            comment: Optional markdown comment (e.g. datasheet URL).

        Returns:
            The created part dict including its ``@id``.
        """
        data: Dict[str, Any] = {
            "name": name,
            "description": description,
            "category": categoryIri,
        }
        if (manufacturerIri):
            data["manufacturer"] = manufacturerIri
        if (footprintIri):
            data["footprint"] = footprintIri
        if (mpn):
            data["manufacturer_product_number"] = mpn
        if (comment):
            data["comment"] = comment

        return self._postJson("/parts", data)

    def patchPart(self, partIri: str, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Update specific fields of an existing part via PATCH.

        Args:
            part_iri: The ``@id`` IRI of the part to update.
            fields: Dict of fields to set (partial update).

        Returns:
            The updated part dict.
        """
        headers = {
            k: v
            for k, v in self._session.headers.items()
            if k.lower() != "content-type"
        }
        headers["Content-Type"] = "application/merge-patch+json"
        try:
            response = self._session.patch(
                self._iriToUrl(partIri), json = fields, headers = headers
            )
            response.raise_for_status()
        except requests.HTTPError as exc:
            raise PartDBError(
                f"PATCH {part_iri} failed ({response.status_code}): {response.text}"
            ) from exc
        except requests.exceptions.ConnectionError as exc:
            raise PartDBError(
                f"PATCH {part_iri} failed: Cannot connect to Part-DB server."
            ) from exc
        except requests.exceptions.RequestException as exc:
            raise PartDBError(f"PATCH {part_iri} failed: {exc}") from exc
        return response.json()

    # ------------------------------------------------------------------
    # Projects
    # ------------------------------------------------------------------

    def getProjects(self) -> List[Dict[str, Any]]:
        """Return all existing projects."""
        return self._getAll("/projects")

    def findProjectByName(self, name: str) -> Optional[Dict[str, Any]]:
        """Find a project by exact name match.

        Args:
            name: Project name to look for.

        Returns:
            The project dict or ``None`` if not found.
        """
        for project in self.getProjects():
            if (project.get("name", "") == name):
                return project
        return None

    def createProject(
        self,
        name: str,
        description: str = "",
        parentIri: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create a new project (or sub-project) in Part-DB.

        Args:
            name: Display name of the project.
            description: Optional description text.
            parent_iri: IRI of the parent project for hierarchical projects.

        Returns:
            The created project dict including its ``@id``.
        """
        data: Dict[str, Any] = {
            "name": name,
            "description": description,
        }
        if (parentIri):
            data["parent"] = parentIri

        return self._postJson("/projects", data)

    # ------------------------------------------------------------------
    # Project BOM entries
    # ------------------------------------------------------------------

    def addBomEntry(
        self,
        projectIri: str,
        partIri: str,
        quantity: float,
        references: str = "",
        mountingType: int = 0,
    ) -> Dict[str, Any]:
        """Add a part as a BOM line item to a project.

        Args:
            project_iri: IRI of the target project (sub-project).
            part_iri: IRI of the part to link.
            quantity: Quantity required per PCB.
            references: Space-separated list of designator references.
            mounting_type: 0 = unspecified, 1 = SMD, 2 = THT.

        Returns:
            The created BOM entry dict.
        """
        return self._postJson(
            "/project_bom_entries",
            {
                "project": projectIri,
                "part": partIri,
                "quantity": quantity,
                "name": references,
                "mountingType": mountingType,
            },
        )

    # ------------------------------------------------------------------
    # Attachment types
    # ------------------------------------------------------------------

    def getAttachmentTypes(self) -> List[Dict[str, Any]]:
        """Return all existing attachment types."""
        return self._getAll("/attachment_types")

    def findOrCreateAttachmentType(self, name: str) -> str:
        """Return the IRI of an attachment type, creating it if necessary.

        Args:
            name: Attachment type name (e.g. ``"KiCad"``).

        Returns:
            The ``@id`` IRI string.
        """
        for atype in self.getAttachmentTypes():
            if (atype.get("name", "").lower() == name.lower()):
                return atype["@id"]

        created = self._postJson("/attachment_types", {"name": name})
        logger.debug("Created attachment type '%s': %s", name, created["@id"])
        return created["@id"]

    # ------------------------------------------------------------------
    # Attachments
    # ------------------------------------------------------------------

    def uploadAttachment(
        self,
        elementIri: str,
        attachmentTypeIri: str,
        name: str,
        filepath: str,
    ) -> Dict[str, Any]:
        """Upload a local file as an attachment to a Part-DB entity.

        Args:
            element_iri: IRI of the entity to attach the file to
                (project, part, …).
            attachment_type_iri: IRI of the attachment type.
            name: Display name shown in Part-DB.
            filepath: Absolute path to the file to upload.

        Returns:
            The created attachment dict.
        """
        return self._postFileAsJson(
            "/attachments",
            data = {
                "element": elementIri,
                "attachment_type": attachmentTypeIri,
                "name": name,
                "show_in_table": True,
            },
            filepath = filepath,
        )
