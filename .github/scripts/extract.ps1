<#
.SYNOPSIS
	Extracts vanilla Minecraft and GT New Horizons mod textures to a resource pack directory.

.DESCRIPTION
	This script downloads and extracts texture assets from both vanilla Minecraft and the GT New Horizons modpack.
	It processes the Minecraft client jar and all mod jars from a GTNH installation, extracting PNG textures and 
	MCMETA metadata files to create a base resource pack structure.
	
	The script performs the following operations:
	1. Downloads the vanilla Minecraft client jar if not present
	2. Extracts all texture assets (*.png, *.mcmeta) from the Minecraft 1.7.10 jar
	3. Downloads the specified version of GT New Horizons modpack if not present
	4. Iterates through all mod jars in the modpack
	5. Extracts texture assets from each mod jar to the output directory
	
	All assets are extracted from their original "assets/*" path structure but without the "assets" prefix,
	maintaining the proper resource pack directory layout.

.PARAMETER Version
	The version of GT New Horizons to download and process. If not specified, the script attempts to 
	automatically determine the version from:
	1. GitHub Actions environment variable (GITHUB_REF_NAME)
	2. Current git branch name (if git is available), if so, the branch should be named after the version. (e.g., "2.7.0")

.EXAMPLE
	.\extract.ps1
	Extracts textures using the automatically detected version from GitHub Actions or git branch.

.EXAMPLE
	.\extract.ps1 -Version "2.7.0"
	Extracts textures from GT New Horizons version 2.7.0.

.INPUTS
	None. You cannot pipe objects to this script.

.OUTPUTS
	System.IO.FileInfo
	Extracted texture files (.png) and metadata files (.mcmeta) in the .default directory,
	organized by resource domain (mod namespace).

.NOTES
	File Name      : extract.ps1
	Prerequisite   : PowerShell 5.0+, .NET Framework 4.5+ (for System.IO.Compression)
	Dependencies   : BitsTransfer module (for download resume capability)
	
	The script uses BITS (Background Intelligent Transfer Service) for reliable downloads with 
	resume capability. Downloaded files are verified for integrity before processing.
	
	Output directory structure:
	.default/
	├── minecraft/
	│   └── textures/
	└── [mods domains]/
		└── textures/

.LINK
	https://github.com/GTNewHorizons/Faithful-GTNH
#>

param(
	[string]$Version = $(if ($env:GITHUB_REF_NAME) { 
		# Use GitHub's branch name if available
		$env:GITHUB_REF_NAME 
	} elseif (Get-Command "git" -ErrorAction SilentlyContinue) {
		# Otherwise try to get it directly from git
		git rev-parse --abbrev-ref HEAD 2>$null
	})
)

# Define URLs and paths
$MinecraftUrl = "https://launcher.mojang.com/v1/objects/e80d9b3bf5085002218d4be59e668bac718abbc6/client.jar"
$DownloadUrl  = "https://downloads.gtnewhorizons.com/Multi_mc_downloads/GT_New_Horizons_${VERSION}_Java_17-25.zip"
$ZipFile      = "$PSScriptRoot\..\..\GTNH_${VERSION}.zip"
$MinecraftJar = "$PSScriptRoot\..\..\client.jar"
$OutputPath   = "$PSScriptRoot\..\..\.default"

## Vanilla Minecraft assets

if (-Not (Test-Path $MinecraftJar)) {
	Write-Host "Downloading Minecraft client jar..."
	Invoke-WebRequest -Uri $MinecraftUrl -OutFile $MinecraftJar
} else {
	Write-Host "Minecraft client jar already exists."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
Write-Host "Opening Minecraft jar..."
$mcZip = [System.IO.Compression.ZipFile]::OpenRead($MinecraftJar)
# Filter for assets folder .png and .mcmeta files
$mcEntries = $mcZip.Entries | Where-Object {
	$_.FullName -like "assets/*" -and 
	($_.FullName.EndsWith(".png") -or $_.FullName.EndsWith(".mcmeta"))
}

Write-Host "Found $($mcEntries.Count) vanilla resource files to extract."
foreach ($mcEntry in $mcEntries) {
	# Write-Host "Extracting $($mcEntry.FullName) to $OutputPath"
	# Extract from assets/* but don't include "assets" in the destination path
	$relativePath = $mcEntry.FullName -replace "^assets/", ""
	$destPath = Join-Path $OutputPath $relativePath
	$destDir = Split-Path $destPath -Parent	
	if (-Not (Test-Path $destDir)) {
		New-Item -ItemType Directory -Path $destDir -Force | Out-Null
	}
	if (-Not $mcEntry.FullName.EndsWith('/')) {
		[System.IO.Compression.ZipFileExtensions]::ExtractToFile($mcEntry, $destPath, $true)
	}
}
$mcZip.Dispose()
Write-Host "Vanilla Minecraft assets extracted to $OutputPath"

## Mods assets from GTNH

if (-Not (Test-Path $ZipFile)) {
	Write-Host "Downloading GT New Horizons version $Version..."
	# Use BITS transfer for faster download with resume capability
	Import-Module BitsTransfer
	Start-BitsTransfer -Source $DownloadUrl -Destination $ZipFile -DisplayName "Downloading GTNH $Version" -Priority High
	
	# Verify the zip file isn't corrupted
	try {
		$testZip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
		$testZip.Dispose()
		Write-Host "Download complete and verified."
	} catch {
		Write-Host "Error: Downloaded zip file appears to be corrupted. Please try again."
		Remove-Item -Path $ZipFile -Force
		exit 1
	}
} else {
	Write-Host "File $ZipFile already exists, checking integrity..."
	try {
		$testZip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
		$testZip.Dispose()
		Write-Host "Zip file integrity verified."
	} catch {
		Write-Host "Error: Existing zip file appears to be corrupted. Redownloading..."
		Remove-Item -Path $ZipFile -Force
		# Use BITS transfer for faster download with resume capability
		Import-Module BitsTransfer
		Start-BitsTransfer -Source $DownloadUrl -Destination $ZipFile -DisplayName "Downloading GTNH $Version" -Priority High
		
		# Verify the new download
		try {
			$testZip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
			$testZip.Dispose()
			Write-Host "Download complete and verified."
		} catch {
			Write-Host "Error: Downloaded zip file appears to be corrupted. Please check your connection."
			Remove-Item -Path $ZipFile -Force
			exit 1
		}
	}
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host "Opening main archive..."
$gtZip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)

# Filter for mods folder .jar files
$jarEntries = $gtZip.Entries | Where-Object { $_.FullName -like "*.minecraft/mods/*.jar" }
$totalExtracted = 0;

foreach ($jarEntry in $jarEntries) {
	Write-Host "Processing $($jarEntry.FullName)..."
	
	$tempPath = Join-Path $env:TEMP "tempJar"
	if (Test-Path $tempPath) {
		Remove-Item -Path $tempPath -Recurse -Force
	}
	New-Item -ItemType Directory -Path $tempPath | Out-Null
	
	$tempJarPath = Join-Path $tempPath (Split-Path $jarEntry.FullName -Leaf)
	[System.IO.Compression.ZipFileExtensions]::ExtractToFile($jarEntry, $tempJarPath, $true)
	
	$jarZip = [System.IO.Compression.ZipFile]::OpenRead($tempJarPath)
	$resourceEntries = $jarZip.Entries | Where-Object { 
		$_.FullName -like "assets/*" -and 
		($_.FullName.EndsWith(".png") -or $_.FullName.EndsWith(".mcmeta"))
	}

	Write-Host "  Found $($resourceEntries.Count) resource files to extract."
	$totalExtracted += $resourceEntries.Count
	
	foreach ($resourceEntry in $resourceEntries) {
		# Write-Host "  Extracting $($resourceEntry.FullName) to $OutputPath"

		# Extract from assets/* but don't include "assets" in the destination path
		$relativePath = $resourceEntry.FullName -replace "^assets/", ""
		$destPath = Join-Path $OutputPath $relativePath
		$destDir = Split-Path $destPath -Parent
		
		if (-Not (Test-Path $destDir)) {
			New-Item -ItemType Directory -Path $destDir -Force | Out-Null
		}
		
		if (-Not $resourceEntry.FullName.EndsWith('/')) {
			[System.IO.Compression.ZipFileExtensions]::ExtractToFile($resourceEntry, $destPath, $true)
		}
	}
	
	$jarZip.Dispose()
}

$gtZip.Dispose()
Write-Host "Done! All $totalExtracted textures extracted to $OutputPath"
