<#
.SYNOPSIS
	Compares texture assets between .default and assets directories and reports their completion status.

.DESCRIPTION
	This script analyzes texture files in a Minecraft resource pack by comparing PNG files in the .default directory 
	with their corresponding files in the assets directory. It categorizes textures as Done, Missing, Blacklisted, 
	Transparent, or Extra based on their presence and configuration in progress.jsonc. The script also verifies 
	if textures are actually fully transparent by analyzing pixel data.

.PARAMETER AssetFolder
	The name of the asset folder to analyze (e.g., "minecraft", "gregtech"). This folder must exist under both 
	.default and assets directories in the repository root.

.PARAMETER Hide
	Optional array of categories to hide from the output. Valid options are: "done", "missing", "blacklisted", 
	"transparents", "extra". Use this to focus on specific texture categories.

.EXAMPLE
	.\status.ps1 -AssetFolder "minecraft"
	Analyzes all textures in the minecraft asset folder and displays a complete report.

.EXAMPLE
	.\status.ps1 -AssetFolder "gregtech" -Hide "done","transparents"
	Analyzes gregtech textures but hides completed and transparent textures from the output.

.EXAMPLE
	.\status.ps1 -AssetFolder "minecraft" -Hide "done","blacklisted","transparents","extra"
	Shows only missing textures for the minecraft asset folder.

.NOTES
	- Requires System.Drawing assembly for image transparency analysis
	- Reads blacklist and transparent texture lists from .github/configs/progress.jsonc
	- Calculates completion percentage excluding blacklisted and transparent textures
	- Warns about textures marked as transparent that aren't actually transparent
	- Reports textures present in assets but not in .default as "Extra"

.OUTPUTS
	Console output with color-coded texture status report and summary statistics.

.INPUTS
	None. This script does not accept pipeline input.
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$AssetFolder,
	
	[Parameter(Mandatory=$false)]
	[string[]]$Hide = @()
)

# Script to compare assets and .default folders and report texture status
# Also reports files present in assets but not in .default ("Extra" textures)

# Load System.Drawing assembly for image processing
Add-Type -AssemblyName System.Drawing

# Get the script directory and set paths
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot   = Split-Path -Parent (Split-Path -Parent $scriptDir)
$assetsDir  = Join-Path -Path $repoRoot -ChildPath "assets\$AssetFolder"
$defaultDir = Join-Path -Path $repoRoot -ChildPath ".default\$AssetFolder"

$progressJsonPath = Join-Path -Path $scriptDir -ChildPath "..\configs\progress.jsonc"

# Validate input parameters
$validHideOptions = @("done", "missing", "blacklisted", "transparents", "extra")
foreach ($option in $Hide) {
	if ($option -notin $validHideOptions) {
		Write-Error "Invalid hide option: '$option'. Valid options are: $($validHideOptions -join ', ')"
		exit 1
	}
}

# Check if directories exist
if (-not (Test-Path $defaultDir)) {
	Write-Error "Default directory not found: $defaultDir"
	exit 1
}

if (-not (Test-Path $assetsDir)) {
	Write-Warning "Assets directory not found: $assetsDir (Assuming no textures are present)"
	# Still continue to allow reporting of zero assets and avoid errors
}

# Check if progress.jsonc exists
if (-not (Test-Path $progressJsonPath)) {
	Write-Error "progress.jsonc file not found at: $progressJsonPath"
	exit 1
}

Write-Host "Analyzing texture status for asset folder: $AssetFolder" -ForegroundColor Cyan

# Read progress.jsonc file
Write-Host "Reading configuration from progress.jsonc..."
try {
	$progressData = (Get-Content -Path $progressJsonPath -Raw) | ConvertFrom-Json
}
catch {
	Write-Error "Failed to parse progress.jsonc: $_"
	exit 1
}

# Extract blacklisted and transparent textures for this asset folder
$blacklistedTextures = @()
$transparentTextures = @()

if ($progressData.blacklist) {
	$blacklistedTextures = $progressData.blacklist | Where-Object { $_ -like "$AssetFolder/*" }
}

if ($progressData.transparents) {
	$transparentTextures = $progressData.transparents | Where-Object { $_ -like "$AssetFolder/*" }
}

Write-Host "Found $($blacklistedTextures.Count) blacklisted textures for $AssetFolder"
Write-Host "Found $($transparentTextures.Count) transparent textures for $AssetFolder"

# Function to check if an image is fully transparent
function Test-FullyTransparent {
	param([string]$imagePath)
	
	try {
		$image = [System.Drawing.Image]::FromFile($imagePath)
		$bitmap = New-Object System.Drawing.Bitmap($image)
		
		# Check if the image has an alpha channel
		$hasAlpha = $bitmap.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::Alpha
		
		if (-not $hasAlpha) {
			$image.Dispose()
			$bitmap.Dispose()
			return $false
		}
		
		# Check each pixel for non-zero alpha
		$isFullyTransparent = $true
		for ($x = 0; $x -lt $bitmap.Width -and $isFullyTransparent; $x++) {
			for ($y = 0; $y -lt $bitmap.Height -and $isFullyTransparent; $y++) {
				$pixel = $bitmap.GetPixel($x, $y)
				if ($pixel.A -gt 0) {
					$isFullyTransparent = $false
				}
			}
		}
		
		$image.Dispose()
		$bitmap.Dispose()
		return $isFullyTransparent
	}
	catch {
		return $false
	}
}

# Get all texture files from .default directory
Write-Host "Scanning for textures in .default directory..."

$defaultTextures = Get-ChildItem -Path $defaultDir -Filter "*.png" -Recurse -File

Write-Host "Found $($defaultTextures.Count) textures in .default directory"

# Prepare results
$results = @{
	Done = @()
	Missing = @()
	Blacklisted = @()
	Transparents = @()
	Extra = @()
}

$processedCount = 0
foreach ($defaultTexture in $defaultTextures) {
	$processedCount++
	Write-Progress -Activity "Analyzing textures" -Status "Processing $($defaultTexture.Name)" -PercentComplete (($processedCount / $defaultTextures.Count) * 100)
	
	# Get relative path from .default directory
	$relativePath = $defaultTexture.FullName.Substring($defaultDir.Length + 1).Replace('\', '/')
	$fullRelativePath = "$AssetFolder/$relativePath"
	
	# Check corresponding assets file
	$assetsTexturePath = Join-Path -Path $assetsDir -ChildPath $relativePath
	
	# Determine status
	$status = @{
		Path = $relativePath
		FullPath = $fullRelativePath
		IsBlacklisted = $fullRelativePath -in $blacklistedTextures
		IsTransparent = $fullRelativePath -in $transparentTextures
		ExistsInAssets = Test-Path $assetsTexturePath
		ActuallyTransparent = $false
	}
	
	# Check if it's actually transparent (for verification)
	if (Test-Path $assetsTexturePath) {
		$status.ActuallyTransparent = Test-FullyTransparent -imagePath $assetsTexturePath
	}
	
	# Categorize the texture
	if ($status.IsBlacklisted) {
		$results.Blacklisted += $status
	} elseif ($status.IsTransparent) {
		$results.Transparents += $status
	} elseif ($status.ExistsInAssets) {
		$results.Done += $status
	} else {
		$results.Missing += $status
	}
}

Write-Progress -Activity "Analyzing textures" -Completed

# Now scan assets for files not present in .default (Extras)
if (Test-Path $assetsDir) {
	Write-Host "Scanning for textures in assets directory..."
	$assetsTextures = Get-ChildItem -Path $assetsDir -Filter "*.png" -Recurse -File
	Write-Host "Found $($assetsTextures.Count) textures in assets directory"

	# Build a HashSet of default relative paths for quick lookup
	$defaultRelativePaths = $defaultTextures | ForEach-Object {
		$_.FullName.Substring($defaultDir.Length + 1).Replace('\', '/')
	}
	# Create a HashSet and populate it to ensure compatibility across PowerShell versions
	$defaultSet = New-Object 'System.Collections.Generic.HashSet[string]'
	if ($defaultRelativePaths) {
		foreach ($p in $defaultRelativePaths) {
			# Add returns true/false; cast to void to suppress output
			[void]$defaultSet.Add($p)
		}
	}

	foreach ($assetTexture in $assetsTextures) {
		$relativePath = $assetTexture.FullName.Substring($assetsDir.Length + 1).Replace('\', '/')
		if (-not $defaultSet.Contains($relativePath)) {
			$fullRelativePath = "$AssetFolder/$relativePath"
			$status = @{
				Path = $relativePath
				FullPath = $fullRelativePath
				IsBlacklisted = $fullRelativePath -in $blacklistedTextures
				IsTransparent = $fullRelativePath -in $transparentTextures
				ExistsInAssets = $true
				ActuallyTransparent = Test-FullyTransparent -imagePath $assetTexture.FullName
			}
			$results.Extra += $status
		}
	}
}

# Display results
Write-Host "`n=== TEXTURE STATUS REPORT for $AssetFolder ===" -ForegroundColor Cyan

if ("done" -notin $Hide) {
	Write-Host "`nDONE TEXTURES ($($results.Done.Count)):" -ForegroundColor Green
	$results.Done | Sort-Object Path | ForEach-Object {
		$marker = if ($_.ActuallyTransparent) { " [ACTUALLY TRANSPARENT]" } else { "" }
		Write-Host "  ✓ $($_.Path)$marker" -ForegroundColor Green
	}
}

if ("missing" -notin $Hide) {
	Write-Host "`nMISSING TEXTURES ($($results.Missing.Count)):" -ForegroundColor Red
	$results.Missing | Sort-Object Path | ForEach-Object {
		Write-Host "  ✗ $($_.Path)" -ForegroundColor Red
	}
}

if ("blacklisted" -notin $Hide) {
	Write-Host "`nBLACKLISTED TEXTURES ($($results.Blacklisted.Count)):" -ForegroundColor Yellow
	$results.Blacklisted | Sort-Object Path | ForEach-Object {
		$existsMarker = if ($_.ExistsInAssets) { " [EXISTS IN ASSETS]" } else { "" }
		Write-Host "  ! $($_.Path)$existsMarker" -ForegroundColor Yellow
	}
}

if ("transparents" -notin $Hide) {
	Write-Host "`nTRANSPARENT TEXTURES ($($results.Transparents.Count)):" -ForegroundColor Magenta
	$results.Transparents | Sort-Object Path | ForEach-Object {
		$existsMarker = if ($_.ExistsInAssets) { " [EXISTS IN ASSETS]" } else { "" }
		$actualMarker = if ($_.ExistsInAssets -and -not $_.ActuallyTransparent) { " [NOT ACTUALLY TRANSPARENT]" } else { "" }
		Write-Host "  ◯ $($_.Path)$existsMarker$actualMarker" -ForegroundColor Magenta
	}
}

if ("extra" -notin $Hide) {
	Write-Host "`nEXTRA (present in assets but not in .default) ($($results.Extra.Count)):" -ForegroundColor Cyan
	$results.Extra | Sort-Object Path | ForEach-Object {
		$blackMarker = if ($_.IsBlacklisted) { " [BLACKLISTED]" } else { "" }
		$transMarker = if ($_.IsTransparent) { " [MARKED TRANSPARENT]" } else { "" }
		$actualMarker = if ($_.ActuallyTransparent) { " [ACTUALLY TRANSPARENT]" } else { "" }
		Write-Host "  ▶ $($_.Path)$blackMarker$transMarker$actualMarker" -ForegroundColor Cyan
	}
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Asset Folder: $AssetFolder"
Write-Host "Total textures in .default: $($defaultTextures.Count)"
Write-Host "Total textures in assets  : $(if (Test-Path $assetsDir) { (Get-ChildItem -Path $assetsDir -Filter '*.png' -Recurse -File).Count } else { 0 })"
Write-Host " ✓ Done        : $($results.Done.Count) $(if ("done" -in $Hide) { "(hidden)" })" -ForegroundColor Green
Write-Host " ✗ Missing     : $($results.Missing.Count) $(if ("missing" -in $Hide) { "(hidden)" })" -ForegroundColor Red
Write-Host " ! Blacklisted : $($results.Blacklisted.Count) $(if ("blacklisted" -in $Hide) { "(hidden)" })" -ForegroundColor Yellow
Write-Host " ◯ Transparent : $($results.Transparents.Count) $(if ("transparents" -in $Hide) { "(hidden)" })" -ForegroundColor Magenta
Write-Host " ▶ Extra       : $($results.Extra.Count) $(if ("extra" -in $Hide) { "(hidden)" })" -ForegroundColor Cyan

$completionPercentage = if ($defaultTextures.Count -gt 0) { 
	[math]::Round(($results.Done.Count / ($defaultTextures.Count - $results.Blacklisted.Count - $results.Transparents.Count)) * 100, 2) 
} else { 
	0 
}

Write-Host "Completion: $completionPercentage% (excluding blacklisted and transparent textures)" -ForegroundColor Cyan

# Warnings and recommendations
if ($results.Done | Where-Object { $_.ActuallyTransparent }) {
	Write-Host "`n⚠ WARNING: Some completed textures are actually fully transparent and might need to be added to the transparents list" -ForegroundColor Yellow
}

if ($results.Transparents | Where-Object { $_.ExistsInAssets -and -not $_.ActuallyTransparent }) {
	Write-Host "`n⚠ WARNING: Some textures marked as transparent are not actually transparent" -ForegroundColor Yellow
}

if ($results.Extra.Count -gt 0) {
	Write-Host "`n⚠ NOTE: There are textures present in assets that don't exist in .default. Review 'Extra' list to determine if they are intentional or should be removed/added to .default." -ForegroundColor Yellow
}

Write-Host "`nAnalysis completed!" -ForegroundColor Green
