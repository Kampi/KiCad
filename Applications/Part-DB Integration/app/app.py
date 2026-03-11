#!/usr/bin/env python3
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

"""KiCad Part-DB Integration — main CLI entry point.

Imports a KiCad project release (produced by a CI/CD pipeline) into a
Part-DB server instance.  The script:

1. Parses the BOM CSV from the release directory.
2. Checks each component against Part-DB and creates missing parts.
3. Creates (or finds) a top-level project and a release sub-project.
4. Populates the sub-project BOM with all components from the BOM file.
5. Uploads relevant release documents as attachments to the sub-project.

Usage::

    python app/app.py [--settings settings.json] [options]
"""

import argparse
import json
import logging
import os
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Allow running as a script directly (python app/app.py)
sys.path.insert(0, str(Path(__file__).parent))

from bom_parser import BOMEntry, findBomFile, parseBom  # noqa: E402
from partdb_client import PartDBClient, PartDBError  # noqa: E402
from release_downloader import ReleaseDownloadError, downloadAndExtractRelease  # noqa: E402

DEFAULT_CATEGORY_MAP: Dict[str, str] = {
    "BT": "Batteries",
    "C": "Capacitors",
    "D": "Diodes",
    "F": "Fuses",
    "IC": "Integrated Circuits",
    "J": "Connectors",
    "K": "Relays",
    "L": "Inductors",
    "LED": "LEDs",
    "M": "Modules",
    "P": "Connectors",
    "Q": "Transistors",
    "R": "Resistors",
    "SW": "Switches",
    "TH": "Sensors",
    "U": "Integrated Circuits",
    "X": "Connectors",
    "Y": "Crystals & Oscillators",
}

# Glob patterns of files to attach to the release sub-project.
# Format: (attachment_type_name, glob_pattern_relative_to_release_dir)
ATTACHMENT_PATTERNS: List[tuple] = [
    ("Schematic", "Schematic/**/*.pdf"),
    ("Schematic", "Schematic/**/*.svg"),
    ("Manufacturing", "Manufacturing/Assembly/*-ibom.html"),
    ("Manufacturing", "Manufacturing/Assembly/*-bom.html"),
    ("Report", "Reports/*.html"),
    ("Report", "Reports/*.rpt"),
    ("3D Model", "3D/*.step"),
    ("3D Model", "3D/*.stl"),
]

def setupLogging(verbose: bool) -> None:
    """Configure root logger to stdout."""
    logging.basicConfig(
        level = logging.DEBUG if verbose else logging.INFO,
        format = "%(asctime)s [%(levelname)-8s] %(message)s",
        datefmt = "%H:%M:%S",
        handlers = [logging.StreamHandler(sys.stdout)],
    )

def loadSettings(path: str) -> dict:
    """Load and minimally validate settings from a JSON file.

    Args:
        path: Path to the settings JSON file.

    Returns:
        Parsed settings dict.

    Raises:
        FileNotFoundError: If the file does not exist.
        ValueError: If required keys are missing.
        json.JSONDecodeError: If the file is not valid JSON.
    """
    with open(path, "r", encoding = "utf-8") as fh:
        settings = json.load(fh)

    missing = [k for k in ("api_url", "api_key") if not settings.get(k)]
    if (missing):
        raise ValueError(f"Missing required settings: {', '.join(missing)}")

    placeholders = {
        "api_url": "your-partdb-instance",
        "api_key": "YOUR_API_KEY_HERE",
    }
    for key, placeholder in placeholders.items():
        if (placeholder in settings.get(key, "")):
            raise ValueError(
                f"'{key}' still contains the placeholder value. "
                f"Please update settings.json with the real value."
            )

    return settings

def deriveProjectName(releaseDir: str) -> str:
    """Derive a human-readable project name from the release directory name.

    Strips an all-uppercase release suffix (e.g. ``RELEASED``, ``RC1``) and
    title-cases the remaining parts.

    Examples:

        mainboard-RELEASED  →  Mainboard
        sensor-board-RC2    →  Sensor Board
        MyPCB-v1            →  Mypcb V1  (no uppercase-only suffix detected)

    Args:
        release_dir: Path to the release directory.

    Returns:
        Human-readable project name string.
    """
    dirName = Path(releaseDir).name
    parts = dirName.split("-")

    # Remove trailing all-uppercase token (release qualifier)
    if (len(parts) > 1 and parts[-1].isupper()):
        parts = parts[:-1]

    return " ".join(p.capitalize() for p in parts)

def collectAttachments(releaseDir: str) -> List[Dict[str, str]]:
    """Collect attachment candidates from the release directory.

    Scans the release tree using :data:`ATTACHMENT_PATTERNS` and returns
    metadata dicts for each discovered file.

    Args:
        release_dir: Root of the KiCad release directory.

    Returns:
        List of dicts with keys ``type``, ``name``, and ``path``.
    """
    attachments: List[Dict[str, str]] = []
    root = Path(releaseDir)

    for attachType, pattern in ATTACHMENT_PATTERNS:
        for filepath in sorted(root.glob(pattern)):
            if (filepath.is_file()):
                attachments.append(
                    {
                        "type": attachType,
                        "name": filepath.name,
                        "path": str(filepath),
                    }
                )

    return attachments

def processBom(
    client: PartDBClient,
    bomEntries: List[BOMEntry],
    category_map: Dict[str, str],
    default_category: str,
    dry_run: bool,
) -> Dict[str, str]:
    """Check/create all parts from the BOM in Part-DB.

    For each BOM entry that contains a manufacturer part number (MPN):
    - If the MPN already exists in Part-DB, record its IRI.
    - Otherwise create a new part with category, manufacturer, and footprint.

    Args:
        client: Authenticated :class:`PartDBClient` instance.
        bom_entries: Parsed BOM entries.
        category_map: Mapping from designator prefix to category name.
        default_category: Fallback category name for unknown prefixes.
        dry_run: When *True* no write calls are made.

    Returns:
        Dict mapping MPN strings to their Part-DB ``@id`` IRIs.
    """
    logger = logging.getLogger(__name__)

    logger.info("Fetching existing categories …")
    categories: Dict[str, str] = {
        c["name"].lower(): c["@id"] for c in client.getCategories()
    }

    logger.info("Fetching existing manufacturers …")
    manufacturers: Dict[str, str] = {
        m["name"].lower(): m["@id"] for m in client.getManufacturers()
    }

    logger.info("Fetching existing footprints …")
    footprints: Dict[str, str] = {
        f["name"].lower(): f["@id"] for f in client.getFootprints()
    }

    logger.info("Fetching existing parts …")
    # Store full part dicts so we can backfill missing MPN without extra calls.
    existingParts: Dict[str, Dict] = {}
    for p in client.getParts():
        key = p.get("manufacturer_product_number") or p.get("name", "")
        if (key):
            existingParts[key] = p

    def _ensureCategory(name: str) -> str:
        key = name.lower()
        if (key not in categories):
            if (not dry_run):
                logger.info("  Creating category: %s", name)
                categories[key] = client.findOrCreateCategory(name)
            else:
                logger.info("  [DRY RUN] Would create category: %s", name)
                categories[key] = f"<dry-run/{name}>"
        return categories[key]

    def _ensureManufacturer(name: str) -> Optional[str]:
        if (not name):
            return None
        key = name.lower()
        if (key not in manufacturers):
            if (not dry_run):
                logger.info("  Creating manufacturer: %s", name)
                manufacturers[key] = client.findOrCreateManufacturer(name)
            else:
                logger.info("  [DRY RUN] Would create manufacturer: %s", name)
                manufacturers[key] = f"<dry-run/{name}>"
        return manufacturers[key]

    def _ensureFootprint(name: str) -> Optional[str]:
        if (not name):
            return None
        key = name.lower()
        if (key not in footprints):
            if (not dry_run):
                logger.info("  Creating footprint: %s", name)
                footprints[key] = client.findOrCreateFootprint(name)
            else:
                logger.info("  [DRY RUN] Would create footprint: %s", name)
                footprints[key] = f"<dry-run/{name}>"
        return footprints[key]

    partIris: Dict[str, str] = {}

    for entry in bomEntries:
        mpn = entry.manufacturerPn

        if (not mpn):
            logger.warning(
                "BOM row %d has no manufacturer part number — skipping.", entry.row
            )
            continue

        if (mpn in partIris):
            # Already handled (same MPN appears in multiple BOM rows)
            continue

        logger.info("Checking MPN: %s  (%s)", mpn, entry.manufacturer)

        if (not dry_run):
            if (mpn in existingParts):
                cached = existingParts[mpn]
                partIri = cached["@id"]
                logger.info("  → Exists: %s", partIri)
                # Backfill MPN if it was previously created without it
                # (e.g. from an earlier run that used wrong field names).
                if (not cached.get("manufacturer_product_number")):
                    logger.info("  → Backfilling missing MPN on %s", partIri)
                    client.patchPart(partIri, {"manufacturer_product_number": mpn})
                partIris[mpn] = partIri
                continue
        else:
            logger.info("  [DRY RUN] Skipping Part-DB lookup")

        # Determine category from designator prefix
        prefix = entry.designatorPrefix
        categoryName = category_map.get(prefix, default_category)
        categoryIri = _ensureCategory(categoryName)

        manufacturerIri = _ensureManufacturer(entry.manufacturer)
        footprintIri = _ensureFootprint(entry.footprint)

        commentLines = []
        if (entry.datasheet):
            commentLines.append(f"Datasheet: {entry.datasheet}")
        if (entry.footprint):
            commentLines.append(f"KiCad footprint: {entry.footprint}")
        comment = "\n".join(commentLines) if commentLines else None

        if (not dry_run):
            logger.info("  → Creating part: %s", mpn)
            created = client.createPart(
                name = mpn,
                description = entry.description,
                categoryIri = categoryIri,
                manufacturerIri = manufacturerIri,
                footprintIri = footprintIri,
                mpn = mpn,
                comment = comment,
            )
            partIris[mpn] = created["@id"]
            existingParts[mpn] = created
            logger.info("  → Created: %s", created["@id"])
        else:
            logger.info("  [DRY RUN] Would create part: %s", mpn)
            partIris[mpn] = f"<dry-run/{mpn}>"

    return partIris

def createProjectHierarchy(
    client: PartDBClient,
    projectName: str,
    releaseName: str,
    dry_run: bool,
) -> str:
    """Ensure the project hierarchy exists and return the sub-project IRI.

    Creates a top-level project named *project_name* if it does not exist,
    then always creates a new sub-project named *release_name* beneath it.
    Aborts with an error if the sub-project already exists to prevent
    duplicate BOM entries during repeated CI/CD runs.

    Args:
        client: Authenticated :class:`PartDBClient` instance.
        project_name: Human-readable board name (top-level project).
        release_name: Release directory basename (sub-project).
        dry_run: When *True* no write calls are made.

    Returns:
        IRI string of the release sub-project.
    """
    logger = logging.getLogger(__name__)

    if (dry_run):
        logger.info(
            "[DRY RUN] Would create project '%s' → '%s'", projectName, releaseName
        )
        return "<dry-run/subproject>"

    # Top-level project
    top = client.findProjectByName(projectName)
    if (top):
        topIri = top["@id"]
        logger.info("Found existing project '%s': %s", projectName, topIri)
    else:
        logger.info("Creating top-level project: %s", projectName)
        top = client.createProject(
            name = projectName,
            description = f"KiCad project: {project_name}",
        )
        topIri = top["@id"]
        logger.info("Created project: %s", topIri)

    # Release sub-project — must not exist yet
    existingSub = client.findProjectByName(releaseName)
    if (existingSub):
        logger.error(
            "Sub-project '%s' already exists (%s).  "
            "Use --force to overwrite or choose a different release name.",
            releaseName,
            existingSub["@id"],
        )
        sys.exit(1)

    logger.info("Creating sub-project: %s", releaseName)
    sub = client.createProject(
        name = releaseName,
        description = f"KiCad release: {release_name}",
        parentIri = topIri,
    )
    subIri = sub["@id"]
    logger.info("Created sub-project: %s", subIri)
    return subIri

def populateBom(
    client: PartDBClient,
    subProjectIri: str,
    bomEntries: List[BOMEntry],
    partIris: Dict[str, str],
    dry_run: bool,
) -> None:
    """Link all BOM parts to the release sub-project.

    Args:
        client: Authenticated :class:`PartDBClient` instance.
        sub_project_iri: IRI of the release sub-project.
        bom_entries: Parsed BOM entries.
        part_iris: MPN → Part-DB IRI mapping from :func:`process_bom`.
        dry_run: When *True* no write calls are made.
    """
    logger = logging.getLogger(__name__)
    logger.info("Populating project BOM …")

    for entry in bomEntries:
        mpn = entry.manufacturerPn
        if (not mpn or mpn not in partIris):
            continue

        references = " ".join(entry.references)
        logger.info(
            "  Adding %s x%d  [%s]", mpn, entry.quantity, references
        )

        if (not dry_run):
            client.addBomEntry(
                projectIri = subProjectIri,
                partIri = partIris[mpn],
                quantity = float(entry.quantity),
                references = references,
            )

def uploadAttachments(
    client: PartDBClient,
    subProjectIri: str,
    releaseDir: str,
    dry_run: bool,
) -> None:
    """Upload release documents as attachments to the sub-project.

    Args:
        client: Authenticated :class:`PartDBClient` instance.
        sub_project_iri: IRI of the release sub-project.
        release_dir: Root of the KiCad release directory.
        dry_run: When *True* no write calls are made.
    """
    logger = logging.getLogger(__name__)

    attachments = collectAttachments(releaseDir)
    if (not attachments):
        logger.info("No attachments found in release directory.")
        return

    if (dry_run):
        logger.info("[DRY RUN] Would upload %d attachment(s):", len(attachments))
        for att in attachments:
            logger.info("  [%s] %s", att["type"], att["name"])
        return

    attachmentTypeIri = client.findOrCreateAttachmentType("KiCad")

    for att in attachments:
        logger.info("  Uploading [%s] %s", att["type"], att["name"])
        try:
            client.uploadAttachment(
                elementIri = subProjectIri,
                attachmentTypeIri = attachmentTypeIri,
                name = att["name"],
                filepath = att["path"],
            )
        except (PartDBError, OSError) as exc:
            logger.warning("  Failed to upload '%s': %s", att["name"], exc)

def buildParser() -> argparse.ArgumentParser:
    """Build and return the argument parser."""
    parser = argparse.ArgumentParser(
        prog = "app.py",
        description = "Import a KiCad CI/CD release into Part-DB Server.",
        formatter_class = argparse.RawDescriptionHelpFormatter,
        epilog = "",
    )
    parser.add_argument(
        "-s",
        "--settings",
        default = "settings.json",
        metavar = "FILE",
        help = "Path to the settings JSON file (default: settings.json).",
    )
    parser.add_argument(
        "-u",
        "--url",
        metavar = "URL",
        help = "URL of the KiCad release ZIP archive (overrides settings).",
    )
    parser.add_argument(
        "--version-tag",
        metavar = "VERSION",
        required = True,
        help = "Release version string used as the sub-project name (e.g. 1.0.2).",
    )
    parser.add_argument(
        "-n",
        "--project-name",
        metavar = "NAME",
        help = "Top-level project name (overrides auto-detection from dir name).",
    )
    parser.add_argument(
        "--skip-attachments",
        action = "store_true",
        help = "Do not upload release documents as attachments.",
    )
    parser.add_argument(
        "--dry-run",
        action = "store_true",
        help = "Simulate all steps without writing anything to Part-DB.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action = "store_true",
        help = "Enable debug-level logging output.",
    )
    return parser

def main() -> None:
    """Entry point for the CLI application."""
    parser = buildParser()
    args = parser.parse_args()

    setupLogging(args.verbose)
    logger = logging.getLogger(__name__)

    if (args.dry_run):
        logger.info("*** DRY RUN — no changes will be written to Part-DB ***")

    try:
        settings = loadSettings(args.settings)
    except FileNotFoundError:
        logger.error("Settings file not found: %s", args.settings)
        sys.exit(1)
    except (ValueError, json.JSONDecodeError) as exc:
        logger.error("Invalid settings file: %s", exc)
        sys.exit(1)

    releaseUrl: str = args.url or settings.get("release_url", "")
    if (not releaseUrl):
        logger.error(
            "No release URL specified. "
            "Use --url or set 'release_url' in settings.json."
        )
        sys.exit(1)

    category_map = {**DEFAULT_CATEGORY_MAP, **settings.get("category_map", {})}
    default_category: str = settings.get("default_category", "Miscellaneous")
    projectNameOverride: Optional[str] = args.projectName or settings.get("project_name")

    tmpDir: Optional[str] = None
    try:
        try:
            releaseDir, tmpDir = downloadAndExtractRelease(releaseUrl)
        except ReleaseDownloadError as exc:
            logger.error("Failed to download release: %s", exc)
            sys.exit(1)

        releaseName = args.version_tag
        projectName: str = projectNameOverride or deriveProjectName(releaseDir)

        logger.info("Release directory : %s", releaseDir)
        logger.info("Release name      : %s", releaseName)
        logger.info("Project name      : %s", projectName)

        try:
            bomFile = findBomFile(releaseDir)
        except FileNotFoundError as exc:
            logger.error(str(exc))
            sys.exit(1)

        logger.info("BOM file: %s", bomFile)
        bomEntries = parseBom(bomFile)
        logger.info("Parsed %d BOM entries.", len(bomEntries))

        client = PartDBClient(settings["api_url"], settings["api_key"])

        try:
            partIris = processBom(
                client, bomEntries, category_map, default_category, args.dry_run
            )
        except PartDBError as exc:
            logger.error("Failed to process BOM: %s", exc)
            sys.exit(1)

        try:
            subProjectIri = createProjectHierarchy(
                client, projectName, releaseName, args.dry_run
            )
        except PartDBError as exc:
            logger.error("Failed to create project hierarchy: %s", exc)
            sys.exit(1)

        try:
            populateBom(client, subProjectIri, bomEntries, partIris, args.dry_run)
        except PartDBError as exc:
            logger.error("Failed to populate project BOM: %s", exc)
            sys.exit(1)

        if (not args.skip_attachments):
            uploadAttachments(client, subProjectIri, releaseDir, args.dry_run)
        else:
            logger.info("Skipping attachment upload (--skip-attachments).")

        logger.info("Done.")

    finally:
        if (tmpDir and os.path.isdir(tmpDir)):
            shutil.rmtree(tmpDir, ignore_errors = True)
            logger.debug("Removed temporary directory: %s", tmpDir)

if (__name__ == "__main__"):
    main()
