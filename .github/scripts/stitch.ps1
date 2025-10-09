# Texture stitching script for Faithful-GTNH resource pack
# This script combines multiple texture files into a horizontal row without ImageMagick

param(
	[string[]]$texturePaths,
	[string]$output
)

# Ensure the output directory exists
if (!(Test-Path -Path (Split-Path -Path $output -Parent))) {
	New-Item -Path (Split-Path -Path $output -Parent) -ItemType Directory -Force | Out-Null
}

# Add System.Drawing assembly
Add-Type -AssemblyName System.Drawing

function Stitch-Textures-Horizontal {
	param(
		[string[]]$texturePaths,
		[string]$outputFile
	)
	
	Write-Host "Stitching textures horizontally to $outputFile"
	
	if ($texturePaths.Count -eq 0) {
		Write-Host "Error: No texture paths provided" -ForegroundColor Red
		return
	}
	
	try {
		# Load first image to get dimensions
		$firstImage = [System.Drawing.Image]::FromFile($texturePaths[0])
		$tileWidth = $firstImage.Width
		$tileHeight = $firstImage.Height
		
		# Create new bitmap to hold all textures
		$totalWidth = $tileWidth * $texturePaths.Count
		$resultImage = New-Object System.Drawing.Bitmap($totalWidth, $tileHeight)
		$graphics = [System.Drawing.Graphics]::FromImage($resultImage)
		
		# Copy each texture to the result image
		for ($i = 0; $i -lt $texturePaths.Count; $i++) {
			$texturePath = $texturePaths[$i]
			if (Test-Path -Path $texturePath) {
				$texture = [System.Drawing.Image]::FromFile($texturePath)
				$graphics.DrawImage($texture, ($i * $tileWidth), 0, $tileWidth, $tileHeight)
				$texture.Dispose()
			} else {
				Write-Host "Warning: Texture not found: $texturePath" -ForegroundColor Yellow
			}
		}
		
		# Save the result
		$resultImage.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)
		
		# Clean up
		$graphics.Dispose()
		$resultImage.Dispose()
		$firstImage.Dispose()
		
		if (Test-Path -Path $outputFile) {
			Write-Host "Successfully created: $outputFile" -ForegroundColor Green
		} else {
			Write-Host "Failed to create: $outputFile" -ForegroundColor Red
		}
	}
	catch {
		Write-Host "Error during texture stitching: $_" -ForegroundColor Red
	}
}

$assetsDirectory     = "$PSScriptRoot/../../assets"
$workAssetsDirectory = "$PSScriptRoot/../../.work/.assets"

$workDirName = ".work/.assets"

$fullPaths = @()
foreach ($texturePath in $texturePaths) {
	if ($texturePath.StartsWith(".work/.assets/")) {
		$fullPaths += "$workAssetsDirectory" + ($texturePath -replace $workDirName, "")
	} else {
		$fullPaths += "$assetsDirectory/$texturePath"
	}
}

Stitch-Textures-Horizontal -texturePaths $fullPaths -outputFile $output
& "$($PSScriptRoot)/display.ps1" -Path $output
