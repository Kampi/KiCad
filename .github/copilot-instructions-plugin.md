# GitHub Copilot Instructions for KiCad Project Template - Plugin Edition

## Project Overview

This repository contains THREE synchronized implementations of KiCad project initialization:

1. **PowerShell Script** (`Scripts/init-project.ps1`) - Windows command-line tool
2. **Bash Script** (`Scripts/init-project.sh`) - Linux/macOS command-line tool  
3. **KiCad Python Plugin** (`kicad_project_init_plugin/`) - GUI plugin for KiCad PCBNew

All three MUST be kept in sync when logic changes are made.

## Critical Rule: THREE-WAY SYNCHRONIZATION

**WHENEVER you change functionality in ONE implementation, you MUST update ALL THREE:**

1. ✅ Update PowerShell script (`Scripts/init-project.ps1`)
2. ✅ Update Bash script (`Scripts/init-project.sh`)
3. ✅ Update Python plugin (`kicad_project_init_plugin/kicad_project_init.py`)
4. ✅ Update documentation (README files)

### Example Scenarios

#### Adding a new metadata field

```sh
1. Add prompt in init-project.ps1
2. Add prompt in init-project.sh  
3. Add input field in Python dialog class
4. Update update_project_file() in all three
5. Update kibot_config update in all three
6. Document in README files
```

#### Changing PCB template logic

```sh
1. Update scan_pcb_templates in both scripts
2. Update scan_pcb_templates() in Python plugin
3. Update apply_pcb_template in all three
4. Test with actual template files
5. Update documentation
```

## File Structure

```sh
D:\KiCad\
├── Scripts/                          # Command-line scripts
│   ├── init-project.ps1              # PowerShell implementation
│   └── init-project.sh               # Bash implementation
│
├── kicad_project_init_plugin/        # KiCad plugin
│   ├── __init__.py                   # Plugin registration
│   ├── kicad_project_init.py         # Main plugin code
│   ├── metadata.json                 # Plugin metadata
│   ├── icon.png                      # Plugin icon
│   ├── README.md                     # Plugin documentation
│   └── __Project__/                  # Template (bundled with plugin)
│
├── __Project__/                      # Master template (for scripts)
│   ├── hardware/
│   │   ├── Template.kicad_pro
│   │   ├── Template.kicad_sch
│   │   ├── Template.kicad_pcb
│   │   ├── Template - *.kicad_pcb    # PCB templates
│   │   └── kibot_yaml/
│   ├── firmware/
│   ├── 3d-print/
│   ├── cad/
│   └── .github/workflows/
│
├── README.md                         # Main documentation
└── .github/
    └── copilot-instructions-plugin.md # This file
```

## Template Path Resolution

### Scripts (PowerShell & Bash)

```powershell
# Scripts are in Scripts/ folder
$SCRIPT_DIR = Split-Path -Parent $PSCommandPath
$KICAD_ROOT = Split-Path -Parent $SCRIPT_DIR  # One level up
$TEMPLATE_PATH = Join-Path $KICAD_ROOT "__Project__"
# Result: D:\KiCad\__Project__
```

### Python Plugin

```python
# Plugin bundles template inside its directory
plugin_dir = Path(__file__).parent
template_path = plugin_dir / "__Project__"
# Result: D:\KiCad\kicad_project_init_plugin\__Project__
```

**Important:** When updating the master template (`D:\KiCad\__Project__`), remember to:

1. Update the bundled plugin template
2. Run: `Copy-Item -Path "D:\KiCad\__Project__" -Destination "D:\KiCad\kicad_project_init_plugin\__Project__" -Recurse -Force`

## Function Mapping Between Implementations

### PowerShell ↔ Bash ↔ Python

| PowerShell Function | Bash Function | Python Method | Purpose |
| --------------------- | --------------- | --------------- | --------- |
| `Get-UserInput` | `get_input` | `dialog.GetValue()` | User input |
| `Get-PCBTemplates` | `get_pcb_templates` | `scan_pcb_templates()` | Find PCB templates |
| `Show-PCBTemplateMenu` | `show_pcb_template_menu` | `wx.Choice()` | Select template |
| `Show-LicenseMenu` | `show_license_menu` | N/A (not in plugin) | License selection |
| `Update-KiCadTextVariables` | `update_kicad_text_variables` | `update_project_file()` | Update .kicad_pro |
| `Update-KibotConfig` | `update_kibot_config` | `update_kibot_config()` | Update kibot yaml |
| N/A | N/A | `copy_missing_template_files()` | Plugin-only feature |

## Core Functionality That MUST Stay Synchronized

### 1. Project Metadata Fields

**All three implementations must handle:**

- `PROJECT_NAME` - Project name
- `BOARD_NAME` - PCB/board name
- `DESIGNER` - Designer name
- `EMAIL` - Designer email (scripts only)
- `COMPANY` - Company name (optional)
- `REVISION` - Version number (default: 1.0.0)
- `RELEASE_DATE` - Date in dd-MMM-yyyy format
- `RELEASE_DATE_NUM` - Date in yyyy-MM-dd format
- `GIT_URL` - GitHub repository URL (scripts only)
- `MASTER_BRANCH` - Main branch name (scripts only)

### 2. File Operations

**All three must perform these operations identically:**

1. **Copy template structure**
   - PowerShell: `Copy-Item -Recurse`
   - Bash: `cp -r`
   - Python: `shutil.copytree()`

2. **Rename hardware directory**
   - `hardware/` → `{BOARD_NAME}/`

3. **Apply PCB template**
   - Select from `Template - {manufacturer}_{thickness}_{layers}-layer.kicad_pcb`
   - Copy to `Template.kicad_pcb`
   - Update BOARD_NAME and PROJECT_NAME in file
   - Delete unused templates

4. **Rename Template files**
   - `Template.*` → `{BOARD_NAME}.*`

5. **Update .kicad_pro**
   - Parse JSON
   - Update `text_variables` section
   - Write back with proper formatting

6. **Update schematic title**
   - Replace `(title "Template")` with `(title "{BOARD_NAME}")`

7. **Update kibot_main.yaml**
   - Replace placeholder values in definitions section

### 3. PCB Template Format

**Pattern:** `Template - {manufacturer}_{thickness}_{layers}-layer.kicad_pcb`

**Examples:**

- `Template - pcbway_1.6mm_2-layer.kicad_pcb`
- `Template - jlcpcb_1.6mm_4-layer.kicad_pcb`
- `Template - aisler_1.6mm_4-layer.kicad_pcb`

**Regex Pattern (all three must use equivalent):**

```regex
^Template - ([^_]+)_([^_]+)_(\d+)-layer\.kicad_pcb$
```

Captured groups:

1. Manufacturer name
2. Thickness (e.g., "1.6mm")
3. Layer count (e.g., "2", "4")

## Development Workflow

### When Adding New Features

1. **Design the feature** - Plan how it works in all three contexts
2. **Implement in order:**
   - Start with Bash (simplest logic)
   - Adapt to PowerShell (similar structure)
   - Adapt to Python (GUI considerations)
3. **Test each implementation** separately
4. **Update documentation** - All README files
5. **Create integration test** if applicable

### When Fixing Bugs

1. **Identify which implementations have the bug**
2. **Fix in all affected implementations**
3. **Test the fix in each context**
4. **Document the fix** if it's not obvious

### When Changing File Formats

If you change how any configuration file is processed:

1. Update PowerShell JSON/YAML handling
2. Update Bash sed/awk/Python handling  
3. Update Python json/re handling
4. Test with real template files
5. Document the format change

## Plugin-Specific Considerations

### GUI vs Command-Line

**The plugin has additional features not in scripts:**

- Two-mode operation (Create New / Update Existing)
- Dialog-based user input
- Optional copying of missing template files
- Direct integration with loaded KiCad board

### Plugin Dependencies

**Required Python modules (bundled with KiCad):**

- `pcbnew` - KiCad Python API
- `wx` - GUI framework
- `json` - JSON parsing
- `shutil` - File operations
- `pathlib` - Path handling
- `re` - Regular expressions

**Do not add dependencies that aren't in KiCad's Python!**

## Documentation Requirements

### When changing functionality, update these files

1. **`README.md`** (root) - Overall project documentation
2. **`kicad_project_init_plugin/README.md`** - Plugin-specific docs
3. **`kicad_project_init_plugin/INSTALLATION.md`** - Installation guide
4. **Script inline comments** - Function documentation

### Documentation must include

- What the feature does
- How to use it (for each implementation)
- Any platform-specific considerations
- Examples with real values

## Testing Checklist

Before committing changes that affect core functionality:

- [ ] Test PowerShell script on Windows
- [ ] Test Bash script on Linux/macOS (or WSL)
- [ ] Test Python plugin in KiCad PCBNew
- [ ] Test with different PCB templates
- [ ] Test with optional fields (empty company, etc.)
- [ ] Verify .kicad_pro JSON is valid
- [ ] Verify schematic title updates correctly
- [ ] Verify kibot_main.yaml updates correctly
- [ ] Check that special characters are handled
- [ ] Verify error messages are helpful

## Common Pitfalls

### ❌ Don't Do This

1. **Update only one implementation** - Always update all three
2. **Use implementation-specific logic** - Keep logic portable
3. **Add Python-specific dependencies** - Stick to KiCad's Python
4. **Hardcode paths** - Use relative paths from script/plugin location
5. **Forget to update documentation** - Docs are part of the code
6. **Break backward compatibility** - Existing projects must still work

### ✅ Do This

1. **Think cross-platform** - Will this work on Windows/Linux/macOS?
2. **Use standard libraries** - JSON, regex, file operations
3. **Validate user input** - Check for required fields
4. **Provide helpful errors** - Tell users what went wrong and how to fix it
5. **Test incrementally** - Test each change before moving on
6. **Document as you go** - Update docs with the code

## Version Synchronization

When bumping version numbers:

1. Update plugin `metadata.json` → `versions[0].version`
2. Update both script headers (Date comment)
3. Update README.md versions section
4. Create git tag if releasing
5. Update CHANGELOG if it exists

## Anti-Patterns (Never Do This)

- ❌ Making changes only to init-project.ps1 without updating init-project.sh
- ❌ Adding features to the plugin without considering script parity
- ❌ Using PowerShell-specific cmdlets without Bash equivalents
- ❌ Hardcoding "D:\KiCad" paths anywhere
- ❌ Forgetting that scripts now run from Scripts/ folder
- ❌ Not testing template path resolution after changes
- ❌ Updating master template without updating plugin bundled template

## Summary

**Golden Rules:**

1. 🔄 **THREE-WAY SYNC** - Always update PowerShell, Bash, AND Python
2. 📁 **PATH AWARENESS** - Scripts in Scripts/, plugin bundles template
3. 📝 **DOCUMENT EVERYTHING** - READMEs, comments, examples
4. 🧪 **TEST ALL THREE** - Don't assume equivalence
5. 🎯 **KEEP LOGIC SIMPLE** - If it's hard to implement in all three, reconsider

**Before every commit, ask:**

- Did I update all three implementations?
- Did I update the documentation?
- Did I test this works from the Scripts/ folder?
- Does the plugin still find its bundled template?
- Are error messages helpful?

This ensures the project remains maintainable and all users (script and plugin) get the same excellent experience.
