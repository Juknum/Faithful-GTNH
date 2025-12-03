<#
.SYNOPSIS
	Syncs vanilla and Et Futurum Requiem assets from the Faithful 32x resource pack repository.

.DESCRIPTION
	This script clones the Faithful-32x-Java repository to obtain vanilla Minecraft assets for version 1.7.10,
	then processes additional branches specified in a sync.jsonc configuration file to copy Et Futurum Requiem
	mod assets to their appropriate destinations. The script handles multiple branches and asset mappings,
	creating necessary directory structures and reporting any missing source files.

.PARAMETER None
	This script does not accept parameters.

.EXAMPLE
	.\sync.ps1
	Executes the asset synchronization process, cloning the Faithful repository and copying assets according to the configuration.

.NOTES
	- Requires Git to be installed and available in PATH
	- Expects a sync.jsonc configuration file at ..\configs\sync.jsonc relative to the script location
	- Uses temporary directories that are automatically cleaned up after processing
	- Reports missing source files in yellow at the end of execution

.LINK
	https://github.com/Faithful-Resource-Pack/Faithful-32x-Java

.OUTPUTS
	None. The script outputs status messages to the console and copies files to the file system.

.INPUTS
	None. This script does not accept pipeline input.
#>

Write-Host "Cloning Faithful-32x-Java repository for vanilla assets..." -ForegroundColor Green

$TEMP_DIR = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_.FullName } | Select-Object -ExpandProperty FullName
git clone --branch 1.7.10 --single-branch "https://github.com/Faithful-Resource-Pack/Faithful-32x-Java" "$TEMP_DIR"

if (Test-Path "$TEMP_DIR\assets") {
	Copy-Item -Path "$TEMP_DIR\assets" -Destination ".\" -Recurse -Force
	Write-Host "Assets directory copied."
} 
else {
	Write-Host "No assets directory found in branch."
	exit 1
}

Remove-Item -Path "$TEMP_DIR" -Recurse -Force

###
# Et Futurum Requiem Assets
###

Write-Host "Syncing assets from Et Futurum Requiem & other mods..." -ForegroundColor Green

# Get the repo root directory
$REPO_ROOT = (Get-Item -Path $PWD).FullName

# Read and parse the efr.jsonc file
$efrJsonPath = Join-Path $PSScriptRoot "..\configs\sync.jsonc"
$notFound = @()

if (Test-Path -Path $efrJsonPath) {
	$efrJson = (Get-Content -Path $efrJsonPath -Raw | ConvertFrom-Json).files  
	$branches = $efrJson.psobject.Properties.Name
	
	Write-Host "Branches to process: $branches" -ForegroundColor Green

	foreach ($branch in $branches) {
		Write-Host "Processing branch: $branch" -ForegroundColor Cyan

		$TEMP_DIR = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_.FullName } | Select-Object -ExpandProperty FullName
		git clone --branch $branch --single-branch "https://github.com/Faithful-Resource-Pack/Faithful-32x-Java" "$TEMP_DIR"

		$assetsToSync = $efrJson.$branch

		foreach ($sourceAsset in $assetsToSync.PSObject.Properties) {
			$sourcePath   = "assets\$($sourceAsset.Name)"
			$destinations = $sourceAsset.Value
			
			# Create the full source path in the cloned repo
			$fullSourcePath = Join-Path -Path $TEMP_DIR -ChildPath $sourcePath
			
			# If the source exists, copy to all destinations
			if (Test-Path -Path $fullSourcePath) {
				foreach ($destination in $destinations) {
					$destinationPath = Join-Path -Path $REPO_ROOT -ChildPath "assets\$destination"
					
					# Ensure destination directory exists
					$destinationDir = Split-Path -Path $destinationPath -Parent
					if (-not (Test-Path -Path $destinationDir)) {
						New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
					}
					
					# Copy the file
					Copy-Item -Path $fullSourcePath -Destination $destinationPath -Force
				}
			} else {
				$notFound += $sourcePath
			}

		}

		Remove-Item -Path "$TEMP_DIR" -Recurse -Force
	}
}

foreach ($file in $notFound) {
	Write-Host "Source file not found: $file" -ForegroundColor Yellow
}
