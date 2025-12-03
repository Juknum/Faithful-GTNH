<#
.SYNOPSIS
	Merges two images by overlaying one image on top of another at a specified position.

.DESCRIPTION
	This script takes two image files (a background and an overlay) and combines them into a single output image.
	The overlay image is placed on top of the background image at the specified X and Y coordinates.
	The script handles cases where the output path matches one of the input paths by using a temporary file.
	After merging, it displays the resulting image using a separate display script.
	All file paths are treated as relative to the script's parent directory (../../).

.PARAMETER layer0Path
	The relative path to the background (base layer) image file.

.PARAMETER layer1Path
	The relative path to the overlay (top layer) image file.

.PARAMETER outPath
	The relative path where the merged output image will be saved.

.PARAMETER X
	The horizontal (X) coordinate where the overlay image will be positioned on the background.
	Default value is 0.

.PARAMETER Y
	The vertical (Y) coordinate where the overlay image will be positioned on the background.
	Default value is 0.

.EXAMPLE
	.\layer.ps1 -layer0Path "textures/base.png" -layer1Path "textures/overlay.png" -outPath "textures/result.png"
	
	Merges base.png and overlay.png, placing the overlay at position (0,0), and saves to result.png.

.EXAMPLE
	.\layer.ps1 -layer0Path "textures/base.png" -layer1Path "textures/overlay.png" -outPath "textures/result.png" -X 10 -Y 20
	
	Merges the images with the overlay positioned at coordinates (10,20) on the background.

.INPUTS
	None. This script does not accept pipeline input.

.OUTPUTS
	System.IO.FileInfo
	The script creates an image file at the specified output path.

.NOTES
	Requires System.Drawing assembly and the display.ps1 script in the same scripts directory.
	All paths are relative to the script's parent directory (../../).
	The script automatically handles temporary file creation when the output path matches an input path.
#>

param (
	[Parameter(Mandatory=$true)]
	[string]$layer0Path,
	
	[Parameter(Mandatory=$true)]
	[string]$layer1Path,
	
	[Parameter(Mandatory=$true)]
	[string]$outPath,
	
	[Parameter(Mandatory=$false)]
	[int]$X = 0,
	
	[Parameter(Mandatory=$false)]
	[int]$Y = 0
)

Add-Type -AssemblyName System.Drawing

function Merge-Images {
	param (
		[string]$backgroundPath,
		[string]$overlayPath,
		[string]$outputPath,
		[int]$x,
		[int]$y
	)
	
	Write-Host $backgroundPath -ForegroundColor Yellow
	Write-Host $overlayPath -ForegroundColor Yellow

	try {
		# Define a temp path if output is same as any input
		$tempOutputPath = $outputPath
		$needsTemp = ($outputPath -eq $backgroundPath) -or ($outputPath -eq $overlayPath)
		
		if ($needsTemp) {
			$tempOutputPath = [System.IO.Path]::GetTempFileName() + ".png"
		}
		
		# Load the background image
		$background = [System.Drawing.Image]::FromFile($backgroundPath)
		
		# Load the overlay image
		$overlay = [System.Drawing.Image]::FromFile($overlayPath)
		
		# Create a bitmap with the same size as the background
		$result = New-Object System.Drawing.Bitmap $background.Width, $background.Height
		
		# Create a graphics object from the bitmap
		$graphics = [System.Drawing.Graphics]::FromImage($result)
		
		# Set the graphics quality
		$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
		$graphics.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
		$graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
		
		# Draw the background image
		$graphics.DrawImage($background, 0, 0, $background.Width, $background.Height)
		
		# Draw the overlay image at the specified position
		$graphics.DrawImage($overlay, $x, $y, $overlay.Width, $overlay.Height)
		
		# Clean up resources before saving to avoid locks
		$graphics.Dispose()
		$background.Dispose()
		$overlay.Dispose()
		
		# Save the result
		$result.Save($tempOutputPath)
		$result.Dispose()
		
		# If we used a temp file, now copy it to the final destination
		if ($needsTemp) {
			Remove-Item -Path $outputPath -Force -ErrorAction SilentlyContinue
			Move-Item -Path $tempOutputPath -Destination $outputPath -Force
		}
		
		Write-Host "Image successfully created at $outputPath" -ForegroundColor Cyan
		Write-Host ""
		& "$($PSScriptRoot)/display.ps1" -Path $outputPath
	}
	catch {
		Write-Error "An error occurred: $_"
	}
}

# Execute the function with the provided parameters
Merge-Images -backgroundPath "$($PSScriptRoot)/../../$($layer0Path)" -overlayPath "$($PSScriptRoot)/../../$($layer1Path)" -outputPath "$($PSScriptRoot)/../../$($outPath)" -x $X -y $Y