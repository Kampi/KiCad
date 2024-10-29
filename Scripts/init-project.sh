#!/bin/bash
# Bash Script to Initialize a New KiCad Project
# Author: GitHub Copilot
# Date: 2026-01-18

set -e  # Exit on error

# ANSI Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to get user input
get_input() {
    local prompt=$1
    local default=$2
    local required=${3:-true}
    local input
    
    if [ "$required" = "false" ]; then
        # Optional field - allow empty input
        read -p "$prompt (optional): " input
        echo "$input"
    elif [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        while [ -z "$input" ]; do
            read -p "$prompt: " input
        done
        echo "$input"
    fi
}

# Function to get PCB templates
get_pcb_templates() {
    local hardware_path=$1
    local templates=()
    local display_names=()
    
    # Parse available template files
    if [ -d "$hardware_path" ]; then
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            # Pattern: Template - manufacturer_thickness_x-layer.kicad_pcb
            # Example: Template - pcbway_1.6mm_2-layer.kicad_pcb
            if [[ $filename =~ ^Template\ -\ ([^_]+)_([^_]+)_([0-9]+)-layer\.kicad_pcb$ ]]; then
                manufacturer="${BASH_REMATCH[1]}"
                thickness="${BASH_REMATCH[2]}"
                layers="${BASH_REMATCH[3]}"
                
                templates+=("$filename|$manufacturer|$thickness|$layers")
                display_names+=("$manufacturer - $thickness - $layers layers")
            fi
        done < <(find "$hardware_path" -maxdepth 1 -name "Template - *.kicad_pcb" -print0)
    fi
    
    # Export arrays for use in main script
    printf '%s\n' "${templates[@]}"
}

# Function to show PCB template menu
show_pcb_template_menu() {
    local -a templates=("$@")
    
    print_color "$BLUE" "\n=== Select PCB Template ===" >&2
    
    for i in "${!templates[@]}"; do
        IFS='|' read -r filename manufacturer thickness layers <<< "${templates[$i]}"
        local display_name="$manufacturer - $thickness - $layers layers"
        echo "$((i + 1)). $display_name" >&2
    done
    
    local selection
    while true; do
        read -p $'\nEnter selection (1-'"${#templates[@]}"'): ' selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#templates[@]}" ]; then
            break
        fi
        print_color "$RED" "Invalid selection. Please enter a number between 1 and ${#templates[@]}." >&2
    done
    
    echo "$((selection - 1))"
}

# Function to show license menu
show_license_menu() {
    print_color "$BLUE" "\n=== Select Open Source License ===" >&2
    echo "1. MIT" >&2
    echo "2. Apache 2.0" >&2
    echo "3. GPL 3.0" >&2
    echo "4. LGPL 3.0" >&2
    echo "5. BSD 2-Clause" >&2
    echo "6. BSD 3-Clause" >&2
    echo "7. MPL 2.0" >&2
    echo "8. AGPL 3.0" >&2
    echo "9. Unlicense" >&2
    echo "10. CC0 1.0" >&2
    echo "11. None" >&2
    
    local selection
    while true; do
        read -p $'\nEnter selection (1-11): ' selection
        if [[ "$selection" =~ ^[1-9]$|^1[01]$ ]]; then
            break
        fi
        print_color "$RED" "Invalid selection. Please enter a number between 1 and 11." >&2
    done
    
    echo "$selection"
}

# Function to get license info
get_license_info() {
    local selection=$1
    
    case $selection in
        1) echo "MIT|MIT-yellow|mit" ;;
        2) echo "Apache 2.0|Apache%202.0-blue|apache-2-0" ;;
        3) echo "GPL 3.0|GPL%203.0-blue|gpl-3-0" ;;
        4) echo "LGPL 3.0|LGPL%203.0-blue|lgpl-3-0" ;;
        5) echo "BSD 2-Clause|BSD%202--Clause-orange|bsd-2-clause" ;;
        6) echo "BSD 3-Clause|BSD%203--Clause-orange|bsd-3-clause" ;;
        7) echo "MPL 2.0|MPL%202.0-brightgreen|mpl-2-0" ;;
        8) echo "AGPL 3.0|AGPL%203.0-blue|agpl-3-0" ;;
        9) echo "Unlicense|Unlicense-blue|unlicense" ;;
        10) echo "CC0 1.0|CC0%201.0-lightgrey|cc0-1-0" ;;
        11) echo "None||" ;;
    esac
}

# Function to update KiCad text variables in .kicad_pro file
update_kicad_text_variables() {
    local kicad_pro_file=$1
    local project_name=$2
    local board_name=$3
    local designer=$4
    local company=$5
    local date=$6
    local revision=$7
    
    if [ ! -f "$kicad_pro_file" ]; then
        print_color "$YELLOW" "Warning: KiCad project file not found: $kicad_pro_file"
        return
    fi
    
    # Find available Python command (try python3 first, then python)
    PYTHON_CMD=""
    if command -v python3 &> /dev/null && python3 -c "import json" 2>/dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null && python -c "import json" 2>/dev/null; then
        PYTHON_CMD="python"
    fi
    
    if [ -z "$PYTHON_CMD" ]; then
        print_color "$RED" "Error: Python is not installed or not working properly."
        print_color "$YELLOW" "Please install Python 3 from https://www.python.org/downloads/"
        print_color "$YELLOW" "Make sure to check 'Add Python to PATH' during installation."
        exit 1
    fi
    
    # Set company value, use "null" if empty
    local company_value="${company:-null}"
    local date_num=$(date +%Y-%m-%d)
    
    # Use Python to update JSON
    $PYTHON_CMD << EOF
import json
import sys

try:
    # Read the JSON file
    with open('$kicad_pro_file', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Ensure text_variables exists
    if 'text_variables' not in data:
        data['text_variables'] = {}
    
    # Update text_variables
    data['text_variables']['PROJECT_NAME'] = '$project_name'
    data['text_variables']['BOARD_NAME'] = '$board_name'
    data['text_variables']['DESIGNER'] = '$designer'
    data['text_variables']['COMPANY'] = '$company_value'
    data['text_variables']['RELEASE_DATE'] = '$date'
    data['text_variables']['RELEASE_DATE_NUM'] = '$date_num'
    data['text_variables']['REVISION'] = '$revision'
    
    # Write back to file with proper formatting
    with open('$kicad_pro_file', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    sys.exit(0)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
EOF
    
    if [ $? -eq 0 ]; then
        print_color "$GREEN" "Updated text_variables in: $kicad_pro_file"
    else
        print_color "$RED" "Failed to update text_variables in: $kicad_pro_file"
    fi
}

# Function to download and create license file
download_license() {
    local license_key=$1
    local destination=$2
    local year=$3
    local copyright_holder=$4
    
    if [ -z "$license_key" ] || [ "$license_key" = "none" ]; then
        print_color "$YELLOW" "No license selected, skipping license file creation"
        return
    fi
    
    local url="https://raw.githubusercontent.com/licenses/license-templates/master/templates/${license_key}.txt"
    
    if curl -sSL "$url" -o "$destination" 2>/dev/null; then
        # Replace placeholders
        sed -i "s/\[year\]/$year/g" "$destination"
        sed -i "s/\[fullname\]/$copyright_holder/g" "$destination"
        sed -i "s/\[email\]//g" "$destination"
        print_color "$GREEN" "License file created: $destination"
    else
        print_color "$YELLOW" "Failed to download license template from $url"
        print_color "$YELLOW" "Creating placeholder license file"
        cat > "$destination" << EOF
License: $license_key

Copyright (c) $year $copyright_holder

All rights reserved.
EOF
        print_color "$GREEN" "Placeholder license file created: $destination"
    fi
}

# Main Script
print_color "$BLUE" "========================================"
print_color "$BLUE" "  KiCad Project Initialization Script  "
print_color "$BLUE" "========================================"

# Step 1: Get project information
PROJECT_NAME=$(get_input "Enter project name" "")
BOARD_NAME=$(get_input "Enter KiCad board name" "$PROJECT_NAME")
DESIGNER=$(get_input "Enter designer name" "")
EMAIL=$(get_input "Enter designer email" "")
GIT_URL=$(get_input "Enter GitHub repository URL (e.g., https://github.com/user/repo)" "")

# Parse GitHub user and repo from URL
if [[ $GIT_URL =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
    GIT_USER="${BASH_REMATCH[1]}"
    GIT_REPO="${BASH_REMATCH[2]}"
else
    print_color "$RED" "Invalid GitHub URL format"
    exit 1
fi

COMPANY=$(get_input "Enter company name" "" false)

MASTER_BRANCH=$(get_input "Enter main branch name" "main" true)

# Step 2: Determine KiCad library path
# Script is in Scripts/ folder, template is one level up
SCRIPT_DIR="$(dirname "$0")"
KICAD_LIBRARY="${KICAD_LIBRARY:-$(dirname "$SCRIPT_DIR")}"
TEMPLATE_PATH="$KICAD_LIBRARY/__Project__"

if [ ! -d "$TEMPLATE_PATH" ]; then
    print_color "$RED" "Template directory not found: $TEMPLATE_PATH"
    print_color "$YELLOW" "Expected path: $TEMPLATE_PATH"
    print_color "$YELLOW" "Make sure __Project__ exists in the KiCad root directory"
    exit 1
fi

print_color "$GREEN" "Using template from: $TEMPLATE_PATH"

# Step 2b: Select PCB template
print_color "$BLUE" "\nScanning for PCB templates..."
mapfile -t PCB_TEMPLATES < <(get_pcb_templates "$TEMPLATE_PATH/hardware")

if [ ${#PCB_TEMPLATES[@]} -eq 0 ]; then
    print_color "$RED" "No PCB templates found in template directory"
    exit 1
fi

SELECTED_INDEX=$(show_pcb_template_menu "${PCB_TEMPLATES[@]}")
SELECTED_PCB_TEMPLATE="${PCB_TEMPLATES[$SELECTED_INDEX]}"

IFS='|' read -r PCB_FILENAME PCB_MANUFACTURER PCB_THICKNESS PCB_LAYERS <<< "$SELECTED_PCB_TEMPLATE"

print_color "$GREEN" "Selected PCB template: $PCB_MANUFACTURER - $PCB_THICKNESS - $PCB_LAYERS layers"

# Step 3: Create project directory
print_color "$BLUE" "\nCreating project directory: $PROJECT_NAME"
if [ -d "$PROJECT_NAME" ]; then
    print_color "$RED" "Directory '$PROJECT_NAME' already exists!"
    exit 1
fi

cp -r "$TEMPLATE_PATH" "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Step 3b: Replace PCB template with selected one and remove all other templates
print_color "$BLUE" "Applying PCB template: $PCB_FILENAME"
SOURCE_PCB="$PCB_FILENAME"
TARGET_PCB="Template.kicad_pcb"

# Navigate to hardware directory
cd hardware

# Copy selected template to Template.kicad_pcb
if [ -f "$SOURCE_PCB" ]; then
    cp "$SOURCE_PCB" "$TARGET_PCB"
    print_color "$GREEN" "Applied PCB template: $PCB_MANUFACTURER - $PCB_THICKNESS - $PCB_LAYERS layers"
else
    print_color "$RED" "Error: Selected template file not found: $SOURCE_PCB"
    exit 1
fi

# Remove all Template - *.kicad_pcb files (keep only Template.kicad_pcb)
find . -maxdepth 1 -name "Template - *.kicad_pcb" -type f -delete
print_color "$GREEN" "Cleaned up unused PCB template files"

# Replace "Template" with BOARD_NAME in the PCB file
print_color "$BLUE" "Updating board name in PCB file"
if [ -f "$TARGET_PCB" ]; then
    sed -i "s/BOARD_NAME\" \"Template\"/BOARD_NAME\" \"$BOARD_NAME\"/g" "$TARGET_PCB"
    sed -i "s/PROJECT_NAME\" \"Template\"/PROJECT_NAME\" \"$PROJECT_NAME\"/g" "$TARGET_PCB"
    print_color "$GREEN" "Updated BOARD_NAME and PROJECT_NAME in PCB file"
fi

# Go back to project root
cd ..

# Step 4: Rename hardware directory
print_color "$BLUE" "Renaming 'hardware' directory to '$BOARD_NAME'"
if [ -d "hardware" ]; then
    mv "hardware" "$BOARD_NAME"
else
    print_color "$YELLOW" "Warning: 'hardware' directory not found"
fi

# Step 5: Rename KiCad project files
print_color "$BLUE" "Renaming KiCad project files from 'Template' to '$BOARD_NAME'"
if [ -d "$BOARD_NAME" ]; then
    cd "$BOARD_NAME"
    for file in Template.*; do
        if [ -f "$file" ]; then
            new_name="${file/Template/$BOARD_NAME}"
            mv "$file" "$new_name"
            print_color "$GREEN" "  Renamed: $file -> $new_name"
        fi
    done
    
    # Update Sheet Title in main schematic file
    MAIN_SCH="$BOARD_NAME.kicad_sch"
    if [ -f "$MAIN_SCH" ]; then
        sed -i "s/(title \"Template\")/(title \"$BOARD_NAME\")/g" "$MAIN_SCH"
        print_color "$GREEN" "  Updated Sheet Title in: $MAIN_SCH"
    fi
    
    cd ..
fi

# Step 5b: Update KiCad text variables
print_color "$BLUE" "Updating KiCad project text variables"
KICAD_PRO_FILE="$BOARD_NAME/$BOARD_NAME.kicad_pro"
CURRENT_DATE=$(date +"%d-%b-%Y")
COMPANY_VALUE="${COMPANY:-}"
update_kicad_text_variables "$KICAD_PRO_FILE" "$PROJECT_NAME" "$BOARD_NAME" "$DESIGNER" "$COMPANY_VALUE" "$CURRENT_DATE" "1.0.0"

# Step 5c: Update kibot_main.yaml
print_color "$BLUE" "Updating kibot_main.yaml"
KIBOT_MAIN="$BOARD_NAME/kibot_yaml/kibot_main.yaml"
if [ -f "$KIBOT_MAIN" ]; then
    COMPANY_VALUE_KIBOT="${COMPANY:-null}"
    sed -i "s/PROJECT_NAME: Project/PROJECT_NAME: $PROJECT_NAME/g" "$KIBOT_MAIN"
    sed -i "s/BOARD_NAME: Board/BOARD_NAME: $BOARD_NAME/g" "$KIBOT_MAIN"
    sed -i "s/COMPANY: Kampis-Elektroecke/COMPANY: $COMPANY_VALUE_KIBOT/g" "$KIBOT_MAIN"
    sed -i "s/DESIGNER: Daniel Kampert/DESIGNER: $DESIGNER/g" "$KIBOT_MAIN"
    sed -i "s|GIT_URL: 'https://github.com/Kampi/KiCad'|GIT_URL: '$GIT_URL'|g" "$KIBOT_MAIN"
    print_color "$GREEN" "Updated: $KIBOT_MAIN"
fi

# Step 6: Update .github/workflows files
print_color "$BLUE" "Updating .github/workflows files"
WORKFLOWS_DIR=".github/workflows"
if [ -d "$WORKFLOWS_DIR" ]; then
    for workflow_file in "$WORKFLOWS_DIR"/*.yaml; do
        if [ -f "$workflow_file" ]; then
            workflow_name=$(basename "$workflow_file")
            
            # Update all occurrences of master_branch
            sed -i "s/master_branch: main/master_branch: $MASTER_BRANCH/g" "$workflow_file"
            sed -i "s/master_branch: master/master_branch: $MASTER_BRANCH/g" "$workflow_file"
            
            # Update PCB-specific settings
            if [ "$workflow_name" = "pcb.yaml" ]; then
                sed -i "s/kicad_board: __Project__/kicad_board: $BOARD_NAME/g" "$workflow_file"
                sed -i "s/kibot_output_dir: Board/kibot_output_dir: $PROJECT_NAME/g" "$workflow_file"
                sed -i "s|kibot_output_path: board|kibot_output_path: ../production|g" "$workflow_file"
                sed -i "s/kibot_input_dir: hardware/kibot_input_dir: $BOARD_NAME/g" "$workflow_file"
                sed -i "s/kibot_variant: PRELIMINARY/kibot_variant: DRAFT/g" "$workflow_file"
            fi
            
            # Update component_release settings
            if [ "$workflow_name" = "component_release.yaml" ]; then
                sed -i "s/\\\$PROJECT_NAME/$PROJECT_NAME/g" "$workflow_file"
                sed -i "s/\\\$NAMESPACE/$GIT_USER/g" "$workflow_file"
            fi
            
            print_color "$GREEN" "Updated: $workflow_name"
        fi
    done
fi

# Step 7: Select and add license
LICENSE_SELECTION=$(show_license_menu)
LICENSE_INFO=$(get_license_info "$LICENSE_SELECTION")
IFS='|' read -r LICENSE_NAME LICENSE_BADGE LICENSE_KEY <<< "$LICENSE_INFO"
CURRENT_YEAR=$(date +%Y)

if [ "$LICENSE_NAME" != "None" ]; then
    print_color "$BLUE" "\nAdding license files"
    
    # Add license to root
    download_license "$LICENSE_KEY" "LICENSE" "$CURRENT_YEAR" "$DESIGNER"
    
    # Add license to subdirectories
    for dir in docs cad "$BOARD_NAME" 3d-print firmware; do
        if [ -d "$dir" ]; then
            download_license "$LICENSE_KEY" "$dir/LICENSE" "$CURRENT_YEAR" "$DESIGNER"
        fi
    done
fi

# Step 8: Update .github/.commit-msg-template
print_color "$BLUE" "Updating .github/.commit-msg-template"
COMMIT_TEMPLATE=".github/.commit-msg-template"
if [ -f "$COMMIT_TEMPLATE" ]; then
    sed -i "s/Signed-off-by:.*/Signed-off-by: $DESIGNER <$EMAIL>/g" "$COMMIT_TEMPLATE"
    print_color "$GREEN" "Updated: $COMMIT_TEMPLATE"
fi

# Step 9: Update README.md
print_color "$BLUE" "Updating README.md"
if [ -f "README.md" ]; then
    # Replace project name
    sed -i "s/\"\$Project\"/$PROJECT_NAME/g" "README.md"
    
    # Replace user, designer, and email
    sed -i "s/\"\$User\"/$GIT_USER/g" "README.md"
    sed -i "s/\"\$Designer\"/$DESIGNER/g" "README.md"
    sed -i "s/\"\$Email\"/$EMAIL/g" "README.md"
    
    # Update license badge
    if [ -n "$LICENSE_BADGE" ]; then
        sed -i "s|https://img.shields.io/badge/License-[^)]*)|https://img.shields.io/badge/License-$LICENSE_BADGE.svg)|g" "README.md"
        sed -i "s|https://opensource.org/license/[^)]*)|https://opensource.org/license/$LICENSE_KEY/)|g" "README.md"
    fi
    
    # Update GitHub URLs (remove .git extension if present)
    GIT_URL_CLEAN="${GIT_URL%.git}"
    sed -i "s|https://github.com/\"\$User\"/\"\$Project\"|$GIT_URL_CLEAN|g" "README.md"
    sed -i "s|github.com/[^/]*/[^/)]*|${GIT_URL_CLEAN#https://}|g" "README.md"
    
    # Update ToC anchor (lowercase for markdown)
    PROJECT_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    sed -i "s/#\"\$project\"/#$PROJECT_LOWER/g" "README.md"
    
    print_color "$GREEN" "Updated: README.md"
fi

# Step 9b: Update .github/workflows/documentation.yaml
print_color "$BLUE" "Updating .github/workflows/documentation.yaml"
DOCUMENTATION_YAML=".github/workflows/documentation.yaml"
if [ -f "$DOCUMENTATION_YAML" ]; then
    sed -i "s/\$PROJECT_NAME/$PROJECT_NAME/g" "$DOCUMENTATION_YAML"
    print_color "$GREEN" "Updated: $DOCUMENTATION_YAML"
fi

# Step 9c: Create basic AsciiDoc documentation
print_color "$BLUE" "Creating AsciiDoc documentation"
DOCS_DIR="docs"
if [ -d "$DOCS_DIR" ]; then
    cat > "$DOCS_DIR/index.adoc" << EOF
= $PROJECT_NAME Documentation
$DESIGNER <$EMAIL>
v1.0, $(date +%Y-%m-%d)
:toc: left
:toclevels: 3
:icons: font
:source-highlighter: highlight.js

== Overview

This document provides comprehensive documentation for the *$PROJECT_NAME* hardware project.

== Project Information

[cols="1,2"]
|===
|Project Name |$PROJECT_NAME
|Board Name |$BOARD_NAME
|Designer |$DESIGNER
|Email |$EMAIL
|Company |${COMPANY:-N/A}
|Repository |$GIT_URL
|License |${LICENSE_NAME:-TBD}
|===

== Getting Started

=== Prerequisites

* KiCad 7.0 or later
* Basic understanding of PCB design

=== Project Structure

Refer to the main README.md for detailed information about the project structure.

== Hardware Design

=== Schematic

TBD - Add schematic overview and block diagrams

=== PCB Layout

TBD - Add PCB layout information and design considerations

=== Bill of Materials (BoM)

TBD - Add component list and sourcing information

== Assembly Instructions

TBD - Add assembly steps and guidelines

== Testing & Validation

TBD - Add testing procedures and validation criteria

== Revision History

[cols="1,2,2,3"]
|===
|Version |Date |Author |Changes

|1.0
|$(date +%Y-%m-%d)
|$DESIGNER
|Initial release

|===
EOF
    print_color "$GREEN" "Created: $DOCS_DIR/index.adoc"
fi

# Step 10: Initialize Git repository
print_color "$BLUE" "\nInitializing Git repository"
git init

# Fix dubious ownership issues on network drives
CURRENT_PATH=$(pwd)
git config --global --add safe.directory "$CURRENT_PATH"

git config user.name "$DESIGNER"
git config user.email "$EMAIL"

# Set commit message template (local)
git config commit.template ".github/.commit-msg-template"
print_color "$GREEN" "Set commit message template to .github/.commit-msg-template"

# Set master as main branch
git branch -M master
print_color "$GREEN" "Set default branch to 'master'"

# Step 11: Add remote
git remote add origin "$GIT_URL"
print_color "$GREEN" "Added remote: $GIT_URL"

# Step 12: Initial commit
print_color "$BLUE" "Creating initial commit"
git add .

# Create commit message
git commit -m "chore: Initialize project $PROJECT_NAME

Initial project setup with KiCad template structure

Signed-off-by: $DESIGNER <$EMAIL>"

print_color "$GREEN" "Initial commit created"

# Step 13: Push to GitHub
print_color "$BLUE" "Pushing to GitHub"
read -p "Push to GitHub now? (y/N): " push_confirm
if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
    git push -u origin master
    print_color "$GREEN" "Pushed to GitHub successfully"
else
    print_color "$YELLOW" "Skipped push to GitHub. You can push later with: git push -u origin master"
fi

# Summary
print_color "$GREEN" "\n========================================"
print_color "$GREEN" "  Project Initialization Complete!     "
print_color "$GREEN" "========================================"
print_color "$BLUE" "\nProject Details:"
print_color "$BLUE" "  Project Name: $PROJECT_NAME"
print_color "$BLUE" "  Board Name: $BOARD_NAME"
print_color "$BLUE" "  Designer: $DESIGNER <$EMAIL>"
print_color "$BLUE" "  Git URL: $GIT_URL"
print_color "$BLUE" "  License: $LICENSE_NAME"
print_color "$BLUE" "\nNext steps:"
print_color "$BLUE" "  1. cd $PROJECT_NAME"
print_color "$BLUE" "  2. Review and customize the project files"
print_color "$BLUE" "  3. Start developing your hardware!"
