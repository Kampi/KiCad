# GitHub Copilot Instructions for KiCad Project Template

## Project Overview

This repository contains a KiCad project template with initialization scripts for Windows (PowerShell) and Linux/macOS (Bash). The template includes a complete CI/CD pipeline using both GitHub Actions and GitLab CI/CD with KiBot for automated hardware manufacturing outputs.

## Development Rules and Guidelines

### Script Development

1. **Dual Platform Support (CRITICAL)**
   - ALL changes must be implemented in BOTH init-project.ps1 (Windows/PowerShell) AND init-project.sh (Linux/Bash)
   - Test that functionality is equivalent between both scripts
   - Use platform-appropriate syntax and tools:
     - PowerShell: Use native cmdlets (Get-Content, Set-Content, ConvertFrom-Json, etc.)
     - Bash: Use sed, awk, Python for JSON manipulation
   - Never make changes to only one script without updating the other

2. **Script Functionality**
   - Maintain interactive prompts for user input (project name, board name, designer, etc.)
   - Always update all relevant files when adding new features:
     - KiCad project files (.kicad_pro, .kicad_sch, .kicad_pcb)
     - KiBot configuration (kibot_main.yaml)
     - GitHub Actions workflows (all .yaml files in .github/workflows/)
     - GitLab CI pipelines (all .gitlab-ci.yml files in .gitlab/ci/)
     - Documentation files (README.md)
   - Keep the scripts idempotent - they should be safe to run multiple times
   - Provide clear, colored output messages for all operations

3. **File Updates**
   - When updating configuration files, search ALL workflow files for similar patterns
   - Example: If updating `master_branch` in pcb.yaml, update it in ALL GitHub AND GitLab workflow files
   - When adding new project metadata fields, update:
     - .kicad_pro (text_variables section)
     - kibot_main.yaml (definitions section)
     - .kicad_sch (title_block section)
     - Any workflow files that reference these values

### Project Metadata Management

The scripts initialize and update the following metadata fields:

**Global Script Variables (DO NOT USE FOR LOCAL VARIABLES)**:
The following variables are used by the initialization scripts to pass data to templates and should NEVER be used as local variable names within functions to prevent accidental replacement:

**Main Input Variables**:
- `PROJECT_NAME` - Name of the overall project (user input)
- `BOARD_NAME` - Name of the PCB/board (user input, default: PROJECT_NAME)
- `DESIGNER` - Name of the designer (user input)
- `EMAIL` - Designer email (user input)
- `GIT_URL` - GitHub repository URL (user input)
- `GIT_USER` - GitHub username (explicitly prompted, default extracted from GIT_URL)
- `GIT_REPO` - Repository name (explicitly prompted, default extracted from GIT_URL)
- `COMPANY` - Company name (optional user input)
- `MASTER_BRANCH` - Main branch name (user input, default: "main")
- `TARGET_DIR` - Target directory for project creation (user input, default: current directory)

**Derived Variables** (lowercase/anchor versions):
- `PROJECT_NAME_ANCHOR` - Lowercase version of PROJECT_NAME for Markdown anchors
- `BOARD_NAME_ANCHOR` - Lowercase version of BOARD_NAME for Markdown anchors (README links, ToC)

**Date Variables**:
- `RELEASE_DATE` - Current date in dd-MMM-yyyy format
- `RELEASE_DATE_NUM` - Current date in yyyy-MM-dd format
- `CURRENT_DATE` - Same as RELEASE_DATE
- `CURRENT_YEAR` - Current year (yyyy)

**Version Variables**:
- `REVISION` - Initial version (always "1.0.0")

**License Variables**:
- `LICENSE_NAME` - Full license name (e.g., "MIT")
- `LICENSE_BADGE` - Badge text for README (e.g., "MIT-yellow")
- `LICENSE_KEY` - License key for template download (e.g., "mit")
- `LICENSE_SELECTION` - User's license selection (1-11)

**PCB Template Variables**:
- `PCB_FILENAME` - Selected PCB template filename
- `PCB_MANUFACTURER` - PCB manufacturer from template
- `PCB_THICKNESS` - PCB thickness from template
- `PCB_LAYERS` - Number of PCB layers from template

**Path Variables**:
- `TEMPLATE_PATH` - Path to Template-Project
- `KICAD_LIBRARY` - Path to KiCad library root
- `PROJECT_PATH` - Full path to created project

**CRITICAL**: When adding new local variables in functions, use descriptive lowercase names with underscores (e.g., `local_project_name`, `temp_dir`) to avoid conflicts with global variables. Never reuse any of the above variable names for local scope.

**KiCad Files (.kicad_pro)**:
- PROJECT_NAME - Name of the overall project
- BOARD_NAME - Name of the PCB/board
- DESIGNER - Name of the designer
- COMPANY - Company name (or "null" if empty)
- RELEASE_DATE - Current date in dd-MMM-yyyy format
- RELEASE_DATE_NUM - Current date in yyyy-MM-dd format
- REVISION - Initial version (1.0.0)

**Schematic Files (.kicad_sch)**:
- title - Sheet title (set to BOARD_NAME)

**KiBot Configuration (kibot_main.yaml)**:
- PROJECT_NAME, BOARD_NAME, COMPANY, DESIGNER, GIT_URL

**GitHub Workflows (all .yaml in .github/workflows/)** AND **GitLab CI Pipelines (all .gitlab-ci.yml in .gitlab/ci/)**:
ALL workflow environment variables must be in UPPERCASE format: `${VARIABLE_NAME}`
- MASTER_BRANCH - Main branch name (main/master)
- KICAD_BOARD - Board name (pcb pipelines only)
- KIBOT_INPUT_DIR - Input directory name (pcb pipelines only)
- KIBOT_OUTPUT_DIR - Output directory name (pcb pipelines only)
- PROJECT_NAME - Project name (documentation pipelines)

GitLab CI uses predefined variables (e.g. `CI_COMMIT_TAG`, `CI_COMMIT_BRANCH`, `CI_PROJECT_URL`) instead of GitHub Actions equivalents (`github.ref_type`, `github.ref_name`, `github.repository`).

**When adding or modifying variables**:
1. Add the variable to this list with a clear description
2. Update BOTH PowerShell and Bash scripts
3. Update BOTH GitHub Actions AND GitLab CI pipeline files
4. Document in README.md if user-facing
5. Use consistent UPPERCASE naming in all pipeline files
6. Never use these names for local function variables

### Documentation Requirements

1. **README Updates**
   - When adding new functionality to the init scripts, update the README.md in the KiCad root directory
   - Document new features in the "Project Initialization Script" section
   - Keep the "What the Script Does" list up to date
   - Use English language and avoid emojis in documentation

2. **CI/CD Documentation**
   - When adding new GitHub Actions workflows, also add the equivalent GitLab CI pipeline and document both in the "CI/CD Pipelines" section
   - Include: file name, trigger conditions, main features, and any required secrets/variables
   - Update the "GitHub Secrets Configuration" and "GitLab CI/CD Variables" sections when adding new secrets

3. **Code Comments**
   - Use clear, descriptive comments in both scripts
   - Document complex logic or platform-specific workarounds
   - Keep step numbers consistent between PowerShell and Bash scripts

4. **Non-Interactive Example Commands**
   - When adding or modifying input prompts in the initialization scripts, update the "Non-Interactive Usage" section in README.md
   - The example commands must reflect ALL current input prompts in the correct order
   - Update BOTH PowerShell and Bash example commands
   - Current input order (as of last update):
     1. Project name
     2. KiCad board name (with default)
     3. Designer name
     4. Designer email
     5. GitHub repository URL (GIT_USER and GIT_REPO extracted automatically)
     6. Company name (optional)
     7. Main branch name (with default)
     8. Target directory (with default)
     9. PCB template selection (number)
     10. License selection (1-11)
   - When adding/removing/reordering prompts:
     - Update the example command strings in both PowerShell and Bash
     - Update the "Input Order" list in README.md
     - Ensure the number of inputs matches the number of prompts
     - Keep default value handling consistent (empty string/`\n` uses default)

### CI/CD Pipeline Development

**CRITICAL: GitHub Actions and GitLab CI pipelines must be kept in sync. Every pipeline that exists for one platform must also exist for the other.**

1. **GitHub Actions Workflow Files**
   - All workflows are in `Template-Project/.github/workflows/`
   - Use consistent naming: lowercase with hyphens (e.g., changelog-check.yaml)
   - Always include descriptive job and step names
   - Use environment variables for configuration where possible

2. **GitLab CI Pipeline Files**
   - All pipeline files are in `Template-Project/.gitlab/ci/`
   - Use consistent naming: lowercase with hyphens and `.gitlab-ci.yml` suffix (e.g., changelog.gitlab-ci.yml)
   - The root `Template-Project/.gitlab-ci.yml` includes all modular pipeline files via `include:`
   - Use GitLab predefined variables (`CI_COMMIT_TAG`, `CI_COMMIT_BRANCH`, `CI_PROJECT_URL`, etc.)
   - Secrets are stored as GitLab CI/CD Variables (not GitHub Secrets)

3. **Required Pipelines (both GitHub Actions AND GitLab CI)**
   - pcb / pcb.gitlab-ci.yml - Main hardware manufacturing pipeline
   - changelog-check / changelog.gitlab-ci.yml - CHANGELOG.md format validation
   - documentation / documentation.gitlab-ci.yml - Documentation generation and deployment
   - astyle / astyle.gitlab-ci.yml - Code formatting for firmware
   - init-kibot-release / init-kibot-release.gitlab-ci.yml - Dev branch initialization
   - esp-component-release / esp-component-release.gitlab-ci.yml - Component publishing
   - west-astyle / west-astyle.gitlab-ci.yml - Zephyr/West code style check

4. **Pipeline Variables**
   - Use env/variables at the workflow level for reusable configuration
   - Document all required secrets in README.md for both platforms
   - Use consistent UPPERCASE naming across all pipeline files

5. **Key Platform Differences**
   | Concept              | GitHub Actions                  | GitLab CI                        |
   |----------------------|---------------------------------|----------------------------------|
   | Tag push detection   | `github.ref_type == 'tag'`      | `CI_COMMIT_TAG`                  |
   | Branch name          | `github.ref_name`               | `CI_COMMIT_BRANCH`               |
   | Repository URL       | `github.server_url/github.repository` | `CI_PROJECT_URL`           |
   | Token for pushes     | `GITHUB_TOKEN` / `WORKFLOW_PAT` | `WORKFLOW_PAT`                   |
   | Release creation     | `actions/create-release`        | GitLab Releases API              |
   | Artifact upload      | `actions/upload-artifact`       | `artifacts:` block               |
   | Pages deployment     | GitHub Pages action             | `pages:` job with `public/`      |

### CHANGELOG Format Requirements

The CHANGELOG.md must follow the keep-a-changelog format:

**Required Structure**:
```markdown
## [Unreleased]

### Added
- Feature description (#123)

### Changed
- Modification description (#124)

### Fixed
- Bug fix description (#125)

### Removed
- Removed feature description (#126)
```

**Rules**:
- All entries under [Unreleased] must be grouped into: Added, Changed, Fixed, Removed
- Each entry must start with `- ` (dash + space or tab)
- Each entry must contain an issue reference in format `(#number)`
- The changelog-check.yaml workflow validates this format

### Code Style and Quality

1. **PowerShell**
   - Use verb-noun naming for functions (e.g., Update-KiCadTextVariables)
   - Use proper parameter blocks with types
   - Follow PowerShell approved verbs
   - Use Write-ColorOutput for user-facing messages

2. **Bash**
   - Use snake_case for functions (e.g., update_kicad_text_variables)
   - Always quote variables ("$variable")
   - Use [[ ]] for conditionals instead of [ ]
   - Provide clear error messages with print_color

3. **Error Handling**
   - Always check if files exist before modifying them
   - Provide meaningful error messages
   - Exit with appropriate codes (0 for success, 1 for errors)
   - Use conditional warnings for optional features

### Testing Guidelines

1. **Before Committing Changes**
   - Test both init-project.ps1 and init-project.sh
   - Verify all file updates occur correctly
   - Check that generated projects work with the CI/CD pipeline
   - Ensure documentation is up to date

2. **Common Test Cases**
   - Empty/optional fields (e.g., company name)
   - Special characters in project names
   - Different branch names (main vs master)
   - Various PCB template selections

### File Structure

```
D:\KiCad\
├── init-project.ps1          # Windows initialization script
├── init-project.sh            # Linux/macOS initialization script
├── README.md                  # Main documentation
├── Template-Project/          # Project template
│   ├── .github/
│   │   └── workflows/        # GitHub Actions CI/CD pipelines
│   │       ├── pcb.yaml
│   │       ├── changelog-check.yaml
│   │       ├── documentation.yaml
│   │       ├── astyle.yaml
│   │       ├── west-astyle.yaml
│   │       ├── init-kibot-release.yaml
│   │       └── esp-component-release.yaml
│   ├── .gitlab-ci.yml         # GitLab CI root (includes all .gitlab/ci/ files)
│   ├── .gitlab/
│   │   └── ci/               # GitLab CI/CD pipeline files
│   │       ├── pcb.gitlab-ci.yml
│   │       ├── changelog.gitlab-ci.yml
│   │       ├── documentation.gitlab-ci.yml
│   │       ├── astyle.gitlab-ci.yml
│   │       ├── west-astyle.gitlab-ci.yml
│   │       ├── init-kibot-release.gitlab-ci.yml
│   │       └── esp-component-release.gitlab-ci.yml
│   ├── hardware/             # KiCad project (renamed during init)
│   │   ├── *.kicad_pro       # KiCad project file
│   │   ├── *.kicad_sch       # Schematic files
│   │   ├── *.kicad_pcb       # PCB layout
│   │   ├── CHANGELOG.md      # Version history
│   │   └── kibot_yaml/       # KiBot configuration
│   ├── firmware/             # Firmware source code
│   ├── 3d-print/             # 3D printable parts
│   ├── cad/                  # Mechanical CAD files
│   └── README.md             # Project-specific documentation
├── 3D/                       # 3D models library
├── Footprints/               # Footprints library
├── Symbols/                  # Symbols library
└── Layout/                   # Layout templates
```

### Common Patterns

**Adding a new project metadata field**:
1. Add prompt in both init scripts (PowerShell and Bash)
2. Update .kicad_pro text_variables (both scripts)
3. Update kibot_main.yaml if needed (both scripts)
4. Update workflows if needed (both scripts)
5. Document in README.md
6. Update non-interactive example commands in README.md
7. Test both scripts

**Adding a new input prompt**:
1. Add prompt using get_input (Bash) or Get-UserInput (PowerShell) in both scripts
2. Update the non-interactive example commands in README.md "Non-Interactive Usage" section:
   - Update the PowerShell example command with backtick-n separators
   - Update the Bash example command with \n separators
   - Add the new input to the "Input Order" list with description
   - Maintain the correct order of all inputs
3. Update the "Current input order" list in .github/copilot-instructions.md
4. Test both interactive and non-interactive modes

**Adding a new pipeline**:
1. Create `.yaml` file in `Template-Project/.github/workflows/` (GitHub Actions)
2. Create the equivalent `.gitlab-ci.yml` file in `Template-Project/.gitlab/ci/` (GitLab CI)
3. Add the new GitLab CI file to the `include:` list in `Template-Project/.gitlab-ci.yml`
4. Add any required secrets to both GitHub Secrets Configuration and GitLab CI/CD Variables sections in README
5. Document the pipeline in CI/CD Pipelines section of README (cover both platforms)
6. Update init scripts to replace any template values (both scripts)
7. Test both pipeline variants

**Updating file format handling**:
1. Check both PowerShell and Bash implementations
2. Ensure regex patterns are compatible
3. Test with edge cases
4. Update error handling
5. Document any format requirements

### Anti-Patterns (DO NOT DO)

- ❌ Making changes only to init-project.ps1 without updating init-project.sh
- ❌ Making changes only to a GitHub Actions workflow without creating/updating the equivalent GitLab CI pipeline
- ❌ Making changes only to a GitLab CI pipeline without creating/updating the equivalent GitHub Actions workflow
- ❌ Hardcoding values instead of using variables
- ❌ Forgetting to update README.md when adding features
- ❌ Adding/modifying input prompts without updating the non-interactive example commands in README.md
- ❌ Not testing both scripts after changes
- ❌ Using emojis in documentation
- ❌ Updating only one workflow/pipeline file when pattern applies to all
- ❌ Not validating file existence before operations
- ❌ Ignoring error cases
- ❌ Using platform-specific paths without conversion
- ❌ Forgetting to add new GitLab CI pipeline files to the `include:` list in `.gitlab-ci.yml`

### Version Control

- Commit both script changes together
- Use conventional commit messages: `feat:`, `fix:`, `docs:`, `refactor:`
- Document breaking changes in commit messages
- Keep commits focused on single features/fixes

### Support and Maintenance

- Maintain compatibility with KiCad 9.0 or later
- Keep KiBot configuration up to date
- Monitor GitHub Actions updates for deprecated features
- Test with latest versions of PowerShell and Bash
- Update documentation for any breaking changes

## Summary

The golden rules:
1. **Always update BOTH scripts** (PowerShell and Bash)
2. **Always update BOTH pipeline platforms** (GitHub Actions AND GitLab CI) - every pipeline must exist on both
3. **Always update README** when adding features
4. **Search ALL workflow files** for similar patterns (both GitHub and GitLab)
5. **Test both platforms** before committing
6. **No emojis** in documentation
7. **Use English** for all documentation
