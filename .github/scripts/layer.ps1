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
		
		# Save the result
		$result.Save($outputPath)
		
		# Clean up
		$graphics.Dispose()
		$result.Dispose()
		$background.Dispose()
		$overlay.Dispose()
		
		Write-Host "Image successfully created at $outPath" -ForegroundColor Cyan
		Write-Host ""
		& "$($PSScriptRoot)/display.ps1" -Path $outputPath
	}
	catch {
		Write-Error "An error occurred: $_"
	}
}

# Execute the function with the provided parameters
Merge-Images -backgroundPath "$($PSScriptRoot)/../../$($layer0Path)" -overlayPath "$($PSScriptRoot)/../../$($layer1Path)" -outputPath "$($PSScriptRoot)/../../$($outPath)" -x $X -y $Y