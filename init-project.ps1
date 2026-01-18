# PowerShell Script to Initialize a New KiCad Project
# Author: GitHub Copilot
# Date: 2026-01-18

param(
    [string]$KicadLibraryPath = $env:KICAD_LIBRARY
)

# ANSI Color Codes for Windows Terminal
$ESC = [char]27
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$RED = "$ESC[31m"
$BLUE = "$ESC[34m"
$NC = "$ESC[0m" # No Color

function Write-ColorOutput {
    param(
        [string]$Color,
        [string]$Message
    )
    Write-Host "${Color}${Message}${NC}"
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "",
        [bool]$Required = $true
    )
    
    if (-not $Required) {
        # Optional field - allow empty input
        $input = Read-Host "$Prompt (optional)"
        return $input
    } elseif ($DefaultValue) {
        # Has default value
        $input = Read-Host "$Prompt [$DefaultValue]"
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $DefaultValue
        }
        return $input
    } else {
        # Required field
        do {
            $input = Read-Host $Prompt
        } while ([string]::IsNullOrWhiteSpace($input))
        return $input
    }
}

function Get-PCBTemplates {
    param(
        [string]$HardwarePath
    )
    
    $templates = @()
    
    # Add Custom option (default Template.kicad_pcb)
    $templates += @{
        DisplayName = "Custom (default)"
        FileName = "Template.kicad_pcb"
        Manufacturer = "Custom"
        Thickness = "Custom"
        Layers = "Custom"
    }
    
    # Parse available template files
    $templateFiles = Get-ChildItem -Path $HardwarePath -Filter "Template - *.kicad_pcb"
    
    foreach ($file in $templateFiles) {
        # Pattern: Template - manufacturer_thickness_x-layer.kicad_pcb
        if ($file.Name -match '^Template - ([^_]+)_([^_]+)_(\d+)-layer\.kicad_pcb$') {
            $manufacturer = $matches[1]
            $thickness = $matches[2]
            $layers = $matches[3]
            
            $templates += @{
                DisplayName = "$manufacturer - $thickness - $layers layers"
                FileName = $file.Name
                Manufacturer = $manufacturer
                Thickness = $thickness
                Layers = $layers
            }
        }
    }
    
    return $templates
}

function Show-PCBTemplateMenu {
    param(
        [array]$Templates
    )
    
    Write-ColorOutput $BLUE "`n=== Select PCB Template ==="
    for ($i = 0; $i -lt $Templates.Count; $i++) {
        Write-Host "$($i + 1). $($Templates[$i].DisplayName)"
    }
    
    do {
        $selection = Read-Host "`nEnter selection (1-$($Templates.Count))"
        $selectionNum = [int]$selection
    } while ($selectionNum -lt 1 -or $selectionNum -gt $Templates.Count)
    
    return $Templates[$selectionNum - 1]
}

function Show-LicenseMenu {
    $licenses = @(
        @{Name="MIT"; Badge="MIT-yellow"; URL="mit"},
        @{Name="Apache 2.0"; Badge="Apache%202.0-blue"; URL="apache-2-0"},
        @{Name="GPL 3.0"; Badge="GPL%203.0-blue"; URL="gpl-3-0"},
        @{Name="LGPL 3.0"; Badge="LGPL%203.0-blue"; URL="lgpl-3-0"},
        @{Name="BSD 2-Clause"; Badge="BSD%202--Clause-orange"; URL="bsd-2-clause"},
        @{Name="BSD 3-Clause"; Badge="BSD%203--Clause-orange"; URL="bsd-3-clause"},
        @{Name="MPL 2.0"; Badge="MPL%202.0-brightgreen"; URL="mpl-2-0"},
        @{Name="AGPL 3.0"; Badge="AGPL%203.0-blue"; URL="agpl-3-0"},
        @{Name="Unlicense"; Badge="Unlicense-blue"; URL="unlicense"},
        @{Name="CC0 1.0"; Badge="CC0%201.0-lightgrey"; URL="cc0-1-0"},
        @{Name="None"; Badge=""; URL=""}
    )
    
    Write-ColorOutput $BLUE "`n=== Select Open Source License ==="
    for ($i = 0; $i -lt $licenses.Count; $i++) {
        Write-Host "$($i + 1). $($licenses[$i].Name)"
    }
    
    do {
        $selection = Read-Host "`nEnter selection (1-$($licenses.Count))"
        $selectionNum = [int]$selection
    } while ($selectionNum -lt 1 -or $selectionNum -gt $licenses.Count)
    
    return $licenses[$selectionNum - 1]
}

function Download-License {
    param(
        [string]$LicenseKey,
        [string]$DestinationPath,
        [string]$Year,
        [string]$CopyrightHolder
    )
    
    if ($LicenseKey -eq "" -or $LicenseKey -eq "none") {
        Write-ColorOutput $YELLOW "No license selected, skipping license file creation"
        return
    }
    
    # Convert to absolute path
    $absolutePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
    
    try {
        $url = "https://raw.githubusercontent.com/licenses/license-templates/master/templates/$LicenseKey.txt"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
        $content = $response.Content
        
        # Replace placeholders
        $content = $content -replace '\[year\]', $Year
        $content = $content -replace '\[fullname\]', $CopyrightHolder
        $content = $content -replace '\[email\]', ''
        
        [System.IO.File]::WriteAllText($absolutePath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-ColorOutput $GREEN "License file created: $DestinationPath"
    } catch {
        Write-ColorOutput $YELLOW "Failed to download license template: $($_.Exception.Message)"
        Write-ColorOutput $YELLOW "Creating placeholder license file"
        $placeholder = "License: $LicenseKey`n`nCopyright (c) $Year $CopyrightHolder`n`nAll rights reserved."
        [System.IO.File]::WriteAllText($absolutePath, $placeholder, [System.Text.UTF8Encoding]::new($false))
        Write-ColorOutput $GREEN "Placeholder license file created: $DestinationPath"
    }
}

# Main Script
Write-ColorOutput $BLUE "========================================"
Write-ColorOutput $BLUE "  KiCad Project Initialization Script  "
Write-ColorOutput $BLUE "========================================"

# Step 1: Get project information
$PROJECT_NAME = Get-UserInput "Enter project name"
$BOARD_NAME = Get-UserInput "Enter KiCad board name" $PROJECT_NAME
$DESIGNER = Get-UserInput "Enter designer name"
$EMAIL = Get-UserInput "Enter designer email"
$GIT_URL = Get-UserInput "Enter GitHub repository URL (e.g., https://github.com/user/repo)"

# Parse GitHub user and repo from URL
if ($GIT_URL -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
    $GIT_USER = $matches[1]
    $GIT_REPO = $matches[2]
} else {
    Write-ColorOutput $RED "Invalid GitHub URL format"
    exit 1
}

$COMPANY = Get-UserInput "Enter company name" "" -Required $false

# Step 2: Determine KiCad library path
if ([string]::IsNullOrWhiteSpace($KicadLibraryPath)) {
    $KicadLibraryPath = $PSScriptRoot
}

$TEMPLATE_PATH = Join-Path $KicadLibraryPath "__Project__"

if (-not (Test-Path $TEMPLATE_PATH)) {
    Write-ColorOutput $RED "Template directory not found: $TEMPLATE_PATH"
    exit 1
}

Write-ColorOutput $GREEN "Using template from: $TEMPLATE_PATH"

# Step 2b: Select PCB template
$pcbTemplates = Get-PCBTemplates -HardwarePath (Join-Path $TEMPLATE_PATH "hardware")
if ($pcbTemplates.Count -eq 0) {
    Write-ColorOutput $RED "No PCB templates found in template directory"
    exit 1
}

$selectedPCBTemplate = Show-PCBTemplateMenu -Templates $pcbTemplates
Write-ColorOutput $GREEN "Selected PCB template: $($selectedPCBTemplate.DisplayName)"

# Step 3: Create project directory
Write-ColorOutput $BLUE "`nCreating project directory: $PROJECT_NAME"
if (Test-Path $PROJECT_NAME) {
    Write-ColorOutput $RED "Directory '$PROJECT_NAME' already exists!"
    exit 1
}

Copy-Item -Path $TEMPLATE_PATH -Destination $PROJECT_NAME -Recurse
Set-Location $PROJECT_NAME

# Step 3b: Replace PCB template with selected one and remove all other templates
Write-ColorOutput $BLUE "Applying PCB template: $($selectedPCBTemplate.FileName)"
$sourcePCB = Join-Path "hardware" $selectedPCBTemplate.FileName
$targetPCB = Join-Path "hardware" "Template.kicad_pcb"

if ($selectedPCBTemplate.FileName -ne "Template.kicad_pcb") {
    if (Test-Path $sourcePCB) {
        Copy-Item -Path $sourcePCB -Destination $targetPCB -Force
        Write-ColorOutput $GREEN "Applied PCB template: $($selectedPCBTemplate.DisplayName)"
    } else {
        Write-ColorOutput $YELLOW "Warning: Selected template file not found, using default"
    }
}

# Remove all Template - *.kicad_pcb files (keep only Template.kicad_pcb)
Get-ChildItem -Path "hardware" -Filter "Template - *.kicad_pcb" | Remove-Item -Force
Write-ColorOutput $GREEN "Cleaned up unused PCB template files"

# Step 4: Rename hardware directory
Write-ColorOutput $BLUE "Renaming 'hardware' directory to '$BOARD_NAME'"
if (Test-Path "hardware") {
    Rename-Item -Path "hardware" -NewName $BOARD_NAME
} else {
    Write-ColorOutput $YELLOW "Warning: 'hardware' directory not found"
}

# Step 5: Rename KiCad project files
Write-ColorOutput $BLUE "Renaming KiCad project files from 'Template' to '$BOARD_NAME'"
Get-ChildItem -Path $BOARD_NAME -Filter "Template.*" | ForEach-Object {
    $newName = $_.Name -replace '^Template', $BOARD_NAME
    Rename-Item -Path $_.FullName -NewName $newName
    Write-ColorOutput $GREEN "  Renamed: $($_.Name) -> $newName"
}

# Step 6: Update .github/workflows/pcb.yaml
Write-ColorOutput $BLUE "Updating .github/workflows/pcb.yaml"
$pcbYamlPath = ".github/workflows/pcb.yaml"
if (Test-Path $pcbYamlPath) {
    $pcbYaml = Get-Content $pcbYamlPath -Raw
    
    # Update kicad_board
    $pcbYaml = $pcbYaml -replace 'kicad_board:\s*__Project__', "kicad_board: $BOARD_NAME"
    
    # Update kibot_input_dir
    $pcbYaml = $pcbYaml -replace 'kibot_input_dir:\s*hardware', "kibot_input_dir: $BOARD_NAME"
    
    # Add environment variables after the env: section
    $envSection = @"
env:
  # Project metadata
  PROJECT_NAME: $PROJECT_NAME
  BOARD_NAME: $BOARD_NAME
  COMPANY: $COMPANY
  DESIGNER: $DESIGNER
  GIT_URL: $GIT_URL

  # Name of the KiCad PCB file
"@
    
    $pcbYaml = $pcbYaml -replace 'env:\s*\n\s*#\s*Name of the KiCad PCB file', $envSection
    
    [System.IO.File]::WriteAllText((Resolve-Path $pcbYamlPath).Path, $pcbYaml, [System.Text.UTF8Encoding]::new($false))
    Write-ColorOutput $GREEN "Updated: $pcbYamlPath"
}

# Step 7: Select and add license
$license = Show-LicenseMenu
$currentYear = (Get-Date).Year

if ($license.Name -ne "None") {
    Write-ColorOutput $BLUE "`nAdding license files"
    
    # Add license to root
    Download-License -LicenseKey $license.URL -DestinationPath "LICENSE" -Year $currentYear -CopyrightHolder $DESIGNER
    
    # Add license to subdirectories
    $subdirs = @("docs", "cad", $BOARD_NAME, "3d-print", "firmware")
    foreach ($dir in $subdirs) {
        if (Test-Path $dir) {
            $licensePath = Join-Path $dir "LICENSE"
            Download-License -LicenseKey $license.URL -DestinationPath $licensePath -Year $currentYear -CopyrightHolder $DESIGNER
        }
    }
}

# Step 8: Update .github/.commit-msg-template
Write-ColorOutput $BLUE "Updating .github/.commit-msg-template"
$commitTemplatePath = ".github/.commit-msg-template"
if (Test-Path $commitTemplatePath) {
    $commitTemplate = Get-Content $commitTemplatePath -Raw
    $commitTemplate = $commitTemplate -replace 'Signed-off-by:.*', "Signed-off-by: $DESIGNER <$EMAIL>"
    [System.IO.File]::WriteAllText((Resolve-Path $commitTemplatePath).Path, $commitTemplate, [System.Text.UTF8Encoding]::new($false))
    Write-ColorOutput $GREEN "Updated: $commitTemplatePath"
}

# Step 9: Update README.md
Write-ColorOutput $BLUE "Updating README.md"
if (Test-Path "README.md") {
    $readme = Get-Content "README.md" -Raw
    
    # Replace project name (case-sensitive for ToC)
    $readme = $readme -replace '\"\$Project\"', $PROJECT_NAME
    $readme = $readme -creplace '#\"\$Project\"', "# $PROJECT_NAME"
    $readme = $readme -replace '\[\"' + [regex]::Escape('$Project') + '\"\]', "[$PROJECT_NAME]"
    
    # Replace user and email
    $readme = $readme -replace '\"\$User\"', $GIT_USER
    $readme = $readme -replace '\"\$Email\"', $EMAIL
    
    # Update license badge
    if ($license.Badge) {
        $readme = $readme -replace '\[!\[License\]\(https://img\.shields\.io/badge/License-[^\)]+\)\]\([^\)]+\)', 
            "[![License](https://img.shields.io/badge/License-$($license.Badge).svg)](https://opensource.org/license/$($license.URL)/)"
    }
    
    # Update GitHub badge
    $readme = $readme -replace 'https://github\.com/\"\$User\"/\"\$Project\"', $GIT_URL
    
    # Update wiki and project links
    $readme = $readme -replace 'github\.com/[^/]+/[^/\)]+/wiki', "$GIT_URL/wiki"
    $readme = $readme -replace 'github\.com/[^/]+/[^/\)]+/actions', "$GIT_URL/actions"
    
    # Update ToC anchor (lowercase for markdown)
    $projectLower = $PROJECT_NAME.ToLower() -replace '\s+', '-' -replace '[^\w-]', ''
    $readme = $readme -replace '#\"\$project\"', "#$projectLower"
    
    # Use UTF8 without BOM to preserve emojis
    [System.IO.File]::WriteAllText((Resolve-Path "README.md").Path, $readme, [System.Text.UTF8Encoding]::new($false))
    Write-ColorOutput $GREEN "Updated: README.md"
}

# Step 10: Initialize Git repository
Write-ColorOutput $BLUE "`nInitializing Git repository"
git init

# Fix dubious ownership issues on network drives
$currentPath = (Get-Location).Path
git config --global --add safe.directory $currentPath

git config user.name $DESIGNER
git config user.email $EMAIL

# Set commit message template (local)
git config commit.template ".github/.commit-msg-template"
Write-ColorOutput $GREEN "Set commit message template to .github/.commit-msg-template"

# Set master as main branch
git branch -M master
Write-ColorOutput $GREEN "Set default branch to 'master'"

# Step 11: Add remote
git remote add origin $GIT_URL
Write-ColorOutput $GREEN "Added remote: $GIT_URL"

# Step 12: Initial commit
Write-ColorOutput $BLUE "Creating initial commit"
git add .github .gitignore

# Create commit message from template
$commitMsg = @"
chore: Initialize project $PROJECT_NAME

Initial project setup with KiCad template structure

Signed-off-by: $DESIGNER <$EMAIL>
"@

git commit -m $commitMsg
Write-ColorOutput $GREEN "Initial commit created"

# Step 13: Push to GitHub
Write-ColorOutput $BLUE "Pushing to GitHub"
$pushConfirm = Read-Host "Push to GitHub now? (y/N)"
if ($pushConfirm -eq 'y' -or $pushConfirm -eq 'Y') {
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
Write-ColorOutput $BLUE "  License: $($license.Name)"
Write-ColorOutput $BLUE "`nNext steps:"
Write-ColorOutput $BLUE "  1. cd $PROJECT_NAME"
Write-ColorOutput $BLUE "  2. Review and customize the project files"
Write-ColorOutput $BLUE "  3. Start developing your hardware!"
