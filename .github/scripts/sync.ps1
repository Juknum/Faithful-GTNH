##############################################################
# Faithful-32x-Java and Et Futurum Requiem Asset Sync Script
# This script clones the Faithful-32x-Java repository and copies
# specified assets into the current repository based on the efr.jsonc
# configuration file.
##############################################################

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

Write-Host "Syncing assets from Et Futurum Requiem..." -ForegroundColor Green

# Get the repo root directory
$REPO_ROOT = (Get-Item -Path $PWD).FullName

# Read and parse the efr.jsonc file
$efrJsonPath = Join-Path $PSScriptRoot "..\configs\sync.jsonc"
$notFound = @()

if (Test-Path -Path $efrJsonPath) {
	$efrJson = (Get-Content -Path $efrJsonPath -Raw | ConvertFrom-Json).et_futurum_requiem  
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
