##############################################################
# PowerShell script to recolor textures to from a source to multiple targets.
#
# Usage:
#   recolor.ps1 -src "minecraft/textures/block/planks_oak.png" -out "forestry/textures/blocks/wood/planks.acacia.png","forestry/textures/blocks/wood/planks.balsa.png"
#
##############################################################

param (
	[string]   $src,       # eg: "minecraft/textures/block/planks_oak.png"
	[string[]] $out = @(), # eg: "forestry/textures/blocks/wood/planks.acacia.png", "forestry/textures/blocks/wood/planks.balsa.png"
	[switch]   $commandLine  = $false,
	[switch]   $forceRecolor = $false
)

if (-not $commandLine) {
	Write-Host "Starting recoloring process..." -ForegroundColor Green
}

$out = $out | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -Unique | Sort-Object

Write-Host "Source  : $src" -ForegroundColor Cyan
Write-Host "Targets :" -ForegroundColor Cyan
foreach ($target in $out) {
	Write-Host "  - $target" -ForegroundColor Cyan
}
Write-Host ""

$palettesDirectory = "$PSScriptRoot/../configs/palettes"
$assetsDirectory   = "$PSScriptRoot/../../assets"
$defaultDirectory  = "$PSScriptRoot/../../.default"

function Get-Palette(
	[string] $asset,
	[switch] $isDefault = $false
) {
	$paletteFilename = "$palettesDirectory/$($asset -replace '\.png$', '.jsonc')"
	$textureFilename = if ($isDefault) { "$defaultDirectory/$asset" } else { "$assetsDirectory/$asset" }

	if (Test-Path $paletteFilename) {
		return $paletteFilename
	}

	Write-Warning "Palette for asset '$asset' not found, generating one..."

	if (-not (Test-Path $textureFilename -PathType Leaf)) {
		Write-Error "Error: Texture file not found at path '$textureFilename'"
		return $null
	}

	$BitMap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $textureFilename).ProviderPath)

	# A hashtable to keep track of the colors we've encountered
	$table = @{}
	foreach ($h in 1..$BitMap.Height) {
		foreach ($w in 1..$BitMap.Width) {
			$color = $BitMap.GetPixel($w - 1, $h - 1)
			# Only add the color to the palette if it's not fully transparent
			if ($color.A -ne 0) {
				$hexColor = "#{0:X2}{1:X2}{2:X2}{3:X2}" -f $color.R, $color.G, $color.B, $color.A
				$table[$hexColor] = $true
			}
		}
	}

	$BitMap.Dispose()

	# The hashtable keys is out palette
	# Convert colors to objects with RGB values and luminance for sorting
	$colorObjects = $table.Keys | ForEach-Object {
		if ($_ -match '^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$') {
			$r = [Convert]::ToInt32($matches[1], 16)
			$g = [Convert]::ToInt32($matches[2], 16)
			$b = [Convert]::ToInt32($matches[3], 16)
			# Calculate luminance using the standard formula (0.299R + 0.587G + 0.114B)
			$luminance = 0.299 * $r + 0.587 * $g + 0.114 * $b
			
			[PSCustomObject]@{
				Color = $_
				Luminance = $luminance
			}
		}
	}
	
	# Sort by luminance (darkest to brightest)
	$palette = $colorObjects | Sort-Object Luminance | Select-Object -ExpandProperty Color
	# Write-Host $palette
	
	# Ensure the palette directory exists
	if (!(Test-Path -Path (Split-Path -Path $paletteFilename -Parent))) {
		New-Item -Path (Split-Path -Path $paletteFilename -Parent) -ItemType Directory -Force | Out-Null
	}
	
	# Save the palette to a JSON file
	$palette | ConvertTo-Json | Out-File -Encoding utf8 $paletteFilename

	return $paletteFilename
}

function Recolor-Texture(
	[string]   $sourceImage,
	[string[]] $targetPalettes = @(),
	[string[]] $targetPaths = @()
) {
	# Take the source image and replace its colors with the target palette
	# Save the new image to the target path
	
	if ($targetPalettes.Length -ne $targetPaths.Length) {
		Write-Error "Error: Number of target palettes and target paths must match."
		return
	}
	
	# Load source image
	$sourcePath = "$assetsDirectory/$sourceImage"
	if (-not (Test-Path $sourcePath -PathType Leaf)) {
		Write-Error "Error: Source image not found at path '$sourcePath'"
		return
	}
	
	$sourceBitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $sourcePath).ProviderPath)
	
	# Get source palette
	$sourcePalettePath = Get-Palette $sourceImage
	$sourcePalette = Get-Content $sourcePalettePath -Raw | ConvertFrom-Json
	
	# Process each target
	for ($i = 0; $i -lt $targetPalettes.Length; $i++) {
		$targetPalettePath = $targetPalettes[$i]
		$targetOutputPath = "$assetsDirectory/$($targetPaths[$i])"
		
		# Ensure directory exists for output file
		$targetDir = Split-Path -Path $targetOutputPath -Parent
		if (!(Test-Path -Path $targetDir)) {
			New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
		}
		
		# Load target palette
		$targetPalette = Get-Content $targetPalettePath -Raw | ConvertFrom-Json
		
		# Create color mapping (source to target)
		$colorMap = @{}
		if ($sourcePalette.Count -eq $targetPalette.Count) {
			# Map colors in order
			for ($j = 0; $j -lt $sourcePalette.Count; $j++) {
				$colorMap[$sourcePalette[$j]] = $targetPalette[$j]
			}
		}
		else {
			Write-Warning "Palette sizes don't match for $($targetPaths[$i]). Skipping this target."
			continue
		}
		
		# Create new bitmap with same dimensions
		$newBitmap = New-Object System.Drawing.Bitmap $sourceBitmap.Width, $sourceBitmap.Height
		
		# Process each pixel
		for ($x = 0; $x -lt $sourceBitmap.Width; $x++) {
			for ($y = 0; $y -lt $sourceBitmap.Height; $y++) {
				$sourceColor = $sourceBitmap.GetPixel($x, $y)
				
				# Skip fully transparent pixels
				if ($sourceColor.A -eq 0) {
					$newBitmap.SetPixel($x, $y, $sourceColor)
					continue
				}
				
				# Convert to hex format
				$sourceHex = "#{0:X2}{1:X2}{2:X2}{3:X2}" -f $sourceColor.R, $sourceColor.G, $sourceColor.B, $sourceColor.A
				
				# Apply color mapping
				if ($colorMap.ContainsKey($sourceHex)) {
					$targetHex = $colorMap[$sourceHex]
					
					# Parse target hex color
					if ($targetHex -match '^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$') {
						# Full RGBA format
						$r = [Convert]::ToInt32($matches[1], 16)
						$g = [Convert]::ToInt32($matches[2], 16)
						$b = [Convert]::ToInt32($matches[3], 16)
						$a = [Convert]::ToInt32($matches[4], 16)
						$newColor = [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
						$newBitmap.SetPixel($x, $y, $newColor)
					}
					elseif ($targetHex -match '^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$') {
						# RGB format without alpha, assume no transparency
						$r = [Convert]::ToInt32($matches[1], 16)
						$g = [Convert]::ToInt32($matches[2], 16)
						$b = [Convert]::ToInt32($matches[3], 16)
						$a = 255
						$newColor = [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
						$newBitmap.SetPixel($x, $y, $newColor)
					}
					else {
						# If target hex is invalid, keep original color
						$newBitmap.SetPixel($x, $y, $sourceColor)
					}
				}
				else {
					# If no mapping found, keep original color
					$newBitmap.SetPixel($x, $y, $sourceColor)
				}
			}
		}
		
		# Save the new image
		$newBitmap.Save($targetOutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
		$newBitmap.Dispose()
		
		Write-Host "INFO: Recolored target $($targetPaths[$i])" -ForegroundColor Green
	}
	
	# Dispose of source bitmap
	$sourceBitmap.Dispose()
}

# Get/Generate palette for source image
$sourcePalette = Get-Palette $src
$validTargets  = @()
$validPalettes = @()

# Process each output target
foreach ($target in $out) {
	if (-not $forceRecolor -and (Test-Path "$assetsDirectory/$target" -PathType Leaf)) {
		Write-Host "INFO: Target $target already exists, skipping recolor. Use -forceRecolor to override." -ForegroundColor Cyan
		continue
	}

	# Get/Generate palette for default version of target
	$targetPalette = Get-Palette $target -isDefault
	
	# Skip if either palette couldn't be generated
	if (-not $sourcePalette -or -not $targetPalette) {
		Write-Warning "Skipping recolor of $target due to missing palette"
		continue
	}

	$validTargets  += $target
	$validPalettes += $targetPalette
}

# Recolor the texture using the Recolor-Texture function
Recolor-Texture -sourceImage $src -targetPalettes $validPalettes -targetPaths $validTargets

if (-not $commandLine) {
	Write-Host "Recoloring complete for all specified targets" -ForegroundColor Green
}