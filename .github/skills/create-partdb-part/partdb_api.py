#!/usr/bin/env python3
"""
partdb_api.py - Minimal client for the Part-DB REST API, used by the create-partdb-part skill.

The server and the token are read from the environment, never from arguments:
    PARTDB_URL        Base URL of the Part-DB server, without '/api'
    PARTDB_TOKEN      API token with the level 'edit'
    PARTDB_INSECURE   Set to 1 to accept a self-signed certificate

Variables that are not set in the environment are read from the file '.partdb.env' in the root of the
repository (lines 'NAME=value'). The file is ignored by Git.

Usage:
    python partdb_api.py get <path>
    python partdb_api.py post <path> <json-file | -> [output-file]
    python partdb_api.py patch <path> <json-file | ->

<path> is the path below the base URL including the query, e.g. '/api/parts?name=ABC'.
'-' reads the JSON body from stdin. The response is printed as JSON. The lists are requested as JSON-LD,
so every record contains its ID ('id' or the last part of '@id').
With an output file the response is stored unchanged, e.g. the PDF of '/api/labels/generate'.
There is no delete command on purpose.

Exit codes:
    0   Request successful
    1   The server answered with an error (the answer is printed)
    2   Missing configuration or wrong usage
"""

import os
import ssl
import sys
import json
import urllib.error
import urllib.request

METHODS = {"get": "GET", "post": "POST", "patch": "PATCH"}

# Repository root: <root>/.github/skills/create-partdb-part/partdb_api.py
ENV_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".partdb.env")


def load_env_file():
    """Sets the variables of the file '.partdb.env' that are missing in the environment"""
    if not os.path.isfile(ENV_FILE):
        return
    with open(ENV_FILE, encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            name, value = line.split("=", 1)
            os.environ.setdefault(name.strip(), value.strip().strip("\"'"))


def simplify(data):
    """Returns the records of a JSON-LD answer, each with its ID as 'id'"""
    if isinstance(data, dict) and "hydra:member" in data:
        data = data["hydra:member"]
    elif isinstance(data, dict) and "member" in data and "@context" in data:
        data = data["member"]
    if isinstance(data, list):
        return [simplify(entry) for entry in data]
    if isinstance(data, dict):
        result = {}
        if "id" not in data and isinstance(data.get("@id"), str) and data["@id"].rsplit("/", 1)[-1].isdigit():
            result["id"] = int(data["@id"].rsplit("/", 1)[-1])
        for key, value in data.items():
            if key not in ("@context", "@type"):
                result[key] = simplify(value)
        return result
    return data


def main():
    args = sys.argv[1:]
    if len(args) < 2 or args[0] not in METHODS:
        sys.exit(__doc__)
    command, path = args[0], args[1]
    if (command == "get" and len(args) != 2) or (command == "patch" and len(args) != 3) \
            or (command == "post" and len(args) not in (3, 4)):
        sys.exit(__doc__)
    output = args[3] if len(args) == 4 else None

    load_env_file()
    url = os.environ.get("PARTDB_URL", "").rstrip("/")
    token = os.environ.get("PARTDB_TOKEN", "")
    if not url or not token:
        print("PARTDB_URL and PARTDB_TOKEN must be set in the environment or in the file .partdb.env",
              file=sys.stderr)
        sys.exit(2)

    method = METHODS[command]
    headers = {"Authorization": "Bearer " + token,
               "Accept": "*/*" if output else "application/ld+json"}
    body = None
    if method != "GET":
        if args[2] == "-":
            # Bytes instead of text: PowerShell pipes UTF-8 with a BOM
            text = sys.stdin.buffer.read().decode("utf-8-sig")
        else:
            with open(args[2], encoding="utf-8-sig") as f:
                text = f.read()
        # Validate the body before it is sent
        body = json.dumps(json.loads(text)).encode("utf-8")
        headers["Content-Type"] = "application/merge-patch+json" if method == "PATCH" else "application/json"

    context = None
    if os.environ.get("PARTDB_INSECURE") == "1":
        context = ssl._create_unverified_context()

    request = urllib.request.Request(url + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, context=context, timeout=120) as response:
            answer = response.read()
            content_type = response.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        print("HTTP %d: %s" % (e.code, e.read().decode("utf-8", "replace")), file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print("Request failed: %s" % e.reason, file=sys.stderr)
        sys.exit(1)

    if output:
        with open(output, "wb") as f:
            f.write(answer)
        print("%s: %d bytes, %s" % (output, len(answer), content_type))
    elif answer:
        print(json.dumps(simplify(json.loads(answer.decode("utf-8"))), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
