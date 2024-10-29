# KiCad

## Table of Contents

- [KiCad](#kicad)
  - [Table of Contents](#table-of-contents)
    - [About](#about)
  - [Setup](#setup)
    - [Project Initialization Script](#project-initialization-script)
      - [What the Script Does](#what-the-script-does)
      - [Usage](#usage)
      - [Requirements](#requirements)
  - [Directories](#directories)
  - [PCB Template Structure](#pcb-template-structure)
    - [Template Naming Convention](#template-naming-convention)
    - [Template Selection](#template-selection)
    - [Adding Custom Templates](#adding-custom-templates)
  - [CI/CD Pipelines](#cicd-pipelines)
    - [PCB Workflow](#pcb-workflow)
    - [Changelog Validation](#changelog-validation)
    - [Documentation Generation](#documentation-generation)
    - [Code Formatting](#code-formatting)
    - [Development Branch Creation](#development-branch-creation)
    - [Component Release](#component-release)
  - [GitHub Secrets Configuration](#github-secrets-configuration)
    - [Required Secrets](#required-secrets)
    - [Automatically Provided Secrets](#automatically-provided-secrets)
    - [How to Obtain API Keys](#how-to-obtain-api-keys)
    - [Notes](#notes)
  - [Ressources](#ressources)
  - [Maintainer](#maintainer)

### About

My private KiCad repository with symbols, 3D models (most of the models are delivered by the part manufacturer, [GrabCAD](https://grabcad.com/), [3D ContentCentral](https://www.3dcontentcentral.com/Default.aspx) or [SnapEDA](https://www.snapeda.com/)), and footprints for different projects.

Please write an e-mail to [DanielKampert@kampis-elektroecke.de](DanielKampert@kampis-elektroecke.de) if you have any questions.

## Setup

Download the repository and create a environment variable with the name `KICAD_LIBRARY`. Set the path of the variable to the location of the repository.

### Project Initialization Script

The repository includes initialization scripts for creating new KiCad projects from the template:

- `init-project.ps1` - Windows PowerShell script
- `init-project.sh` - Linux/macOS Bash script

#### What the Script Does

The initialization script automates the complete setup of a new KiCad project with the following features:

1. **Interactive Project Setup**: Prompts for project information including project name, board name, designer details, company name, and GitHub repository URL
2. **PCB Template Selection**: Allows selection from available PCB templates with different manufacturers, thicknesses, and layer counts
3. **License Selection**: Interactive menu to select an open source license (MIT, Apache, GPL, BSD, etc.) or no license
4. **Project Structure Creation**: Copies the complete project template structure including hardware, firmware, CAD, and documentation directories
5. **File Customization**: Automatically renames and updates all project files with the specified names
6. **Metadata Updates**:  
   - Updates KiCad project files (.kicad_pro, .kicad_sch, .kicad_pcb) with project metadata
   - Sets text variables: `PROJECT_NAME`, `BOARD_NAME`, `DESIGNER`, `COMPANY`
   - Updates sheet title in the main schematic to match the board name
   - Updates KiBot configuration files with project-specific values
7. **Documentation Generation**: Creates initial README.md, AsciiDoc documentation, and license files
8. **Workflow Configuration**: Updates GitHub Actions workflows for PCB manufacturing, documentation, and releases
9. **Git Repository Initialization**: Sets up a new Git repository with initial commit and optional push to GitHub

#### Usage

**Windows:**

```ps
cd /path/to/KiCad
.\init-project.ps1
```

**Linux/macOS:**

```sh
cd /path/to/KiCad
./init-project.sh
```

The script will guide you through an interactive setup process. After completion, your new project directory will contain a fully configured KiCad project ready for development.

#### Requirements

- **Windows**: PowerShell 5.1 or later
- **Linux/macOS**: Bash, Python 3 (for JSON processing)
- Git (for repository initialization)
- KiCad 9.0 or later

**Note for Linux/macOS**: The script checks if Python 3 is properly installed and will provide installation instructions if needed.

## Directories

The library contain the following directory and file structure:

- `3D` : All 3D models in `step` format used by the library
- `Drawings` : Inventor projects for different 3D models
- `Footprints` : Part footprints
- `Layout` : Layout templates
- `Scripts` : Python scripts for KiCad
- `Symbols` : Part symbols
- `__Project__` : Project template

## PCB Template Structure

The project template supports multiple PCB stackup configurations through template files. Templates must be placed in the `__Project__/hardware/` directory.

### Template Naming Convention

PCB template files must follow this exact naming pattern:

```sh
Template - <manufacturer>_<thickness>_<layers>-layer.kicad_pcb
```

**Components:**

- `Template - ` - Fixed prefix (required)
- `<manufacturer>` - PCB manufacturer name (e.g., pcbway, jlcpcb, oshpark)
- `<thickness>` - Board thickness with unit (e.g., 1.6mm, 0.8mm, 2.0mm)
- `<layers>` - Number of copper layers (e.g., 2, 4, 6)
- `-layer.kicad_pcb` - Fixed suffix (required)

**Examples:**
- `Template - pcbway_1.6mm_4-layer.kicad_pcb` - PCBWay, 1.6mm thickness, 4 layers
- `Template - jlcpcb_1.6mm_2-layer.kicad_pcb` - JLCPCB, 1.6mm thickness, 2 layers
- `Template - oshpark_1.6mm_4-layer.kicad_pcb` - OSH Park, 1.6mm thickness, 4 layers

### Template Selection

During project initialization, the script will:

1. Scan the `__Project__/hardware/` directory for all template files
2. Parse the manufacturer, thickness, and layer count from each filename
3. Present an interactive menu with available templates
4. Copy the selected template as the base PCB file for the new project

### Adding Custom Templates

To add a new PCB template:

1. Create a KiCad PCB file with your desired stackup and design rules
2. Name the file following the convention above
3. Place it in the `__Project__/hardware/` directory
4. The template will automatically appear in the selection menu

**Template Requirements:**

- Must be a valid `.kicad_pcb` file
- Should include appropriate design rules for the manufacturer
- Should contain stackup configuration matching the specified layer count
- Recommended to include manufacturer-specific constraints (trace width, spacing, etc.)

## CI/CD Pipelines

The project template includes automated GitHub Actions workflows for continuous integration and deployment. All pipelines are located in `__Project__/.github/workflows/`.

### PCB Workflow

**File**: `pcb.yaml`

**Trigger**: Push to main/master/dev branches, workflow dispatch, or version tags

The main pipeline for generating hardware manufacturing outputs using KiBot. Features include:

- **Variant-based builds**: Supports DRAFT, PRELIMINARY, CHECKED, and RELEASED variants
- **Automated outputs**: Generates Gerbers, drill files, BoM, assembly documents, 3D renders, and documentation
- **ERC/DRC checks**: Runs electrical and design rule checks for CHECKED and RELEASED variants
- **Changelog management**: Automatically updates CHANGELOG.md when releasing version tags
- **Release creation**: Creates GitHub releases with manufacturing files on version tags
- **Cost analysis**: Runs KiCost to estimate component costs using Mouser and DigiKey APIs

**Variants**:

- `DRAFT`: Schematic only, generates PDF, netlist, and BoM (skips ERC/DRC)
- `PRELIMINARY`: Full outputs without ERC/DRC validation
- `CHECKED`: Full outputs with ERC/DRC validation
- `RELEASED`: Full outputs with ERC/DRC, automatically triggered on version tags

### Changelog Validation

**File**: `changelog-check.yaml`

**Trigger**: Pull requests or pushes that modify `hardware/CHANGELOG.md`

Validates the CHANGELOG.md format to ensure compatibility with the keep-a-changelog standard:

- **Section validation**: Ensures all entries are grouped under Added, Changed, Fixed, or Removed
- **Format checking**: Verifies entries start with dash and space (`-`)
- **Issue references**: Validates that each entry contains an issue reference `(#number)`
- **Duplicate detection**: Warns about duplicate issue numbers in the Unreleased section

### Documentation Generation

**File**: `documentation.yaml`

**Trigger**: Push to main/master branches or workflow dispatch

Generates and deploys project documentation:

- **AsciiDoc processing**: Converts documentation to HTML
- **GitHub Pages deployment**: Automatically publishes documentation to GitHub Pages
- **Version tracking**: Updates documentation with current project version

### Code Formatting

**File**: `astyle.yaml`

**Trigger**: Push or pull request affecting firmware source files

Enforces code formatting standards for firmware:

- **Artistic Style (AStyle)**: Automatically formats C/C++ code
- **Consistent style**: Applies project-defined formatting rules
- **Auto-commit**: Commits formatted code back to the branch

### Development Branch Creation

**File**: `create-dev-branch.yaml`

**Trigger**: Workflow dispatch or release publication

Automates development branch management:

- **Branch creation**: Creates dev-vX.Y.Z branches for new releases
- **Changelog setup**: Adds Unreleased section to CHANGELOG.md for the new development cycle
- **Version management**: Prepares repository for next development iteration

### Component Release

**File**: `esp_component_release.yaml`

**Trigger**: Push of version tags

Publishes esp-idf components to Espressif Registry:

- **Registry publication**: Pushes to Espressif Registry for reuse in other projects

## GitHub Secrets Configuration

The CI/CD workflows require specific GitHub secrets to be configured in your repository settings. Navigate to **Settings > Secrets and variables > Actions** to add these secrets.

### Required Secrets

| Secret Name | Used In | Description | Required |
| ------------ | --------- | ------------- | ---------- |
| `MOUSER_KEY` | pcb.yaml | API key for Mouser Electronics price lookup via KiCost | Optional |
| `DIGIKEY_KEY` | pcb.yaml | API key for DigiKey Electronics price lookup via KiCost | Optional |
| `IDF_COMPONENT_REGISTRY_TOKEN` | esp_component_release.yaml | Authentication token for ESP-IDF Component Registry | Required for ESP components |

### Automatically Provided Secrets

These secrets are automatically provided by GitHub and do not need to be configured:

| Secret Name | Description |
| ------------ | ------------- |
| `GITHUB_TOKEN` | Automatically generated token for GitHub API access. Used for creating releases, pushing commits, and GitHub Pages deployment |

### How to Obtain API Keys

**Mouser API Key**:

1. Register at [Mouser Electronics](https://www.mouser.com/)
2. Navigate to [API Hub](https://www.mouser.com/api-hub/)
3. Request API access and obtain your key

**DigiKey API Key**:

1. Register at [DigiKey](https://www.digikey.com/)
2. Navigate to [API Portal](https://developer.digikey.com/)
3. Create an application and obtain your client ID and secret
4. Use the client ID as the secret value

**ESP-IDF Component Registry Token**:

1. Log in to [ESP Component Registry](https://components.espressif.com/)
2. Navigate to your profile settings
3. Generate an API token for component uploads

### Notes

- The MOUSER_KEY and DIGIKEY_KEY are optional. Without them, the cost analysis step will be skipped
- Cost analysis requires at least one API key to function
- The GITHUB_TOKEN secret has limited permissions. For certain operations, you may need to create a Personal Access Token (PAT) with additional permissions

## Ressources

- [KiBot Template](https://github.com/nguyen-v/KDT_Hierarchical_KiBot)

## Maintainer

- [Daniel Kampert](mailto:DanielKampert@kampis-elektroecke.de)
