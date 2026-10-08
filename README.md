# KiCad

## Table of Contents

- [KiCad](#kicad)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
  - [Setup](#setup)
    - [Required Tools](#required-tools)
    - [Setup Instructions](#setup-instructions)
      - [1. Install the Tools](#1-install-the-tools)
      - [2. Clone the Repository](#2-clone-the-repository)
      - [3. Set the KICAD\_LIBRARY Environment Variable](#3-set-the-kicad_library-environment-variable)
      - [4. Authenticate Git and the GitHub CLI](#4-authenticate-git-and-the-github-cli)
      - [5. Configure VS Code and GitHub Copilot](#5-configure-vs-code-and-github-copilot)
    - [Project Initialization Script](#project-initialization-script)
      - [What the Script Does](#what-the-script-does)
      - [Usage](#usage)
      - [Non-Interactive Usage](#non-interactive-usage)
  - [Directories](#directories)
  - [PCB Template Structure](#pcb-template-structure)
    - [Template Naming Convention](#template-naming-convention)
    - [Available Templates](#available-templates)
    - [Template Selection](#template-selection)
    - [Adding Custom Templates](#adding-custom-templates)
  - [CI/CD Pipelines](#cicd-pipelines)
    - [PCB](#pcb)
    - [Changelog Check](#changelog-check)
    - [Documentation](#documentation)
    - [Code Style Check](#code-style-check)
    - [PlatformIO Firmware](#platformio-firmware)
    - [ESP-IDF Component](#esp-idf-component)
    - [Component Release](#component-release)
  - [Release Workflow](#release-workflow)
    - [Version Scheme](#version-scheme)
    - [create-dev-branch Skill](#create-dev-branch-skill)
    - [create-release Skill](#create-release-skill)
      - [Prerequisites](#prerequisites)
      - [Usage of the Skill](#usage-of-the-skill)
      - [What the Skill Does](#what-the-skill-does)
      - [Files Changed by the Skill](#files-changed-by-the-skill)
  - [GitHub Secrets Configuration](#github-secrets-configuration)
  - [GitLab CI/CD Variables](#gitlab-cicd-variables)
  - [How to Obtain API Keys](#how-to-obtain-api-keys)
  - [Resources](#resources)
  - [Maintainer](#maintainer)

## About

My private KiCad repository with symbols, 3D models (most of the models are delivered by the part manufacturer, [GrabCAD](https://grabcad.com/), [3D ContentCentral](https://www.3dcontentcentral.com/Default.aspx) or [SnapEDA](https://www.snapeda.com/)), and footprints for different projects.

Please write an e-mail to [DanielKampert@kampis-elektroecke.de](mailto:DanielKampert@kampis-elektroecke.de) if you have any questions.

## Setup

### Required Tools

| Tool | Version | Needed for |
| ---- | ------- | ---------- |
| [KiCad](https://www.kicad.org/download/) | 10.0 or later | Schematic and PCB design, `kicad-cli` for ERC/DRC. The template files and the PCB pipeline use KiCad 10 |
| [Git](https://git-scm.com/downloads) | Current version | Repository handling, init scripts, releases |
| [Python 3](https://www.python.org/downloads/) | 3.8 or later | JSON processing in `init-project.sh`, file updates in the `create-dev-branch` and `create-release` skills |
| Bash | 4.0 or later | `init-project.sh`, project scripts and the `create-dev-branch` and `create-release` skills (Git Bash or WSL on Windows) |
| PowerShell | 5.1 or later | `init-project.ps1` (Windows only) |
| curl | Current version | License download in `init-project.sh` |
| [GitHub CLI](https://cli.github.com/) (`gh`) | Current version | Pushing with the logged in GitHub user in the `create-dev-branch` and `create-release` skills, watching pipelines and reading releases in the `create-release` skill |
| [Visual Studio Code](https://code.visualstudio.com/) | Current version | Running the `create-dev-branch` and `create-release` skills |
| [GitHub Copilot](https://github.com/features/copilot) | Copilot subscription | Agent mode for the `create-dev-branch` and `create-release` skills |
| [KiBot](https://github.com/INTI-CMNB/KiBot) | Optional | Local output generation with `kibot_launch.sh` (the CI/CD pipeline uses its own container) |

### Setup Instructions

#### 1. Install the Tools

**Linux (Debian/Ubuntu):**

```bash
sudo apt update
sudo apt install git python3 curl
```

Install KiCad from the [KiCad download page](https://www.kicad.org/download/linux/) and the GitHub CLI by following the [official installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md). The distribution packages of both tools are often outdated.

**Windows (PowerShell):**

```powershell
winget install --id KiCad.KiCad
winget install --id Git.Git
winget install --id Python.Python.3.12
winget install --id GitHub.cli
winget install --id Microsoft.VisualStudioCode
```

Add the `bin` directory of KiCad (e.g. `C:\Program Files\KiCad\10.0\bin`) to the `PATH`, so that `kicad-cli` can be found.

Verify the installation:

```bash
git --version
python3 --version
kicad-cli version
gh --version
```

#### 2. Clone the Repository

The template and the plugins are included as Git submodules, so clone the repository recursively:

```bash
git clone --recurse-submodules https://github.com/Kampi/KiCad
```

For an existing clone, fetch the submodules with `git submodule update --init --recursive`.

#### 3. Set the KICAD_LIBRARY Environment Variable

Create an environment variable with the name `KICAD_LIBRARY` and set it to the location of the repository.

**Linux/macOS:**

```bash
echo 'export KICAD_LIBRARY="$HOME/Projects/KiCad"' >> ~/.bashrc
source ~/.bashrc
```

**Windows (PowerShell):**

```powershell
[Environment]::SetEnvironmentVariable("KICAD_LIBRARY", "C:\KiCad", "User")
```

Restart KiCad and all terminals afterwards.

#### 4. Authenticate Git and the GitHub CLI

```bash
git config --global user.name "John Doe"
git config --global user.email "john.doe@example.com"
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status
```

`gh auth setup-git` makes Git use the credentials of the active GitHub CLI account, so `git push` and `gh` always use the same account. With several accounts, add them with `gh auth login` and switch with `gh auth switch --user <username>`.

#### 5. Configure VS Code and GitHub Copilot

1. Install the GitHub Copilot extension and sign in with your GitHub account
2. Open the generated project folder (not the `KiCad` repository) in VS Code, so that the skills in `.github/skills/` are found
3. Make sure agent skills are enabled (`chat.useAgentSkills`, enabled by default)
4. **Windows only**: The skill uses Bash commands. Set Git Bash as the terminal profile for agent commands:

   ```json
   "chat.tools.terminal.terminalProfile.windows": {
       "path": "C:\\Program Files\\Git\\bin\\bash.exe"
   }
   ```

### Project Initialization Script

The `Scripts` directory contains initialization scripts for creating new projects from the template:

- `Scripts/init-project.ps1` - Windows PowerShell script
- `Scripts/init-project.sh` - Linux/macOS Bash script

The scripts find the template via the `KICAD_LIBRARY` environment variable or, if it is not set, relative to their own location.

#### Project Types

The scripts ask for the project type and keep only the directories, the firmware profile and the GitHub Actions workflows that belong to it:

| No. | Project type | Hardware | Firmware profile | Result |
| --- | ------------ | -------- | ---------------- | ------ |
| 1 | Hardware (default) | Yes | `firmware/blank` | KiCad project with an empty firmware directory |
| 2 | Hardware with PlatformIO firmware | Yes | `firmware/platformio` | KiCad project and a PlatformIO project in `firmware/` |
| 3 | PlatformIO firmware | No | `firmware/platformio` | PlatformIO project in `firmware/` |
| 4 | ESP-IDF component | No | `firmware/esp-idf-component` | Component in the repository root |

- **PlatformIO profile**: ESP32 (`esp32dev`) with the ESP-IDF framework. The platform `espressif32 @ 7.1.3` contains ESP-IDF v6.1. Hardware independent code in `lib/` is tested on the host with the `native` environment
- **ESP-IDF component profile**: Component for ESP-IDF v6.1 or later with `idf_component.yml`, an example project in `examples/basic` and its own `README.md` and `CHANGELOG.md`. The sources are named after the repository (`my-component` becomes `my_component.h`)
- Project types without hardware get no KiCad project, no `hw-*` workflows and no release skills. The GitLab CI pipelines are not adapted to the project type yet
- A component cannot be combined with hardware in one repository, because the component release and the hardware release both use the tag `x.y.z`

#### What the Script Does

1. **Project metadata**: Prompts for project name, board name, designer, email, repository URL, company, main branch, target directory and the [project type](#project-types)
2. **PCB template selection** (project types with hardware): Lists the PCB templates from `Template-Project/hardware/` and applies the selected one
3. **Project structure**: Copies the complete template (hardware, firmware, CAD, 3D print, scripts, GitHub Actions workflows, GitLab CI pipelines and agent skills), removes template artifacts such as backups, `VARIABLES.md` and the Git data of the template, and applies the project type
4. **Renaming**: Renames the `hardware` directory to the lowercase board name and all `Template.*` files to `<BoardName>.*`
5. **Metadata**: Updates the text variables in the `.kicad_pro` file (`PROJECT_NAME`, `BOARD_NAME`, `DESIGNER`, `COMPANY`, release date and revision), the sheet title of the main schematic, `kibot_main.yaml` and the workflow settings
6. **License**: Prompts for an open source license (or no license) and downloads the license text
7. **Placeholders**: Replaces all `${...}` placeholders in every text file of the project, including the GitLab CI pipelines and the agent skills
8. **Documentation**: Creates the AsciiDoc scaffolding in `firmware/docs/` (not for the ESP-IDF component)
9. **Git repository**: Initializes the repository with the main branch, the remote `origin`, the commit message template `.github/.commit-msg-template` and an initial commit, and optionally pushes it

#### Usage

**Windows (PowerShell):**

```powershell
cd C:\path\to\KiCad
.\Scripts\init-project.ps1
```

**Linux/macOS (Bash):**

```bash
cd /path/to/KiCad
./Scripts/init-project.sh
```

The script guides you through an interactive setup. Afterwards the target directory contains a fully configured KiCad project. The Bash script checks whether Python 3 is installed and prints installation instructions if it is missing.

#### Non-Interactive Usage

For automated or scripted usage, you can pipe all inputs to the initialization script using `echo`:

**Windows (PowerShell):**

```powershell
"MyProject`nMyBoard`nJohn Doe`njohn.doe@example.com`nhttps://github.com/user/repo`nMyCompany`nmain`nC:\Projects`n1`n1`n1`nn" | .\Scripts\init-project.ps1
```

**Linux/macOS (Bash):**

```bash
echo -e "MyProject\nMyBoard\nJohn Doe\njohn.doe@example.com\nhttps://github.com/user/repo\nMyCompany\nmain\n/home/$(whoami)/projects\n1\n1\n1\nn" | ./Scripts/init-project.sh
```

**Input Order:**

1. Project name (e.g., "MyProject")
2. KiCad board name (e.g., "MyBoard", or press Enter to use project name)
3. Designer name (e.g., "John Doe")
4. Designer email (e.g., `john.doe@example.com`)
5. GitHub repository URL (e.g., `https://github.com/user/repo`) - username and repository name are extracted automatically
6. Company name (optional, or press Enter to skip)
7. Main branch name (default: "main")
8. Target directory (default: current directory)
9. Project type selection (1-4, default: "1" for hardware, see [Project Types](#project-types))
10. PCB template selection (number, e.g., "1" for first template). Only asked for project types with hardware, leave it out for the types 3 and 4
11. License selection (1-11, e.g., "1" for MIT)
12. Push to GitHub now (y/N, default: no)

**Note:** Empty values (just `\n` or backtick-n in PowerShell) will use the default value for that field.

## Directories

The repository contains the following directories and files:

- `3D`: 3D models in STEP format used by the library
- `Applications`: Additional applications, e.g. the Part-DB integration
- `Design-Blocks`: KiCad design blocks
- `Drawings`: Inventor projects for different 3D models
- `Footprints`: Part footprints
- `GitHub`: Third-party libraries as Git submodules (Espressif KiCad libraries)
- `Layout`: Drawing sheet templates
- `Plugins`: KiCad plugins as Git submodules (KiCad Project Initialization Plugin)
- `Scripts`: Project initialization scripts
- `Symbols`: Part symbols
- `Template-Project`: Project template (Git submodule)
- `KiCad Workflow.md`: Development workflow, version numbering and GitHub workflow
- `AGENTS.md`: Project guidelines for AI coding agents (GitHub Copilot, Claude Code, Codex, Cursor and others). `.github/copilot-instructions.md` and `CLAUDE.md` only point to it. Rules for single areas are in `.github/instructions/`

## PCB Template Structure

The project template supports multiple PCB stackup configurations through template files. Templates must be placed in the `Template-Project/hardware/` directory.

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

### Available Templates

- `Template - pcbway_1.6mm_2-layer.kicad_pcb` - PCBWay, 1.6mm thickness, 2 layers
- `Template - pcbway_1.6mm_4-layer.kicad_pcb` - PCBWay, 1.6mm thickness, 4 layers

### Template Selection

During project initialization, the script will:

1. Scan the `Template-Project/hardware/` directory for all template files
2. Parse the manufacturer, thickness, and layer count from each filename
3. Present an interactive menu with available templates
4. Copy the selected template as the base PCB file for the new project and remove the unused templates

### Adding Custom Templates

To add a new PCB template:

1. Create a KiCad PCB file with your desired stackup and design rules
2. Name the file following the convention above
3. Place it in the `Template-Project/hardware/` directory
4. The template will automatically appear in the selection menu

**Template Requirements:**

- Must be a valid `.kicad_pcb` file
- Should include appropriate design rules for the manufacturer
- Should contain stackup configuration matching the specified layer count
- Recommended to include manufacturer-specific constraints (trace width, spacing, etc.)

## CI/CD Pipelines

The project template contains pipelines for GitHub Actions (`Template-Project/.github/workflows/`) and GitLab CI (`Template-Project/.gitlab/ci/`, included by `Template-Project/.gitlab-ci.yml`).

The GitHub Actions workflows are grouped by a prefix in the file name and in the workflow name, so they are listed together in the Actions view. The initialization script removes the workflows that do not belong to the project type.

| Prefix | Workflow name | Area | Runs for |
| ------ | ------------- | ---- | -------- |
| `hw-` | `Hardware / ...` | KiCad project | Changes in the hardware directory |
| `fw-` | `Firmware / ...` | Firmware and components | Changes in the firmware sources |
| `docs-` | `Documentation / ...` | Documentation | Changes in `firmware/docs/` |
| `common-` | `Common / ...` | All project types | Every push and pull request |

| Pipeline | GitHub Actions | GitLab CI |
| -------- | -------------- | --------- |
| PCB | `hw-pcb.yaml` | `pcb.gitlab-ci.yml` |
| Changelog check | `common-changelog.yaml` | `changelog.gitlab-ci.yml` |
| Documentation | `docs-build.yaml` | `documentation.gitlab-ci.yml` |
| Code style check (AStyle) | `fw-format.yaml` | `astyle.gitlab-ci.yml` |
| Code style check (West) | - | `west-astyle.gitlab-ci.yml` |
| PlatformIO firmware | `fw-platformio.yaml` | - |
| ESP-IDF component | `fw-esp-component.yaml` | - |
| Component release (ESP-IDF) | `fw-esp-component-release.yaml` | `esp-component-release.gitlab-ci.yml` |

### PCB

**Trigger**: Push to `dev` or a development branch `x.y.z_Dev` / `x.y_Dev`, push of a version tag `x.y.z`, or manual start. The GitHub workflow only runs for branch pushes that change the hardware directory or `hw-pcb.yaml`. Tag pushes always start it

A push to `main` or `master` does not start the GitHub workflow. The main branch only receives releases, and a release is built by its tag. The GitLab pipeline still runs for `main` and `master` (except changes to `*.md`)

A branch `x.y_Dev` only triggers the build. Releases always use the three-part [version scheme](#version-scheme) `x.y.z`

Generates the hardware outputs with KiBot in the `kicad10_auto_full` container:

- **Variant-based builds**: Uses the variant from `kibot_variant`. Tag pushes always use `RELEASED`
- **Outputs**: Schematic PDF, Gerbers, drill files, BoM, assembly documents, 3D renders and reports. The outputs are uploaded as workflow artifact (GitLab: job artifact) and not committed. Only the netlist XML is pushed back to the branch, because the next run reads the sheet titles from it
- **ERC/DRC checks**: Only for the `CHECKED` and `RELEASED` variants
- **BoM check**: `scripts/python/check-bom.py` compares the generated BoM (CSV and XLSX) with the schematic. The check fails when a fitted component is missing in the BoM, when the BoM lists a component that is not fitted or excluded from the BoM, or when the CSV and the XLSX BoM differ. A failed check is reported as error, but does not stop the pipeline or the release: GitHub shows an error annotation for the step `Check BoM against schematic`, GitLab marks the job `pcb:check_bom` as failed with a warning. The report lists the components that are not expected in the BoM by reason (DNP, test points, mounting holes, ...) and is shown in the job summary (GitLab: `bom_check.md` in the artifact of `pcb:check_bom`). The result is also stored as Markdown checklist `<board>-bom_check.md` next to the BoM, so it is part of the artifact and the release. The checklist contains the automatic checks and the components for the manual review
- **Cost analysis**: Runs KiCost with the distributor API keys. Missing keys do not fail the pipeline
- **Release** (tag pushes only): Updates `CHANGELOG.md` on the main branch, creates the GitHub/GitLab release with the outputs as ZIP file and publishes the outputs to GitHub/GitLab Pages. GitHub Pages is only updated by releases, so it always shows the state of the latest release

**Variants**:

- `DRAFT`: Schematic only, generates PDF, netlist and BoM (skips ERC/DRC)
- `PRELIMINARY`: Full outputs without ERC/DRC. Set by the `create-dev-branch` skill
- `CHECKED`: Full outputs with ERC/DRC. Set by the `create-release` skill
- `RELEASED`: Full outputs with ERC/DRC, automatically used for version tags

### Changelog Check

**Trigger**: Pull/merge requests targeting `main` or `master`, push to `main`, `master` or `dev`

Validates the changelogs of the project. The GitHub workflow checks `<board>/CHANGELOG.md`, `firmware/CHANGELOG.md` and `CHANGELOG.md` (ESP-IDF component) and skips the files that do not exist. The GitLab pipeline checks `<board>/CHANGELOG.md`:

- The `## [Unreleased]` section must exist
- Entries must be grouped under `**Added:**`, `**Changed:**`, `**Fixed:**` or `**Removed:**`
- Each entry must start with a dash and a space

Example:

```markdown
## [Unreleased]

**Added:**

- New feature description (#12)

**Fixed:**

- Bug fix description (#13)
```

### Documentation

**Trigger**: Push to `main` or `master` and pull/merge requests that change `firmware/docs/**` or the pipeline file, or manual start

- Converts all AsciiDoc files in `firmware/docs/` to HTML and PDF and generates a landing page
- Publishes the result to GitHub/GitLab Pages

### Code Style Check

**Trigger**: Pull/merge requests, push to `main`, `master` or `dev`, or manual start. The GitHub workflow only runs when C/C++ sources, `scripts/` or the workflow file change

- Builds AStyle and runs `scripts/bash/check-format.sh` in dry-run mode. Style violations are reported, files are not changed
- The GitHub workflow checks the directories from `source_dirs` (`firmware`, for the ESP-IDF component `src include examples`). Without arguments the script checks `src` and `include`
- GitLab only: `west-astyle.gitlab-ci.yml` runs `west format --dry-run` for Zephyr/West based firmware (requires a West workspace)

### PlatformIO Firmware

**Trigger**: Pull requests and pushes to `main`, `master`, `dev` or a development branch that change `firmware/` or the workflow file, or manual start

Builds, tests and checks the PlatformIO project in `firmware/` (GitHub Actions only):

- **Build**: Reads the environments from `platformio.ini` and builds every environment except the ones with the `native` platform as a matrix. The firmware images (`*.bin`, `*.elf`) are uploaded as workflow artifact
- **Unit tests**: Runs `pio test -e native` on the host
- **Static analysis**: Runs `pio check` (cppcheck) for every target environment and fails on defects of medium or high severity

The firmware has no release pipeline. A version tag `x.y.z` starts the hardware release only.

### ESP-IDF Component

**Trigger**: Pull requests and pushes to `main`, `master`, `dev` or a development branch (except changes to `*.md`), or manual start

Builds and validates the component in the repository root (GitHub Actions only):

- **Build**: Builds every example in `examples/` in the `espressif/idf` Docker image for each combination of the matrix `idf_version` (default: `v6.1`) and `target` (default: `esp32`). Add versions or targets to the matrix to cover them
- **Validation**: Packs the component with `compote component pack`. This checks `idf_component.yml` without uploading anything

### Component Release

**Trigger**: Push to `main` or `master` (merge of a development branch)

Releases an ESP-IDF component:

- Takes the version from the merge commit (`Merge branch 'x.y.z_Dev'`) or the branch name
- Updates `CHANGELOG.md`, `CMakeLists.txt` and `idf_component.yml`, commits the changes and pushes the tag `x.y.z`
- Creates the GitHub/GitLab release. The GitHub workflow also uploads the component to the ESP Component Registry

## Release Workflow

A hardware release follows the development cycle of the template:

1. Create a development branch `x.y.z_Dev` with the `create-dev-branch` skill. It branches off the main branch, sets the KiBot variant to `PRELIMINARY` and prepares the changelog variables for the release
2. Work on the design and document all changes in the `## [Unreleased]` section of `CHANGELOG.md`
3. Create the release with the `create-release` skill. It merges the development branch into the main branch and pushes the tag `x.y.z`, which triggers the `RELEASED` build and the GitHub release

### Version Scheme

Releases use exactly three numeric parts `x.y.z` (major, minor, patch), e.g. `1.2.0`. A two-part version like `1.2` is not a valid release version, write it as `1.2.0`.

| Item | Format | Example |
| ---- | ------ | ------- |
| Development branch | `x.y.z_Dev` | `1.2.0_Dev` |
| Release version and tag | `x.y.z`, without prefix or suffix | `1.2.0` |
| Commit of the release preparation | `Prepare Release x.y.z` | `Prepare Release 1.2.0` |
| Changelog variables | `RELEASE_TITLE_x.y.z`, `RELEASE_BODY_x.y.z` | `RELEASE_TITLE_1.2.0` |

The version is defined once by the name of the development branch. The tag, the commit message and the changelog variables are derived from it and are never entered separately.

The `create-dev-branch` skill extends a shorter input to this format (`1.2` becomes `1.2.0`). The `create-release` skill and the tag trigger of the `PCB` pipeline only accept this format. With a branch `1.2_Dev` the skill stops, and a tag `1.2` or `v1.2.0` does not start the release pipeline.

### create-dev-branch Skill

The template contains the agent skill `create-dev-branch` in `Template-Project/.github/skills/create-dev-branch/SKILL.md`. GitHub Copilot finds it there, Claude Code finds it through the pointer in `Template-Project/.claude/skills/create-dev-branch/SKILL.md`. The initialization script copies it into every new project and replaces the placeholders (`${BOARD_NAME}`, `${BOARD_NAME_LOWER}`, `${MASTER_BRANCH}`) with the project values.

The skill prepares a development branch from any state of the main branch, so that only the design work and the changelog entries are missing before the `create-release` skill is started. It requires `git`, `python3`, an authenticated GitHub CLI and a clean working tree. The branch is pushed with the user that is logged in to the GitHub CLI. Start it in the **Agent** mode of the Chat view with `/create-dev-branch`.

1. **Version**: Asks for the version of the next release and extends it to `x.y.z`. Stops if the tag or the branch already exists
2. **Main branch**: Pulls the main branch (`main` or `master`, from `master_branch` in `hw-pcb.yaml`)
3. **Branch**: Creates the development branch `x.y.z_Dev`
4. **Production data**: Removes the production directory (`kibot_output_path` in `hw-pcb.yaml`) with the outputs of the previous release. The netlist XML is kept
5. **Variant**: Sets `kibot_variant` in `.github/workflows/hw-pcb.yaml` to `PRELIMINARY`
6. **Changelog variables**: Adds a free `x.y.z` entry for `RELEASE_TITLE_<version>` and `RELEASE_BODY_<version>` to the KiBot configuration and to the revision history sheet. It uses the unused column (`${RELEASE_TITLE_...}`) following the newest release. If all columns of the table are used, the column of the oldest release is replaced
7. **Commit and push**: Commits `Prepare Development Branch for Release x.y.z` and pushes the branch after a confirmation

The skill is based on the GitHub Actions workflow `hw-pcb.yaml`. It does not change the GitLab CI pipelines.

### create-release Skill

The template contains the agent skill `create-release` in `Template-Project/.github/skills/create-release/SKILL.md`. GitHub Copilot finds it there, Claude Code finds it through the pointer in `Template-Project/.claude/skills/create-release/SKILL.md`. The initialization script copies it into every new project and replaces the placeholders (`${BOARD_NAME}`, `${BOARD_NAME_LOWER}`, `${MASTER_BRANCH}`) with the project values.

The skill is based on the GitHub Actions workflow `hw-pcb.yaml` and the GitHub CLI. It does not support GitLab CI.

#### Prerequisites

- All [required tools](#required-tools) for the skill are installed: `git`, `python3`, `kicad-cli` (KiCad 10 or later) and `gh`
- The GitHub CLI is authenticated with an account that can push to the repository (`gh auth status`). All pushes of the skill are done with this user
- The working tree is clean (`git status --porcelain` is empty)
- The current branch is the development branch `x.y.z_Dev` (three parts, see [Version Scheme](#version-scheme)). The release version is always taken from the branch name
- The `## [Unreleased]` section of `CHANGELOG.md` contains entries
- The tag `x.y.z` does not exist yet
- `kibot_yaml/kibot_pre_set_text_variables.yaml` and the revision history sheet contain a free `x.y.z` entry for the changelog variables, or already the entries for the release version

#### Usage of the Skill

1. Open the project in VS Code and check out the development branch, e.g. `1.2.0_Dev`
2. Open the Chat view and select **Agent** mode
3. Start the skill with the slash command or a prompt:

   ```text
   /create-release
   ```

   ```text
   Create the release for the current development branch.
   ```

4. Confirm the summary (version, development branch, main branch) before the skill pushes anything

The skill stops at the first failing step and reports the error. It never deletes or moves a tag without asking.

#### What the Skill Does

1. **Checks**: Validates the branch name, the project files, the `env` section of `hw-pcb.yaml`, the changelog and the tag
2. **ERC and DRC**: Runs `kicad-cli sch erc` and `kicad-cli pcb drc` (with schematic parity). Errors abort the release, warnings do not
3. **Changelog variables**: Sets the free `x.y.z` entries for `RELEASE_TITLE_<version>` and `RELEASE_BODY_<version>` in the KiBot configuration and in the revision history sheet to the release version
4. **Variant**: Sets `kibot_variant` in `.github/workflows/hw-pcb.yaml` to `CHECKED`
5. **Commit and push**: Commits `Prepare Release x.y.z` and pushes it to the development branch
6. **KiBot pipeline**: Waits for the `Hardware / PCB Data` workflow of the commit with `gh run watch`
7. **Merge**: Pulls the netlist XML generated by the pipeline and merges the development branch into the main branch
8. **Tag**: Creates the tag `x.y.z` and pushes the main branch and the tag atomically
9. **Release pipeline**: Waits for the run of the tag, which builds the release, and reports the URL of the GitHub release. Only this run decides whether the release was successful. The push of the main branch starts no run
10. **Pull**: Pulls the main branch (`main` or `master`, from `master_branch` in `hw-pcb.yaml`) to get the released state with the updated `CHANGELOG.md`

#### Files Changed by the Skill

| File | Change |
| ---- | ------ |
| `<board>/kibot_yaml/kibot_pre_set_text_variables.yaml` | Changelog variables of the release version |
| `<board>/Revision History.kicad_sch` | Changelog variables in the revision history table |
| `.github/workflows/hw-pcb.yaml` | `kibot_variant` set to `CHECKED` |

## GitHub Secrets Configuration

Add the secrets in the repository settings under **Settings > Secrets and variables > Actions**.

| Secret Name | Used In | Description | Required |
| ----------- | ------- | ----------- | -------- |
| `MOUSER_KEY` | `hw-pcb.yaml` | Mouser API key for the KiCost price lookup | Optional |
| `DIGIKEY_KEY` | `hw-pcb.yaml` | DigiKey API key for the KiCost price lookup | Optional |
| `TME_KEY` | `hw-pcb.yaml` | TME API key for the KiCost price lookup | Optional |
| `RS_KEY` | `hw-pcb.yaml` | RS API key for the KiCost price lookup | Optional |
| `FARNELL_KEY` | `hw-pcb.yaml` | Farnell API key for the KiCost price lookup | Optional |
| `IDF_COMPONENT_REGISTRY_TOKEN` | `fw-esp-component-release.yaml` | Token for the upload to the ESP Component Registry | Required for ESP-IDF components |

`GITHUB_TOKEN` is provided automatically. The workflows use it to push the netlist and the changelog, to create releases and to deploy GitHub Pages. For the Pages deployment set **Settings > Pages > Source** to **GitHub Actions**.

## GitLab CI/CD Variables

Add the variables in the project settings under **Settings > CI/CD > Variables** and mark them as masked.

| Variable Name | Used In | Description | Required |
| ------------- | ------- | ----------- | -------- |
| `WORKFLOW_PAT` | `pcb.gitlab-ci.yml`, `esp-component-release.gitlab-ci.yml` | Personal access token with the scopes `api` and `write_repository` to push commits and tags and to create releases | Required |
| `MOUSER_KEY` | `pcb.gitlab-ci.yml` | Mouser API key for the KiCost price lookup | Optional |
| `DIGIKEY_KEY` | `pcb.gitlab-ci.yml` | DigiKey API key for the KiCost price lookup | Optional |
| `TME_KEY` | `pcb.gitlab-ci.yml` | TME API key for the KiCost price lookup | Optional |
| `RS_KEY` | `pcb.gitlab-ci.yml` | RS API key for the KiCost price lookup | Optional |
| `FARNELL_KEY` | `pcb.gitlab-ci.yml` | Farnell API key for the KiCost price lookup | Optional |

## How to Obtain API Keys

Only the Mouser API is enabled in `kibot_yaml/kicost_config_local.yaml` of the template. Enable further distributors there before you add their keys.

**Mouser API Key**:

1. Register at [Mouser Electronics](https://www.mouser.com/)
2. Navigate to [API Hub](https://www.mouser.com/api-hub/)
3. Request access to the Search API and copy the key

**DigiKey API Key**:

1. Register at the [DigiKey API Portal](https://developer.digikey.com/)
2. Create an application and copy the client ID and the client secret

**ESP Component Registry Token**:

1. Log in to the [ESP Component Registry](https://components.espressif.com/)
2. Navigate to your profile settings
3. Generate an API token for component uploads

## Resources

- [KiBot Template](https://github.com/nguyen-v/KDT_Hierarchical_KiBot)
- [KiCad Project Template](https://github.com/Kampi/Template-Project)

## Maintainer

- [Daniel Kampert](mailto:DanielKampert@kampis-elektroecke.de)
