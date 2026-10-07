---
description: "Use when editing the project init scripts init-project.sh or init-project.ps1: prompts, input order, placeholders, template copy, license, Git initialization."
applyTo: "Scripts/**"
---
# Init Scripts

- Implement every change in `init-project.sh` and `init-project.ps1` with the same behavior and the same step numbers
- Port every change to `Plugins/KiCad-Project-Initialization-Plugin/kicad_project_init.py` (prompts become dialog fields). The plugin must create the same files as the scripts, except the Git repository. Compare the results with `diff -r` for every project type
- Bash: snake_case functions, quoted variables, `[[ ]]`, `print_color` for output, Python 3 for JSON
- PowerShell: approved verb-noun functions, typed parameter blocks, native cmdlets, `Write-ColorOutput` for output
- Check that a file exists before changing it. Exit with 1 on errors
- Keep the scripts idempotent

## Global Variables and Placeholders

Global variables pass the project data to the template. Never reuse their names for local variables, use lowercase names such as `local_project_name`.

The scripts replace these `${NAME}` placeholders in every text file of the new project:

| Placeholder | Value |
| ----------- | ----- |
| `PROJECT_NAME` | Project name (input) |
| `BOARD_NAME` | Board name (input, default: project name) |
| `BOARD_NAME_LOWER` | Lowercase board name, also the name of the hardware directory |
| `PROJECT_NAME_ANCHOR`, `BOARD_NAME_ANCHOR` | Markdown anchors of the project and board name |
| `DESIGNER`, `EMAIL` | Designer name and email (input) |
| `COMPANY` | Company name (optional input) |
| `GIT_URL`, `GIT_USER`, `GIT_REPO` | Repository URL (input), user and repository extracted from it |
| `GIT_REPO_LOWER`, `GIT_REPO_UPPER` | Repository name as C identifier in lowercase and uppercase, `-` becomes `_` (ESP-IDF component) |
| `MASTER_BRANCH` | Main branch (input, default: `main`) |
| `REVISION` | Initial version `1.0.0` |
| `RELEASE_DATE`, `RELEASE_DATE_NUM` | Current date as `dd-MMM-yyyy` and `yyyy-MM-dd` |
| `LICENSE_BADGE`, `LICENSE_LINK` | License badge and link (project README only) |

Further global variables: `PROJECT_TYPE`, `PROJECT_TYPE_NAME`, `HAS_HARDWARE`, `FIRMWARE_PROFILE`, `TARGET_DIR`, `TEMPLATE_PATH`, `KICAD_LIBRARY`, `PROJECT_PATH`, `CURRENT_DATE`, `CURRENT_YEAR`, `LICENSE_NAME`, `LICENSE_KEY`, `LICENSE_SELECTION`, `PCB_FILENAME`, `PCB_MANUFACTURER`, `PCB_THICKNESS`, `PCB_LAYERS`.

Don't use the placeholder names in template files for anything else, e.g. KiCad text variables, because the scripts would replace them.

A new project metadata field needs: the prompt in both scripts, the placeholder replacement, and where needed the `text_variables` of the `.kicad_pro`, the `definitions` of `kibot_main.yaml` and the title block of the `.kicad_sch`.

## Input Order

1. Project name
2. KiCad board name (default: project name)
3. Designer name
4. Designer email
5. GitHub repository URL
6. Company name (optional)
7. Main branch name (default: `main`)
8. Target directory (default: current directory)
9. Project type selection (1-4, default: 1)
10. PCB template selection (number, project types with hardware only)
11. License selection (1-11)
12. Push to GitHub now (y/N)

When adding, removing or reordering a prompt, update this list, the header comments of both scripts and the "Non-Interactive Usage" section of [README.md](../../README.md) (both example commands and the input order). Empty input uses the default value.

## Project Types

| No. | Project type | `HAS_HARDWARE` | `FIRMWARE_PROFILE` |
| --- | ------------ | -------------- | ------------------ |
| 1 | Hardware | true | `blank` |
| 2 | Hardware with PlatformIO firmware | true | `platformio` |
| 3 | PlatformIO firmware | false | `platformio` |
| 4 | ESP-IDF component | false | `esp-idf-component` |

- The firmware profiles are the directories in `Template-Project/firmware/`. `apply_project_type` / `Set-ProjectType` moves the selected profile to `firmware/` (ESP-IDF component: to the repository root), removes the other profiles and removes the workflows, directories and skills of the other project types
- All steps that change the KiCad project run only with `HAS_HARDWARE`
- A new firmware profile needs: the directory in `Template-Project/firmware/`, the menu entry and the mapping in both scripts, its `fw-` workflows and the documentation in [README.md](../../README.md) (Project Types, CI/CD Pipelines)

## Testing

Run both scripts interactively and non-interactively with empty optional fields, special characters in names, `main` and `master` as main branch, every PCB template and every project type.
