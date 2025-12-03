<#
.SYNOPSIS
	Scans for fully transparent PNG textures in the .default directory and updates progress.jsonc with the results.

.DESCRIPTION
	This script analyzes all PNG image files in the .default directory to identify textures that are completely transparent
	(all pixels have alpha value of 0). It then updates the progress.jsonc configuration file with a list of these transparent
	textures, storing their relative paths from the .default directory.
	
	The script performs the following operations:
	1. Loads the System.Drawing assembly for image processing
	2. Recursively scans the .default directory for PNG files
	3. Analyzes each image pixel-by-pixel to determine if it's fully transparent
	4. Reads the existing progress.jsonc file (handling JSONC comments)
	5. Updates or adds the "transparents" field with the list of transparent texture paths
	6. Writes the updated JSON back to progress.jsonc
	7. Displays a summary of findings

.PARAMETER None
	This script does not accept parameters.

.EXAMPLE
	.\ignore.ps1
	Scans the .default directory and updates progress.jsonc with transparent textures.

.NOTES
	File Name      : ignore.ps1
	Prerequisite   : PowerShell 5.1 or higher, System.Drawing assembly
	Dependencies   : Requires .default directory and progress.jsonc file to exist
	
	The script expects the following directory structure:
	- Script location: <repo>/.github/scripts/
	- Default textures: <repo>/.default/
	- Progress file: <repo>/.github/configs/progress.jsonc

.LINK
	https://docs.microsoft.com/en-us/dotnet/api/system.drawing

.OUTPUTS
	Updates the progress.jsonc file with a "transparents" array containing relative paths
	to all fully transparent PNG textures found in the .default directory.

.INPUTS
	This script does not accept pipeline input.
#>

# Load System.Drawing assembly for image processing
Add-Type -AssemblyName System.Drawing

# Get the script directory and set paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$defaultDir = Join-Path -Path $repoRoot -ChildPath ".default"
$progressJsonPath = Join-Path -Path $scriptDir -ChildPath "..\configs\progress.jsonc"

Write-Host "Scanning for fully transparent textures in .default directory..." -ForegroundColor Cyan

# Function to check if an image is fully transparent
function Test-FullyTransparent {
	param(
		[string]$imagePath
	)
	
	try {
		# Load the image using System.Drawing
		$image = [System.Drawing.Image]::FromFile($imagePath)
		$bitmap = New-Object System.Drawing.Bitmap($image)
		
		# Check if the image has an alpha channel
		$hasAlpha = $bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::Alpha
		
		if (-not $hasAlpha) {
			# No alpha channel means not transparent
			$image.Dispose()
			$bitmap.Dispose()
			return $false
		}
		
		# Check each pixel for non-zero alpha
		$isFullyTransparent = $true
		for ($x = 0; $x -lt $bitmap.Width; $x++) {
			for ($y = 0; $y -lt $bitmap.Height; $y++) {
				$pixel = $bitmap.GetPixel($x, $y)
				if ($pixel.A -gt 0) {
					# Found a non-transparent pixel
					$isFullyTransparent = $false
					break
				}
			}
			if (-not $isFullyTransparent) { break }
		}
		
		# Clean up resources
		$image.Dispose()
		$bitmap.Dispose()
		
		return $isFullyTransparent
	}
	catch {
		Write-Warning "Failed to analyze transparency for: $imagePath - $_"
		return $false
	}
}

# Find all image files in .default directory
Write-Host "Searching for image files in .default directory..."
$imageExtensions = @("*.png")
$allImages = @()

foreach ($extension in $imageExtensions) {
	$images = Get-ChildItem -Path $defaultDir -Filter $extension -Recurse -File
	$allImages += $images
}

Write-Host "Found $($allImages.Count) image files to analyze" -ForegroundColor Yellow

# Check each image for full transparency
$transparentTextures = @()
$processedCount = 0

foreach ($image in $allImages) {
	$processedCount++
	Write-Progress -Activity "Analyzing transparency" -Status "Processing $($image.Name)" -PercentComplete (($processedCount / $allImages.Count) * 100)
	
	if (Test-FullyTransparent -imagePath $image.FullName) {
		# Convert absolute path to relative path from .default directory
		$relativePath = $image.FullName.Substring($defaultDir.Length + 1).Replace('\', '/')
		$transparentTextures += $relativePath
		Write-Host "  Found transparent texture: $relativePath" -ForegroundColor Green
	}
}

Write-Progress -Activity "Analyzing transparency" -Completed

Write-Host "`nFound $($transparentTextures.Count) fully transparent textures" -ForegroundColor Cyan

# Read current progress.jsonc file
if (-not (Test-Path $progressJsonPath)) {
	Write-Error "progress.jsonc file not found at: $progressJsonPath"
	exit 1
}

Write-Host "Reading progress.jsonc file..."

# Read the JSONC content (handling comments)
$jsonContent = Get-Content -Path $progressJsonPath -Raw

# Parse JSON content (PowerShell's ConvertFrom-Json handles basic JSONC)
try {
	# Remove single-line comments for safer parsing
	$cleanJson = ($jsonContent -split "`n" | ForEach-Object {
		$line = $_.Trim()
		if ($line -match '^\s*//') {
			# Skip comment lines
		} else {
			# Remove inline comments
			if ($line -match '(.+?)\s*//.*$') {
				$matches[1].TrimEnd(',') + $(if ($line.EndsWith(',')) { ',' } else { '' })
			} else {
				$line
			}
		}
	}) -join "`n"
	
	$progressData = $cleanJson | ConvertFrom-Json
}
catch {
	Write-Error "Failed to parse progress.jsonc: $_"
	exit 1
}

# Add or update the transparents field
$progressData | Add-Member -Name "transparents" -Value $transparentTextures -MemberType NoteProperty -Force

Write-Host "Updating progress.jsonc with transparent textures list..."

# Convert back to JSON with proper formatting
$updatedJson = $progressData | ConvertTo-Json -Depth 10

# Write the updated content back to the file
try {
	Set-Content -Path $progressJsonPath -Value $updatedJson -Encoding UTF8
	Write-Host "Successfully updated progress.jsonc with $($transparentTextures.Count) transparent textures" -ForegroundColor Green
}
catch {
	Write-Error "Failed to write updated progress.jsonc: $_"
	exit 1
}

# Display summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total images analyzed: $($allImages.Count)"
Write-Host "Fully transparent textures found: $($transparentTextures.Count)"
Write-Host "Progress.jsonc updated successfully"

if ($transparentTextures.Count -gt 0) {
	Write-Host "`nTransparent textures:" -ForegroundColor Yellow
	$transparentTextures | Sort-Object | ForEach-Object { Write-Host "  $_" }
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green
