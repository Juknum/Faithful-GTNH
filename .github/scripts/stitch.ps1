<#
.SYNOPSIS
	Stitches multiple texture images horizontally into a single PNG file.

.DESCRIPTION
	This script takes an array of texture file paths and combines them horizontally into a single output image.
	It supports both regular asset paths and work directory asset paths, automatically resolving the full paths.
	After stitching, it displays the resulting image using a separate display script.

.PARAMETER texturePaths
	An array of texture file paths to be stitched together. Paths can be relative to the assets directory
	or can start with ".work/.assets/" for work directory assets.

.PARAMETER output
	The full path where the stitched output image should be saved. The output format is PNG.

.EXAMPLE
	.\stitch.ps1 -texturePaths @("texture1.png", "texture2.png", "texture3.png") -output "output/stitched.png"
	Stitches three textures horizontally and saves the result to output/stitched.png

.EXAMPLE
	.\stitch.ps1 -texturePaths @(".work/.assets/temp1.png", "texture2.png") -output "result.png"
	Stitches a work directory texture with a regular asset texture

.NOTES
	- Requires System.Drawing assembly
	- All input textures should have the same height for best results
	- The output directory is created automatically if it doesn't exist
	- Images are disposed properly to free up resources
	- Displays the result using display.ps1 script after completion

.OUTPUTS
	System.Void
	Creates a PNG file at the specified output path.

.INPUTS
	System.String[]
	Accepts an array of texture file paths.
#>

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

function Join-TexturesHorizontal {
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

Join-TexturesHorizontal -texturePaths $fullPaths -outputFile $output
& "$($PSScriptRoot)/display.ps1" -Path $output
