# Specification

## Idea

Import a KiCad project release produced by a CI/CD pipeline into a Part-DB server.
The goal is to add new components to the Part-DB database and to represent the PCB
as a hierarchical *Project* inside Part-DB.

## Process

1. Parse the BOM CSV from a given KiCad release directory.
   The release is downloaded by an external CI/CD step; its local path is specified
   in `settings.json` or via the `--release-dir` CLI argument.
2. For each BOM entry that carries a manufacturer part number (MPN):
   - Query Part-DB for an existing part with that exact MPN.
   - If found → record the IRI and continue.
   - If not found → create the part (name = MPN, description, KiCad footprint,
     manufacturer, category derived from the designator prefix) and record the
     new IRI.
3. Create or find a **top-level project** in Part-DB.
   The name is derived from the release directory name by stripping the
   all-uppercase release qualifier and title-casing the remainder
   (e.g. `mainboard-RELEASED` → `Mainboard`).
   A custom name can be provided via `settings.json → project_name` or `--project-name`.
4. Create a **sub-project** (child of the top-level project) whose name equals
   the release directory basename (e.g. `mainboard-RELEASED`).
   The script exits with an error if the sub-project already exists, preventing
   duplicate BOM entries on repeated CI/CD runs.
5. Link every BOM component to the sub-project BOM, including quantity and
   designator references.
6. Upload relevant release documents as attachments to the sub-project
   (schematics PDF/SVG, interactive BOM, DRC/ERC reports, 3D STEP model).

## BOM File Format

Location inside a release: `<release_dir>/Manufacturing/Assembly/*-bom.csv`

CSV columns (the header row uses these exact names):

| Column            | Description                                     |
|-------------------|-------------------------------------------------|
| `Row`             | Sequential row number                           |
| `Quantity Per PCB`| Number of identical components per board        |
| `References`      | Space-separated list of designators (e.g. `C1 C2`) |
| `Value`           | Component value or part value string            |
| `Datasheet`       | URL to the datasheet (often Mouser-hosted)      |
| `Footprint`       | KiCad footprint reference                       |
| `Description`     | Human-readable component description            |
| `manf`            | Manufacturer name                               |
| `manf#`           | Manufacturer part number (MPN) — primary key    |

## Designator-Prefix to Category Mapping

The category is derived from the alphabetic prefix of the first designator
in the *References* column.  The mapping can be extended in `settings.json`.

| Prefix | Category               |
|--------|------------------------|
| `BT`   | Batteries              |
| `C`    | Capacitors             |
| `D`    | Diodes                 |
| `F`    | Fuses                  |
| `IC`   | Integrated Circuits    |
| `J`    | Connectors             |
| `K`    | Relays                 |
| `L`    | Inductors              |
| `LED`  | LEDs                   |
| `M`    | Modules                |
| `P`    | Connectors             |
| `Q`    | Transistors            |
| `R`    | Resistors              |
| `SW`   | Switches               |
| `TH`   | Sensors                |
| `U`    | Integrated Circuits    |
| `X`    | Connectors             |
| `Y`    | Crystals & Oscillators |

Unknown prefixes fall back to `default_category` (default: `"Miscellaneous"`).

ICs that require finer sub-classification (voltage regulators, LED drivers, …)
can be separated in a later step by editing the parts inside Part-DB, or the
`category_map` override in `settings.json` can map specific prefixes to custom
categories before the first import.

## Part-DB API

The application communicates with the Part-DB REST API (API Platform / JSON-LD).

Base URL: configured in `settings.json → api_url`
Authentication: `Authorization: Bearer <api_key>` header.

Endpoints used:

| Method | Endpoint                    | Purpose                                      |
|--------|-----------------------------|----------------------------------------------|
| GET    | `/categories`               | List categories (for lookup/create)          |
| POST   | `/categories`               | Create a new category                        |
| GET    | `/manufacturers`            | List manufacturers                           |
| POST   | `/manufacturers`            | Create a new manufacturer                   |
| GET    | `/footprints`               | List footprints                              |
| POST   | `/footprints`               | Create a new footprint                       |
| GET    | `/parts?filter[manufacturerProductNumber]=…` | Search part by MPN    |
| POST   | `/parts`                    | Create a new part                            |
| GET    | `/projects`                 | List projects                                |
| POST   | `/projects`                 | Create a project (top-level or sub)          |
| POST   | `/project_bom_entries`      | Add a BOM line item to a project             |
| GET    | `/attachment_types`         | List attachment types                        |
| POST   | `/attachment_types`         | Create an attachment type                    |
| POST   | `/attachments`              | Upload a file attachment (multipart/form-data) |

## File Structure

```sh
app/
├── app.py              Main CLI entry point
├── partdb_client.py    Part-DB REST API client
└── bom_parser.py       KiCad BOM CSV parser
settings.json.template  Settings file template
requirements.txt        Python dependency list
LICENSE                 GNU General Public License v3
.github/
└── copilot-instructions.md  Coding standards for GitHub Copilot
```

## Settings File (`settings.json`)

| Key               | Required | Description                                              |
|-------------------|----------|----------------------------------------------------------|
| `api_url`         | yes      | Part-DB API base URL                                     |
| `api_key`         | yes      | Part-DB bearer token — **never commit to VCS**           |
| `release_dir`     | no       | Default release directory path                           |
| `project_name`    | no       | Override the auto-derived top-level project name         |
| `default_category`| no       | Fallback category for unknown prefixes (default: `Miscellaneous`) |
| `category_map`    | no       | Override/extend the default designator-prefix mapping    |

## CLI Reference

```sh
python app/app.py [OPTIONS]

Options:
  -s, --settings FILE       Settings JSON file (default: settings.json)
  -r, --release-dir DIR     KiCad release directory (overrides settings)
  -n, --project-name NAME   Top-level project name (overrides auto-detection)
      --skip-attachments    Do not upload release documents as attachments
      --dry-run             Simulate all steps, no writes to Part-DB
  -v, --verbose             Debug-level logging
```

## CI/CD Integration

The application can be included in a CI/CD workflow as a Git submodule or by
installing it from the repository.  A minimal GitHub Actions step:

```yaml
- name: Import release to Part-DB
  run: |
    pip install -r requirements.txt
    python app/app.py \
      --release-dir "${{ env.RELEASE_DIR }}" \
      --settings ci/settings.json
```

The `settings.json` used in CI should provide the API key via a repository
secret (never hardcode it).

## Rules for the Project

- Python 3.8+ command-line application
- `settings.json` for runtime configuration (API key, paths, category overrides)
- GPLv3 license; file header: `Daniel Kampert <DanielKampert@kampis-elektroecke>`
- `requirements.txt` for pip-installable dependencies
- Application entry point: `app/app.py`
- Coding standards defined in `.github/copilot-instructions.md`

## Open Items

- Supplier article numbers (e.g. Mouser order codes) are not present in the
  KiCad BOM CSV.  Adding them would require a separate lookup step via a
  distributor API (Mouser, Digikey, …) and is not yet implemented.

## Resources

- Part-DB API: https://inventory.kampert.synology.me/api
