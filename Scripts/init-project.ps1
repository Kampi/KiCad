# PowerShell Script to Initialize a New KiCad Project
# Author: GitHub Copilot
# Date: 2026-01-21

param(
    [string]$KicadLibraryPath = $env:KICAD_LIBRARY
)

# ANSI Color Codes
$ESC = [char]27
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$RED = "$ESC[31m"
$BLUE = "$ESC[34m"
$NC = "$ESC[0m"

function Write-ColorOutput {
    param([string]$Color, [string]$Message)
    Write-Host "${Color}${Message}${NC}"
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "",
        [bool]$Required = $true
    )
    
    if (-not $Required) {
        $input = Read-Host "$Prompt (optional)"
        return $input
    } elseif ($DefaultValue) {
        $input = Read-Host "$Prompt [$DefaultValue]"
        if ([string]::IsNullOrWhiteSpace($input)) { return $DefaultValue }
        return $input
    } else {
        do {
            $input = Read-Host $Prompt
        } while ([string]::IsNullOrWhiteSpace($input))
        return $input
    }
}

function Get-PCBTemplates {
    param([string]$HardwarePath)
    
    $templates = @()
    $templateFiles = Get-ChildItem -Path $HardwarePath -Filter "Template - *.kicad_pcb" -ErrorAction SilentlyContinue
    
    foreach ($file in $templateFiles) {
        if ($file.Name -match '^Template - ([^_]+)_([^_]+)_(\d+)-layer\.kicad_pcb$') {
            $templates += @{
                DisplayName = "$($matches[1]) - $($matches[2]) - $($matches[3]) layers"
                FileName = $file.Name
                Manufacturer = $matches[1]
                Thickness = $matches[2]
                Layers = $matches[3]
            }
        }
    }
    
    return $templates
}

function Show-PCBTemplateMenu {
    param([array]$Templates)
    
    Write-ColorOutput $BLUE "`n=== Select PCB Template ==="
    for ($i = 0; $i -lt $Templates.Count; $i++) {
        Write-Host "$($i + 1). $($Templates[$i].DisplayName)"
    }
    
    do {
        $selection = Read-Host "`nEnter selection (1-$($Templates.Count))"
        $index = [int]$selection - 1
    } while ($index -lt 0 -or $index -ge $Templates.Count)
    
    return $Templates[$index]
}

function Show-LicenseMenu {
    Write-ColorOutput $BLUE "`n=== Select Open Source License ==="
    Write-Host "1. MIT"
    Write-Host "2. Apache 2.0"
    Write-Host "3. GPL 3.0"
    Write-Host "4. LGPL 3.0"
    Write-Host "5. BSD 2-Clause"
    Write-Host "6. BSD 3-Clause"
    Write-Host "7. MPL 2.0"
    Write-Host "8. AGPL 3.0"
    Write-Host "9. Unlicense"
    Write-Host "10. CC0 1.0"
    Write-Host "11. None"
    
    do {
        $selection = Read-Host "`nEnter selection (1-11)"
    } while ($selection -notmatch '^([1-9]|1[01])$')
    
    return [int]$selection
}
function Update-KiCadTextVariables {
    param(
        [string]$KicadProFile,
        [string]$ProjectName,
        [string]$BoardName,
        [string]$Designer,
        [string]$Company,
        [string]$Date,
        [string]$Revision
    )
    
    if (-not (Test-Path $KicadProFile)) {
        Write-ColorOutput $YELLOW "Warning: KiCad project file not found: $KicadProFile"
        return
    }
    
    # Read the JSON file
    $jsonContent = Get-Content $KicadProFile -Raw | ConvertFrom-Json
    
    # Update text_variables
    if ($null -eq $jsonContent.text_variables) {
        $jsonContent | Add-Member -MemberType NoteProperty -Name "text_variables" -Value @{}
    }
    
    $jsonContent.text_variables.PROJECT_NAME = $ProjectName
    $jsonContent.text_variables.BOARD_NAME = $BoardName
    $jsonContent.text_variables.DESIGNER = $Designer
    $jsonContent.text_variables.COMPANY = if ([string]::IsNullOrWhiteSpace($Company)) { "null" } else { $Company }
    $jsonContent.text_variables.RELEASE_DATE = $Date
    $jsonContent.text_variables.RELEASE_DATE_NUM = (Get-Date -Format "yyyy-MM-dd")
    $jsonContent.text_variables.REVISION = $Revision
    
    # Write back to file with proper formatting
    $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $KicadProFile
    
    Write-ColorOutput $GREEN "Updated text_variables in: $KicadProFile"
}
function Get-LicenseInfo {
    param([int]$Selection)
    
    $licenses = @{
        1 = @{ Name = "MIT"; Badge = "MIT-yellow"; Key = "mit" }
        2 = @{ Name = "Apache 2.0"; Badge = "Apache%202.0-blue"; Key = "apache-2-0" }
        3 = @{ Name = "GPL 3.0"; Badge = "GPL%203.0-blue"; Key = "gpl-3-0" }
        4 = @{ Name = "LGPL 3.0"; Badge = "LGPL%203.0-blue"; Key = "lgpl-3-0" }
        5 = @{ Name = "BSD 2-Clause"; Badge = "BSD%202--Clause-orange"; Key = "bsd-2-clause" }
        6 = @{ Name = "BSD 3-Clause"; Badge = "BSD%203--Clause-orange"; Key = "bsd-3-clause" }
        7 = @{ Name = "MPL 2.0"; Badge = "MPL%202.0-brightgreen"; Key = "mpl-2-0" }
        8 = @{ Name = "AGPL 3.0"; Badge = "AGPL%203.0-blue"; Key = "agpl-3-0" }
        9 = @{ Name = "Unlicense"; Badge = "Unlicense-blue"; Key = "unlicense" }
        10 = @{ Name = "CC0 1.0"; Badge = "CC0%201.0-lightgrey"; Key = "cc0-1-0" }
        11 = @{ Name = "None"; Badge = ""; Key = "" }
    }
    
    return $licenses[$Selection]
}

function Download-License {
    param(
        [string]$LicenseKey,
        [string]$Destination,
        [string]$Year,
        [string]$Author
    )
    
    if ([string]::IsNullOrWhiteSpace($LicenseKey)) {
        Write-ColorOutput $YELLOW "No license selected, skipping license file creation"
        return
    }
    
    $url = "https://raw.githubusercontent.com/licenses/license-templates/master/templates/$LicenseKey.txt"
    
    try {
        $content = Invoke-WebRequest -Uri $url -UseBasicParsing | Select-Object -ExpandProperty Content
        $content = $content -replace '\[year\]', $Year
        $content = $content -replace '\[fullname\]', $Author
        $content | Out-File -FilePath $Destination -Encoding UTF8
        Write-ColorOutput $GREEN "License file created: $Destination"
    } catch {
        Write-ColorOutput $YELLOW "Failed to download license template from $url"
        Write-ColorOutput $YELLOW "Creating placeholder license file"
        "LICENSE PLACEHOLDER - Please replace with actual license text" | Out-File -FilePath $Destination -Encoding UTF8
        Write-ColorOutput $GREEN "Placeholder license file created: $Destination"
    }
}

# Main Script
Write-ColorOutput $BLUE "========================================"
Write-ColorOutput $BLUE "  KiCad Project Initialization Script  "
Write-ColorOutput $BLUE "========================================"

# Step 1: Get project information
$PROJECT_NAME = Get-UserInput "Enter project name"
$BOARD_NAME = Get-UserInput "Enter KiCad board name" -DefaultValue $PROJECT_NAME
$DESIGNER = Get-UserInput "Enter designer name"
$EMAIL = Get-UserInput "Enter designer email"
$GIT_URL = Get-UserInput "Enter GitHub repository URL (e.g., https://github.com/user/repo)"
$MASTER_BRANCH = Get-UserInput "Enter main branch name" -DefaultValue "main"

# Parse GitHub user and repo from URL
if ($GIT_URL -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
    $GIT_USER = $matches[1]
    $GIT_REPO = $matches[2]
} else {
    Write-ColorOutput $RED "Invalid GitHub URL format"
    exit 1
}

$COMPANY = Get-UserInput "Enter company name" -Required $false

# Step 2: Determine KiCad library path
# Script is in Scripts/ folder, template is one level up
$SCRIPT_DIR = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrEmpty($KicadLibraryPath)) {
    $KicadLibraryPath = Split-Path -Parent $SCRIPT_DIR
}

$TEMPLATE_PATH = Join-Path $KicadLibraryPath "__Project__"

if (-not (Test-Path $TEMPLATE_PATH)) {
    Write-ColorOutput $RED "Template directory not found: $TEMPLATE_PATH"
    Write-ColorOutput $YELLOW "Expected path: $TEMPLATE_PATH"
    Write-ColorOutput $YELLOW "Make sure __Project__ exists in the KiCad root directory"
    exit 1
}

Write-ColorOutput $GREEN "Using template from: $TEMPLATE_PATH"

# Step 2b: Select PCB template
Write-ColorOutput $BLUE "`nScanning for PCB templates..."
$PCB_TEMPLATES = Get-PCBTemplates -HardwarePath (Join-Path $TEMPLATE_PATH "hardware")

if ($PCB_TEMPLATES.Count -eq 0) {
    Write-ColorOutput $RED "No PCB templates found in template directory"
    exit 1
}

$SELECTED_PCB = Show-PCBTemplateMenu -Templates $PCB_TEMPLATES
$PCB_FILENAME = $SELECTED_PCB.FileName
$PCB_MANUFACTURER = $SELECTED_PCB.Manufacturer
$PCB_THICKNESS = $SELECTED_PCB.Thickness
$PCB_LAYERS = $SELECTED_PCB.Layers

Write-ColorOutput $GREEN "Selected PCB template: $PCB_MANUFACTURER - $PCB_THICKNESS - $PCB_LAYERS layers"

# Step 3: Create project directory
Write-ColorOutput $BLUE "`nCreating project directory: $PROJECT_NAME"

if (Test-Path $PROJECT_NAME) {
    Write-ColorOutput $RED "Directory '$PROJECT_NAME' already exists!"
    exit 1
}

Copy-Item -Path $TEMPLATE_PATH -Destination $PROJECT_NAME -Recurse
Set-Location $PROJECT_NAME

# Step 3b: Replace PCB template with selected one
Write-ColorOutput $BLUE "Applying PCB template: $PCB_FILENAME"
$SOURCE_PCB = $PCB_FILENAME
$TARGET_PCB = "Template.kicad_pcb"

Set-Location hardware

if (Test-Path $SOURCE_PCB) {
    Copy-Item -Path $SOURCE_PCB -Destination $TARGET_PCB -Force
    Write-ColorOutput $GREEN "Applied PCB template: $PCB_MANUFACTURER - $PCB_THICKNESS - $PCB_LAYERS layers"
} else {
    Write-ColorOutput $RED "Error: Selected template file not found: $SOURCE_PCB"
    exit 1
}

# Remove all Template - *.kicad_pcb files
Get-ChildItem -Filter "Template - *.kicad_pcb" | Remove-Item
Write-ColorOutput $GREEN "Cleaned up unused PCB template files"

# Replace "Template" with BOARD_NAME in the PCB file
Write-ColorOutput $BLUE "Updating board name in PCB file"
if (Test-Path $TARGET_PCB) {
    (Get-Content $TARGET_PCB) -replace 'BOARD_NAME" "Template"', "BOARD_NAME`" `"$BOARD_NAME`"" | Set-Content $TARGET_PCB
    (Get-Content $TARGET_PCB) -replace 'PROJECT_NAME" "Template"', "PROJECT_NAME`" `"$PROJECT_NAME`"" | Set-Content $TARGET_PCB
    Write-ColorOutput $GREEN "Updated BOARD_NAME and PROJECT_NAME in PCB file"
}

Set-Location ..

# Step 4: Rename hardware directory
Write-ColorOutput $BLUE "Renaming 'hardware' directory to '$BOARD_NAME'"
if (Test-Path "hardware") {
    Rename-Item -Path "hardware" -NewName $BOARD_NAME
}

# Step 5: Rename KiCad project files
Write-ColorOutput $BLUE "Renaming KiCad project files from 'Template' to '$BOARD_NAME'"
if (Test-Path $BOARD_NAME) {
    Set-Location $BOARD_NAME
    Get-ChildItem -Filter "Template.*" | ForEach-Object {
        $newName = $_.Name -replace "^Template", $BOARD_NAME
        Rename-Item -Path $_.Name -NewName $newName
        Write-ColorOutput $GREEN "  Renamed: $($_.Name) -> $newName"
    }
    
    # Update Sheet Title in main schematic file
    $MAIN_SCH = "$BOARD_NAME.kicad_sch"
    if (Test-Path $MAIN_SCH) {
        (Get-Content $MAIN_SCH) -replace '\(title "Template"\)', "(title `"$BOARD_NAME`")" | Set-Content $MAIN_SCH
        Write-ColorOutput $GREEN "  Updated Sheet Title in: $MAIN_SCH"
    }
    
    Set-Location ..
}

# Step 5b: Update KiCad text variables
Write-ColorOutput $BLUE "Updating KiCad project text variables"
$KICAD_PRO_FILE = Join-Path $BOARD_NAME "$BOARD_NAME.kicad_pro"
$CURRENT_DATE = Get-Date -Format "dd-MMM-yyyy"
$COMPANY_VALUE = if ([string]::IsNullOrWhiteSpace($COMPANY)) { "" } else { $COMPANY }
Update-KiCadTextVariables -KicadProFile $KICAD_PRO_FILE -ProjectName $PROJECT_NAME -BoardName $BOARD_NAME -Designer $DESIGNER -Company $COMPANY_VALUE -Date $CURRENT_DATE -Revision "1.0.0"

# Step 5c: Update kibot_main.yaml
Write-ColorOutput $BLUE "Updating kibot_main.yaml"
$KIBOT_MAIN = Join-Path $BOARD_NAME "kibot_yaml\kibot_main.yaml"
if (Test-Path $KIBOT_MAIN) {
    $COMPANY_VALUE_KIBOT = if ([string]::IsNullOrWhiteSpace($COMPANY)) { "null" } else { $COMPANY }
    (Get-Content $KIBOT_MAIN -Raw) `
        -replace "PROJECT_NAME: Project", "PROJECT_NAME: $PROJECT_NAME" `
        -replace "BOARD_NAME: Board", "BOARD_NAME: $BOARD_NAME" `
        -replace "COMPANY: Kampis-Elektroecke", "COMPANY: $COMPANY_VALUE_KIBOT" `
        -replace "DESIGNER: Daniel Kampert", "DESIGNER: $DESIGNER" `
        -replace "GIT_URL: 'https://github.com/Kampi/KiCad'", "GIT_URL: '$GIT_URL'" |
        Set-Content $KIBOT_MAIN
    Write-ColorOutput $GREEN "Updated: $KIBOT_MAIN"
}

# Step 6: Update .github/workflows files
Write-ColorOutput $BLUE "Updating .github/workflows files"
$WORKFLOWS_DIR = ".github\workflows"
if (Test-Path $WORKFLOWS_DIR) {
    Get-ChildItem -Path $WORKFLOWS_DIR -Filter "*.yaml" | ForEach-Object {
        $workflowFile = $_.FullName
        $workflowContent = Get-Content $workflowFile -Raw
        
        # Update all occurrences of master_branch
        $workflowContent = $workflowContent -replace 'master_branch: main', "master_branch: $MASTER_BRANCH"
        $workflowContent = $workflowContent -replace 'master_branch: master', "master_branch: $MASTER_BRANCH"
        
        # Update PCB-specific settings
        if ($_.Name -eq 'pcb.yaml') {
            $workflowContent = $workflowContent -replace 'kicad_board: __Project__', "kicad_board: $BOARD_NAME"
            $workflowContent = $workflowContent -replace 'kibot_output_dir: Board', "kibot_output_dir: $PROJECT_NAME"
            $workflowContent = $workflowContent -replace 'kibot_output_path: board', 'kibot_output_path: ../production'
            $workflowContent = $workflowContent -replace 'kibot_input_dir: hardware', "kibot_input_dir: $BOARD_NAME"
            $workflowContent = $workflowContent -replace 'kibot_variant: PRELIMINARY', 'kibot_variant: DRAFT'
        }
        
        # Update component_release settings
        if ($_.Name -eq 'component_release.yaml') {
            $workflowContent = $workflowContent -replace '\$PROJECT_NAME', $PROJECT_NAME
            $workflowContent = $workflowContent -replace '\$NAMESPACE', $GIT_USER
        }
        
        $workflowContent | Set-Content $workflowFile
        Write-ColorOutput $GREEN "Updated: $($_.Name)"
    }
}

# Step 7: Select and add license
$LICENSE_SELECTION = Show-LicenseMenu
$LICENSE_INFO = Get-LicenseInfo -Selection $LICENSE_SELECTION
$LICENSE_NAME = $LICENSE_INFO.Name
$LICENSE_BADGE = $LICENSE_INFO.Badge
$LICENSE_KEY = $LICENSE_INFO.Key
$CURRENT_YEAR = (Get-Date).Year

if ($LICENSE_NAME -ne "None") {
    Write-ColorOutput $BLUE "`nAdding license files"
    
    Download-License -LicenseKey $LICENSE_KEY -Destination "LICENSE" -Year $CURRENT_YEAR -Author $DESIGNER
    
    foreach ($dir in @("docs", "cad", $BOARD_NAME, "3d-print", "firmware")) {
        if (Test-Path $dir) {
            Download-License -LicenseKey $LICENSE_KEY -Destination "$dir\LICENSE" -Year $CURRENT_YEAR -Author $DESIGNER
        }
    }
}

# Step 8: Update .github/.commit-msg-template
Write-ColorOutput $BLUE "Updating .github/.commit-msg-template"
$COMMIT_TEMPLATE = ".github\.commit-msg-template"
if (Test-Path $COMMIT_TEMPLATE) {
    (Get-Content $COMMIT_TEMPLATE) -replace 'Signed-off-by:.*', "Signed-off-by: $DESIGNER <$EMAIL>" |
        Set-Content $COMMIT_TEMPLATE
    Write-ColorOutput $GREEN "Updated: $COMMIT_TEMPLATE"
}

# Step 9: Update README.md
Write-ColorOutput $BLUE "Updating README.md"
if (Test-Path "README.md") {
    $content = Get-Content "README.md" -Raw
    $content = $content -replace '"\$Project"', $PROJECT_NAME
    $content = $content -replace '"\$User"', $GIT_USER
    $content = $content -replace '"\$Designer"', $DESIGNER
    $content = $content -replace '"\$Email"', $EMAIL
    
    if (-not [string]::IsNullOrWhiteSpace($LICENSE_BADGE)) {
        $content = $content -replace 'https://img\.shields\.io/badge/License-[^)]*\)', "https://img.shields.io/badge/License-$LICENSE_BADGE.svg)"
        $content = $content -replace 'https://opensource\.org/license/[^)]*\)', "https://opensource.org/license/$LICENSE_KEY/)"
    }
    
    # Remove .git extension if present
    $GIT_URL_CLEAN = $GIT_URL -replace '\.git$', ''
    $content = $content -replace 'https://github\.com/"\$User"/"\$Project"', $GIT_URL_CLEAN
    
    $PROJECT_LOWER = $PROJECT_NAME.ToLower() -replace '[^a-z0-9-]', '' -replace ' ', '-'
    $content = $content -replace '#"\$project"', "#$PROJECT_LOWER"
    
    $content | Set-Content "README.md"
    Write-ColorOutput $GREEN "Updated: README.md"
}

# Step 9b: Update .github/workflows/documentation.yaml
Write-ColorOutput $BLUE "Updating .github/workflows/documentation.yaml"
$DOCUMENTATION_YAML = ".github\workflows\documentation.yaml"
if (Test-Path $DOCUMENTATION_YAML) {
    (Get-Content $DOCUMENTATION_YAML) -replace '\$PROJECT_NAME', $PROJECT_NAME |
        Set-Content $DOCUMENTATION_YAML
    Write-ColorOutput $GREEN "Updated: $DOCUMENTATION_YAML"
}

# Step 9c: Create basic AsciiDoc documentation
Write-ColorOutput $BLUE "Creating AsciiDoc documentation"
$DOCS_DIR = "docs"
if (Test-Path $DOCS_DIR) {
    $asciidocContent = @"
= $PROJECT_NAME Documentation
$DESIGNER <$EMAIL>
v1.0, $(Get-Date -Format 'yyyy-MM-dd')
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
|Company |$(if ($COMPANY) { $COMPANY } else { 'N/A' })
|Repository |$GIT_URL
|License |$(if ($LICENSE_NAME) { $LICENSE_NAME } else { 'TBD' })
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
|$(Get-Date -Format 'yyyy-MM-dd')
|$DESIGNER
|Initial release

|===
"@
    $asciidocContent | Out-File -FilePath "$DOCS_DIR\index.adoc" -Encoding UTF8
    Write-ColorOutput $GREEN "Created: $DOCS_DIR\index.adoc"
}

# Step 10: Initialize Git repository
Write-ColorOutput $BLUE "`nInitializing Git repository"
git init

$CURRENT_PATH = (Get-Location).Path
git config --global --add safe.directory $CURRENT_PATH

git config user.name $DESIGNER
git config user.email $EMAIL

git config commit.template ".github/.commit-msg-template"
Write-ColorOutput $GREEN "Set commit message template to .github/.commit-msg-template"

git branch -M master
Write-ColorOutput $GREEN "Set default branch to 'master'"

# Step 11: Add remote
git remote add origin $GIT_URL
Write-ColorOutput $GREEN "Added remote: $GIT_URL"

# Step 12: Initial commit
Write-ColorOutput $BLUE "Creating initial commit"
git add .

$commitMessage = @"
chore: Initialize project $PROJECT_NAME

Initial project setup with KiCad template structure

Signed-off-by: $DESIGNER <$EMAIL>
"@

git commit -m $commitMessage
Write-ColorOutput $GREEN "Initial commit created"

# Step 13: Push to GitHub
Write-ColorOutput $BLUE "Pushing to GitHub"
$pushConfirm = Read-Host "Push to GitHub now? (y/N)"
if ($pushConfirm -match '^[Yy]$') {
    git push -u origin master
    Write-ColorOutput $GREEN "Pushed to GitHub successfully"
} else {
    Write-ColorOutput $YELLOW "Skipped push to GitHub. You can push later with: git push -u origin master"
}

# Summary
Write-ColorOutput $GREEN "`n========================================"
Write-ColorOutput $GREEN "  Project Initialization Complete!     "
Write-ColorOutput $GREEN "========================================"
Write-ColorOutput $BLUE "`nProject Details:"
Write-ColorOutput $BLUE "  Project Name: $PROJECT_NAME"
Write-ColorOutput $BLUE "  Board Name: $BOARD_NAME"
Write-ColorOutput $BLUE "  Designer: $DESIGNER <$EMAIL>"
Write-ColorOutput $BLUE "  Git URL: $GIT_URL"
Write-ColorOutput $BLUE "  License: $LICENSE_NAME"
Write-ColorOutput $BLUE "`nNext steps:"
Write-ColorOutput $BLUE "  1. cd $PROJECT_NAME"
Write-ColorOutput $BLUE "  2. Review and customize the project files"
Write-ColorOutput $BLUE "  3. Start developing your hardware!"
