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

"""Download and extraction helpers for KiCad release ZIP archives."""

import logging
import os
import shutil
import tempfile
import zipfile
from typing import Tuple

import requests

logger = logging.getLogger(__name__)

class ReleaseDownloadError(Exception):
    """Raised when downloading or extracting a release archive fails."""

def downloadAndExtractRelease(url: str) -> Tuple[str, str]:
    """Download a KiCad release ZIP and extract it to a temporary directory.

    On success the caller is responsible for deleting ``tmp_dir`` after use
    (e.g. via ``shutil.rmtree``).  On failure the temporary directory is
    cleaned up automatically before the exception is re-raised.

    Args:
        url: HTTPS URL pointing to the release ZIP file.

    Returns:
        A ``(release_dir, tmp_dir)`` tuple where *release_dir* is the path
        to the extracted KiCad release directory and *tmp_dir* is the root
        temporary directory that the caller must delete when done.

    Raises:
        ReleaseDownloadError: If the download, extraction, or directory
            detection fails.
    """
    tmpDir = tempfile.mkdtemp(prefix = "partdb_release_")
    try:
        logger.info("Downloading release from %s …", url)
        try:
            response = requests.get(url, stream = True, timeout = 120)
            response.raise_for_status()
        except requests.exceptions.RequestException as exc:
            raise ReleaseDownloadError(f"Download failed: {exc}") from exc

        zipPath = os.path.join(tmpDir, "release.zip")
        try:
            with open(zipPath, "wb") as fh:
                for chunk in response.iter_content(chunk_size = 65536):
                    fh.write(chunk)
        except OSError as exc:
            raise ReleaseDownloadError(f"Failed to write archive: {exc}") from exc

        logger.info("Extracting release archive …")
        try:
            with zipfile.ZipFile(zipPath, "r") as zf:
                zf.extractall(tmpDir)
        except zipfile.BadZipFile as exc:
            raise ReleaseDownloadError(f"Invalid ZIP archive: {exc}") from exc
        finally:
            if (os.path.isfile(zipPath)):
                os.remove(zipPath)

        releaseDir = _findReleaseDir(tmpDir)
        logger.debug("Extracted release directory: %s", releaseDir)
        return releaseDir, tmpDir

    except ReleaseDownloadError:
        shutil.rmtree(tmpDir, ignore_errors = True)
        raise

def _findReleaseDir(base: str) -> str:
    """Locate the KiCad release directory inside an extraction root.

    Searches for a sub-directory that contains ``Manufacturing/Assembly/``.
    Falls back to *base* itself if the archive was extracted flat.

    Args:
        base: Root directory of the extracted archive.

    Returns:
        Absolute path to the KiCad release directory.

    Raises:
        ReleaseDownloadError: If no suitable directory is found.
    """
    for entry in sorted(os.listdir(base)):
        candidate = os.path.join(base, entry)
        if (os.path.isdir(candidate) and os.path.isdir(
            os.path.join(candidate, "Manufacturing", "Assembly")
        )):
            return candidate

    if (os.path.isdir(os.path.join(base, "Manufacturing", "Assembly"))):
        return base

    raise ReleaseDownloadError(
        "Could not locate the KiCad release directory "
        "(expected Manufacturing/Assembly/) inside the downloaded archive."
    )
