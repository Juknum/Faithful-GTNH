# Script to detect fully transparent textures in .default directory and update progress.jsonc

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
