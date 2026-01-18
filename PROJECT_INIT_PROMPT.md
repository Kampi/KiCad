# KiCad Project Initialization - AI Prompt (English)

## Context

This document describes the complete process for initializing a new KiCad project based on the template in the `__Project__` folder. The scripts `init-project.ps1` (Windows) and `init-project.sh` (Linux) automate this process.

## Project Structure

The template project (`__Project__`) contains:

- `.github/` - GitHub-specific files (workflows, commit template)
- `.gitignore` - Git ignore file
- `hardware/` - KiCad project files (will be renamed)
- `docs/` - Documentation
- `cad/` - CAD files
- `3d-print/` - 3D print files
- `firmware/` - Firmware code
- `README.md` - Project description

## Initialization Process

### 1. User Inputs

The following information is requested from the user:

| Variable       | Description                            | Example                        |
| -------------- | -------------------------------------- | ------------------------------ |
| `PROJECT_NAME` | Name of the project                    | "MyAwesomeBoard"               |
| `BOARD_NAME`   | Name of the KiCad board (can differ)   | "MainBoard"                    |
| `DESIGNER`     | Name of the designer/developer         | "John Doe"                     |
| `EMAIL`        | Email address of the designer          | "john@example.com"             |
| `GIT_URL`      | GitHub repository URL                  | `https://github.com/user/repo` |
| `COMPANY`      | Company name (optional)                | "ACME Corp"                    |

### 2. PCB Template Selection

The script automatically scans for available PCB templates in the hardware folder and offers the following options:

**Template Naming Scheme:**

`Template - <manufacturer>_<thickness>_<layers>-layer.kicad_pcb`

**Examples:**

- `Template - pcbway_1.6mm_2-layer.kicad_pcb` - PCBWay, 1.6mm, 2 layers
- `Template - jlcpcb_1.2mm_4-layer.kicad_pcb` - JLCPCB, 1.2mm, 4 layers
- `Template.kicad_pcb` - Custom (default)

**Selection Process:**

1. The script scans the `hardware/` folder for all template files
2. A menu displays all available templates with manufacturer, thickness, and layer count
3. "Custom (default)" uses the standard `Template.kicad_pcb`
4. The selected template is used as the basis for the new project

**Template Variables:**

| Variable           | Description        | Example  |
| ------------------ | ------------------ | -------- |
| `PCB_MANUFACTURER` | PCB manufacturer   | "pcbway" |
| `PCB_THICKNESS`    | Board thickness    | "1.6mm"  |
| `PCB_LAYERS`       | Number of layers   | "2"      |

### 3. Directory Structure

1. New project folder is created with `PROJECT_NAME`
2. Template content from `__Project__` is copied
3. Selected PCB template is copied to `Template.kicad_pcb`
4. `hardware/` folder is renamed to `BOARD_NAME`

### 4. KiCad Project Files

All KiCad files in the board folder are renamed from "Template" to `BOARD_NAME`:

- `Template.kicad_pro` → `{BOARD_NAME}.kicad_pro`
- `Template.kicad_pcb` → `{BOARD_NAME}.kicad_pcb`
- `Template.kicad_sch` → `{BOARD_NAME}.kicad_sch`
- etc.

### 5. GitHub Workflow Configuration

The `.github/workflows/pcb.yaml` file is updated:

```yaml
env:
  # Project metadata
  PROJECT_NAME: {PROJECT_NAME}
  BOARD_NAME: {BOARD_NAME}
  COMPANY: {COMPANY}
  DESIGNER: {DESIGNER}
  GIT_URL: {GIT_URL}

  # Name of the KiCad PCB file
  kicad_board: {BOARD_NAME}
  
  # Input directory with the KiCad project
  kibot_input_dir: {BOARD_NAME}
```

### 6. License Selection

A selection menu offers the following open source licenses:

1. MIT
2. Apache 2.0
3. GPL 3.0
4. LGPL 3.0
5. BSD 2-Clause
6. BSD 3-Clause
7. MPL 2.0
8. AGPL 3.0
9. Unlicense
10. CC0 1.0
11. None (no license)

The license is downloaded and copied to the following folders:

- Root directory: `LICENSE`
- Subdirectories: `docs/LICENSE`, `cad/LICENSE`, `{BOARD_NAME}/LICENSE`, `3d-print/LICENSE`, `firmware/LICENSE`

### 7. Commit Message Template

The `.github/.commit-msg-template` file is updated:

- `Signed-off-by:` line is replaced with `DESIGNER` and `EMAIL`

### 8. README.md Adjustments

The README.md in the root directory is adjusted:

| Placeholder   | Replaced with         | Description                           |
| ------------- | --------------------- | ------------------------------------- |
| `"$Project"`  | `PROJECT_NAME`        | Project name (Title + ToC)            |
| `"$User"`     | `GIT_USER`            | GitHub username (extracted from URL)  |
| `"$Email"`    | `EMAIL`               | Email address                         |
| License Badge | Corresponding license | Badge URL is updated                  |
| GitHub URLs   | `GIT_URL`             | All GitHub links are updated          |

**Important:** The Table of Contents (ToC) must maintain the correct case:

- Title: `# {PROJECT_NAME}` (original case)
- ToC Anchor: `#{project-name}` (lowercase, spaces → `-`)

### 9. Git Repository Initialization

```text
# Initialize repository
git init

# User configuration (local)
git config user.name "{DESIGNER}"
git config user.email "{EMAIL}"

# Set commit template (local, not global!)
git config commit.template ".github/.commit-msg-template"

# Create master branch
git branch -M master

# Add remote
git remote add origin {GIT_URL}
```

### 10. Initial Commit

Only `.github/` and `.gitignore` are added in the first commit:

```text
Commit title: chore: Initialize project {PROJECT_NAME}

Commit body:
Initial project setup with KiCad template structure

Signed-off-by: {DESIGNER} <{EMAIL}>
```

### 11. Push to GitHub

The master branch is pushed to GitHub (optional, with confirmation).

## Special Features

### URL Parsing

The GitHub URL is parsed to extract username and repository:

- Supports HTTPS: `https://github.com/user/repo`
- Supports SSH: `git@github.com:user/repo`
- Extracts: `GIT_USER` and `GIT_REPO`

### License Badges

Each license has a specific badge format:

```markdown
[![License](https://img.shields.io/badge/License-{BADGE_TEXT}.svg)](https://opensource.org/license/{LICENSE_KEY}/)
```

Examples:

- MIT: `MIT-yellow` → `https://opensource.org/license/mit/`
- GPL 3.0: `GPL%203.0-blue` → `https://opensource.org/license/gpl-3-0/`

### Markdown Anchors

Table of Contents links must be in lowercase with hyphens:

- Project: "My Awesome Project"
- Anchor: `#my-awesome-project`
- Special characters are removed

### PCB Template Parser

**Regex Pattern:** `^Template - ([^_]+)_([^_]+)_(\d+)-layer\.kicad_pcb$`

**Groups:**

1. Manufacturer (e.g., "pcbway", "jlcpcb")
2. Thickness (e.g., "1.6mm", "1.2mm")
3. Layer count (e.g., "2", "4")

**Dynamic Detection:**

The scripts scan the `hardware/` folder at runtime and automatically create the selection menu based on found templates.

## Error Handling

### Common Problems

1. **Template not found**: Check `KICAD_LIBRARY` environment variable
2. **Project folder already exists**: Use different name or delete folder
3. **Invalid GitHub URL**: Check URL format
4. **Git not installed**: Git must be available in PATH
5. **License download failed**: Fallback to placeholder license
6. **No PCB templates found**: At least `Template.kicad_pcb` must exist

### Script Abort

On errors, the script aborts (PowerShell with exit code, Bash with `set -e`).

## Checklist for Extensions

When extending the template, consider:

- [ ] Document new placeholders in README.md
- [ ] Add new environment variables to pcb.yaml
- [ ] Include new subdirectories for license copies
- [ ] Add new KiCad files for renaming
- [ ] Document new git hooks or configurations
- [ ] Add new PCB templates with correct naming scheme
- [ ] Adapt PCB template parser for naming scheme changes

## Script Usage

### Windows (PowerShell)

```powershell
# From KiCad directory
.\init-project.ps1

# With explicit library path
.\init-project.ps1 -KicadLibraryPath "C:\Path\To\KiCad"
```

### Linux (Bash)

```bash
# Make executable
chmod +x init-project.sh

# From KiCad directory
./init-project.sh

# With environment variable
KICAD_LIBRARY=/path/to/kicad ./init-project.sh
```

## AI Assistant Notes

When creating or modifying the scripts:

1. **Interactivity**: User inputs must be validated
2. **Platform differences**: Note Windows (PowerShell) vs. Linux (Bash) syntax
3. **Error handling**: Clear error messages and exit codes
4. **Color output**: ANSI codes for better readability
5. **Atomic operations**: Nothing should be left half-finished on errors
6. **Template dependencies**: Scripts must stay in sync with template structure
7. **PCB template parser**: Regex patterns must be flexible for different manufacturers/specs
8. **Dynamic menus**: Template lists are generated at runtime

## Version

- Created: 2026-01-18
- Template Version: KiCad 9
- KiBot Version: Latest (via Docker Container)
- New: PCB Template Selection (v1.1)
