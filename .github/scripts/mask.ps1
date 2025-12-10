<#
.SYNOPSIS
	Applies pixel masks to textures based on JSON configuration files.

.DESCRIPTION
	This script processes texture images by applying masks that remove specific pixels.
	It reads configuration files (JSONC format) that specify origin textures, mask images,
	and output paths. For each pixel where the mask has transparency (alpha > 0), the
	corresponding pixel in the origin texture is removed (made transparent).
	
	The script can process either a single configuration file or batch process all
	configuration files found in the masks directory.

.PARAMETER file
	Optional. Path to a specific JSONC configuration file relative to the masks config
	directory (.github/configs/masks). If not provided, all JSONC files in the masks
	directory will be processed recursively.

.EXAMPLE
	.\mask.ps1
	Processes all .jsonc configuration files found in the masks directory recursively.

.EXAMPLE
	.\mask.ps1 -file "myconfig.jsonc"
	Processes only the specified configuration file from the masks config directory.

.EXAMPLE
	.\mask.ps1 -file "subfolder/texture_mask.jsonc"
	Processes a configuration file located in a subdirectory of the masks config directory.

.NOTES
	Configuration File Format:
	{
		"origin": "path/to/source/texture.png",
		"mask": "path/to/mask/texture.png",
		"output": "path/to/output/texture.png"
	}
	
	Requirements:
	- System.Drawing assembly (loaded automatically)
	- Origin and mask textures must have matching dimensions
	- Mask texture uses alpha channel to determine pixels to remove

.OUTPUTS
	System.Boolean
	Returns true if mask application succeeds, false otherwise (when processing single file).
	Exit codes: 0 for success, 1 for failure.

.INPUTS
	System.String
	Accepts a file path string parameter for single file processing.
#>

param(
	[Parameter(Mandatory = $false)]
	[string]$file = $null
)

# Script to apply pixel masks to textures based on JSON configuration files

# Load System.Drawing assembly for image processing
Add-Type -AssemblyName System.Drawing

# Get the script directory and set paths
$scriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot       = Split-Path -Parent (Split-Path -Parent $scriptDir)
$masksConfigDir = Join-Path -Path $scriptDir -ChildPath "..\configs\masks"

Write-Host "Texture Masking Script" -ForegroundColor Cyan

# Function to apply mask to texture
function Set-TextureMask {
	param(
		[string]$originPath,
		[string]$maskPath,
		[string]$outputPath
	)

	try {
		# Resolve full paths
		$fullOriginPath = Join-Path -Path $repoRoot -ChildPath $originPath
		$fullMaskPath   = Join-Path -Path $repoRoot -ChildPath $maskPath
		$fullOutputPath = Join-Path -Path $repoRoot -ChildPath $outputPath
		
		# Check if origin and mask files exist
		if (-not (Test-Path $fullOriginPath)) {
			Write-Error "Origin texture not found: $($fullOriginPath)"
			return $false
		}
		
		if (-not (Test-Path $fullMaskPath)) {
			Write-Error "Mask texture not found: $($fullMaskPath)"
			return $false
		}
		
		# Create output directory if it doesn't exist
		$outputDir = Split-Path -Parent $fullOutputPath
		if (-not (Test-Path $outputDir)) {
			New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
		}
		
		Write-Host "  Processing: $($originPath)" -ForegroundColor Yellow
		Write-Host "  Using mask: $($maskPath)" -ForegroundColor Yellow
		Write-Host "  Output to: $($outputPath)" -ForegroundColor Yellow
		
		# Load images
		$originImage = [System.Drawing.Image]::FromFile($fullOriginPath)
		$originBitmap = New-Object System.Drawing.Bitmap($originImage)
		
		$maskImage = [System.Drawing.Image]::FromFile($fullMaskPath)
		$maskBitmap = New-Object System.Drawing.Bitmap($maskImage)
		
		# Check if dimensions match
		if ($originBitmap.Width -ne $maskBitmap.Width -or $originBitmap.Height -ne $maskBitmap.Height) {
			Write-Warning "  Dimension mismatch: Origin ($($originBitmap.Width)x$($originBitmap.Height)) vs Mask ($($maskBitmap.Width)x$($maskBitmap.Height))"
			return $false
		}
		
		# Create output bitmap
		$outputBitmap = New-Object System.Drawing.Bitmap($originBitmap.Width, $originBitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
		
		# Process each pixel
		$pixelsRemoved = 0
		for ($x = 0; $x -lt $originBitmap.Width; $x++) {
			for ($y = 0; $y -lt $originBitmap.Height; $y++) {
				$originPixel = $originBitmap.GetPixel($x, $y)
				$maskPixel = $maskBitmap.GetPixel($x, $y)
				
				# Check if mask pixel is non-transparent (pixel to remove)
				# If mask pixel has alpha > 0, remove the pixel from origin (make it transparent)
				if ($maskPixel.A -gt 0) {
					# Remove pixel by making it fully transparent
					$outputBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
					$pixelsRemoved++
				} else {
					# Keep original pixel
					$outputBitmap.SetPixel($x, $y, $originPixel)
				}
			}
		}
		
		# Save the output image
		$outputBitmap.Save($fullOutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
		
		Write-Host "  ✓ Success: Removed $($pixelsRemoved) pixels" -ForegroundColor Green
		
		# Clean up resources
		$originImage.Dispose()
		$originBitmap.Dispose()
		$maskImage.Dispose()
		$maskBitmap.Dispose()
		$outputBitmap.Dispose()
		
		return $true
	} catch {
		Write-Error "  ✗ Failed to apply mask: $($_)"
		return $false
	}

}

# Function to process a single config file
function Start-ConfigFileProcessing {
	param([string]$configPath)

	try {
		Write-Host "`nProcessing config: $($configPath | Split-Path -Leaf)" -ForegroundColor Cyan
		
		$config = (Get-Content -Path $configPath -Raw) | ConvertFrom-Json
		
		# Validate required fields
		if (-not $config.origin) {
			Write-Error "  Missing 'origin' field in config"
			return $false
		}
		
		if (-not $config.mask) {
			Write-Error "  Missing 'mask' field in config"
			return $false
		}
		
		if (-not $config.output) {
			Write-Error "  Missing 'output' field in config"
			return $false
		}
		
		# Apply the mask
		return Set-TextureMask -originPath $config.origin -maskPath $config.mask -outputPath $config.output
	} catch {
		Write-Error "  Failed to process config file: $($_)"
		return $false
	}
}

# Main execution
if ($file) {
	# Process single config file
	# Make sure the file path is relative to the masks config directory
	if (-not [System.IO.Path]::IsPathRooted($file)) {
		$configPath = Join-Path -Path $masksConfigDir -ChildPath $file
	} else {
		Write-Error "Please provide a file path relative to the masks config directory"
		exit 1
	}

	if (-not (Test-Path $configPath -Type Leaf)) {
		Write-Error "Config file not found: $($configPath)"
		exit 1
	}

	Write-Host "Processing single config file: $($configPath)"
	$success = Start-ConfigFileProcessing -configPath $configPath

	if ($success) {
		Write-Host "`nMask applied successfully!" -ForegroundColor Green
	} else {
		Write-Host "`nFailed to apply mask!" -ForegroundColor Red
		exit 1
	}
} else {
	# Process all config files in masks directory
	if (-not (Test-Path $masksConfigDir)) {
		Write-Error "Masks config directory not found: $masksConfigDir"
		exit 1
	}

	Write-Host "Scanning for mask configuration files in: $masksConfigDir"

	# Find all .jsonc files recursively
	$Files = Get-ChildItem -Path $masksConfigDir -Filter "*.jsonc" -Recurse -File

	if ($Files.Count -eq 0) {
		Write-Warning "No .jsonc configuration files found in masks directory"
		exit 0
	}

	Write-Host "Found $($Files.Count) configuration files" -ForegroundColor Yellow

	# Process each config file
	$successCount = 0
	$failCount = 0

	foreach ($file in $Files) {
		$success = Start-ConfigFileProcessing -configPath $file.FullName
		if ($success) {
			$successCount++
		} else {
			$failCount++
		}
	}

	# Summary
	Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
	Write-Host "Total configurations: $($Files.Count)"
	Write-Host "Successful: $successCount" -ForegroundColor Green
	Write-Host "Failed: $failCount" -ForegroundColor Red

	if ($failCount -eq 0) {
		Write-Host "`nAll masks applied successfully!" -ForegroundColor Green
	} else {
		Write-Host "`nSome masks failed to apply. Check the errors above." -ForegroundColor Yellow
		exit 1
	}
}

Write-Host "Masking process completed!" -ForegroundColor Green
