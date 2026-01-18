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
    
    # Add Custom option (default Template.kicad_pcb)
    templates+=("Template.kicad_pcb|Custom|Custom|Custom")
    display_names+=("Custom (default)")
    
    # Parse available template files
    if [ -d "$hardware_path" ]; then
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            # Pattern: Template - manufacturer_thickness_x-layer.kicad_pcb
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
    
    print_color "$BLUE" "\n=== Select PCB Template ==="
    
    for i in "${!templates[@]}"; do
        IFS='|' read -r filename manufacturer thickness layers <<< "${templates[$i]}"
        local display_name
        if [ "$manufacturer" = "Custom" ]; then
            display_name="Custom (default)"
        else
            display_name="$manufacturer - $thickness - $layers layers"
        fi
        echo "$((i + 1)). $display_name"
    done
    
    local selection
    while true; do
        read -p $'\nEnter selection (1-'"${#templates[@]}"'): ' selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#templates[@]}" ]; then
            break
        fi
        print_color "$RED" "Invalid selection. Please enter a number between 1 and ${#templates[@]}."
    done
    
    echo "$((selection - 1))"
}

# Function to show license menu
show_license_menu() {
    print_color "$BLUE" "\n=== Select Open Source License ==="
    echo "1. MIT"
    echo "2. Apache 2.0"
    echo "3. GPL 3.0"
    echo "4. LGPL 3.0"
    echo "5. BSD 2-Clause"
    echo "6. BSD 3-Clause"
    echo "7. MPL 2.0"
    echo "8. AGPL 3.0"
    echo "9. Unlicense"
    echo "10. CC0 1.0"
    echo "11. None"
    
    local selection
    while true; do
        read -p $'\nEnter selection (1-11): ' selection
        if [[ "$selection" =~ ^[1-9]$|^1[01]$ ]]; then
            break
        fi
        print_color "$RED" "Invalid selection. Please enter a number between 1 and 11."
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

# Step 2: Determine KiCad library path
KICAD_LIBRARY="${KICAD_LIBRARY:-$(dirname "$0")}"
TEMPLATE_PATH="$KICAD_LIBRARY/__Project__"

if [ ! -d "$TEMPLATE_PATH" ]; then
    print_color "$RED" "Template directory not found: $TEMPLATE_PATH"
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

if [ "$PCB_MANUFACTURER" = "Custom" ]; then
    print_color "$GREEN" "Selected PCB template: Custom (default)"
else
    print_color "$GREEN" "Selected PCB template: $PCB_MANUFACTURER - $PCB_THICKNESS - $PCB_LAYERS layers"
fi

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
SOURCE_PCB="hardware/$PCB_FILENAME"
TARGET_PCB="hardware/Template.kicad_pcb"

if [ "$PCB_FILENAME" != "Template.kicad_pcb" ]; then
    if [ -f "$SOURCE_PCB" ]; then
        cp "$SOURCE_PCB" "$TARGET_PCB"
        if [ "$PCB_MANUFACTURER" = "Custom" ]; then
            print_color "$GREEN" "Applied PCB template: Custom (default)"
        else
            print_color "$GREEN" "Applied PCB template: $PCB_MANUFACTURER - $PCB_THICKNESS - $PCB_LAYERS layers"
        fi
    else
        print_color "$YELLOW" "Warning: Selected template file not found, using default"
    fi
fi

# Remove all Template - *.kicad_pcb files (keep only Template.kicad_pcb)
find hardware -name "Template - *.kicad_pcb" -type f -delete
print_color "$GREEN" "Cleaned up unused PCB template files"

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
    cd ..
fi

# Step 6: Update .github/workflows/pcb.yaml
print_color "$BLUE" "Updating .github/workflows/pcb.yaml"
PCB_YAML=".github/workflows/pcb.yaml"
if [ -f "$PCB_YAML" ]; then
    # Update kicad_board
    sed -i "s/kicad_board: __Project__/kicad_board: $BOARD_NAME/g" "$PCB_YAML"
    
    # Update kibot_input_dir
    sed -i "s/kibot_input_dir: hardware/kibot_input_dir: $BOARD_NAME/g" "$PCB_YAML"
    
    # Add environment variables after env:
    sed -i "/^env:/a\\
  # Project metadata\\
  PROJECT_NAME: $PROJECT_NAME\\
  BOARD_NAME: $BOARD_NAME\\
  COMPANY: $COMPANY\\
  DESIGNER: $DESIGNER\\
  GIT_URL: $GIT_URL\\
\\
  # Name of the KiCad PCB file" "$PCB_YAML"
    
    print_color "$GREEN" "Updated: $PCB_YAML"
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
    
    # Replace user and email
    sed -i "s/\"\$User\"/$GIT_USER/g" "README.md"
    sed -i "s/\"\$Email\"/$EMAIL/g" "README.md"
    
    # Update license badge
    if [ -n "$LICENSE_BADGE" ]; then
        sed -i "s|https://img.shields.io/badge/License-[^)]*)|https://img.shields.io/badge/License-$LICENSE_BADGE.svg)|g" "README.md"
        sed -i "s|https://opensource.org/license/[^)]*)|https://opensource.org/license/$LICENSE_KEY/)|g" "README.md"
    fi
    
    # Update GitHub URLs
    sed -i "s|https://github.com/\"\$User\"/\"\$Project\"|$GIT_URL|g" "README.md"
    sed -i "s|github.com/[^/]*/[^/)]*|${GIT_URL#https://}|g" "README.md"
    
    # Update ToC anchor (lowercase for markdown)
    PROJECT_LOWER=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    sed -i "s/#\"\$project\"/#$PROJECT_LOWER/g" "README.md"
    
    print_color "$GREEN" "Updated: README.md"
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
git add .github .gitignore

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
