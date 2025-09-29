# Script to extract color palettes from texture files defined in JSON files

# Ensure ImageMagick is installed (required for palette extraction)
if (-not (Get-Command "magick.exe" -ErrorAction SilentlyContinue)) {
	Write-Error "ImageMagick is required for this script. Please install it from https://imagemagick.org/"
	exit 1
}

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Get all JSON files in the script directory
$jsonFiles = Get-ChildItem -Path $scriptDir -Filter "*.json"

# Function to extract palette from a texture file and save it
function Extract-Palette {
	param(
		[string]$texturePath,
		[string]$outputPath
	)
	
	# Check if texture file exists
	if (-not (Test-Path $texturePath)) {
		Write-Warning "Texture file not found: $texturePath"
		return
	}
	
	# Create output directory if it doesn't exist
	$outputDir = Split-Path -Parent $outputPath
	if (-not (Test-Path $outputDir)) {
		New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
	}
	
	# Extract palette using ImageMagick
	# This creates a palette image with the unique colors used in the texture
	& magick.exe $texturePath -unique-colors $outputPath
}

# Process each JSON file
foreach ($jsonFile in $jsonFiles) {
	Write-Host "Processing $($jsonFile.Name)..."
	
	# Create a directory for this JSON file's palettes
	$paletteDir = Join-Path -Path $scriptDir -ChildPath "$($jsonFile.BaseName)"
	if (-not (Test-Path $paletteDir)) {
		New-Item -ItemType Directory -Path $paletteDir -Force | Out-Null
	}
	
	# Read the JSON content
	try {
		$jsonContent = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
		
		# Extract origin texture path and create full path
		$originTexture = $jsonContent.origin
		$originTexturePath = Join-Path -Path $scriptDir -ChildPath "..\..\assets\$originTexture"
		
		# Extract palette for origin texture
		$originPalettePath = Join-Path -Path $paletteDir -ChildPath "origin.png"
		Extract-Palette -texturePath $originTexturePath -outputPath $originPalettePath
		
		# Get the color count from origin texture
		$originColorCount = (& magick.exe $originTexturePath -format "%k" info:)
		
		# Extract palettes for all target textures
		if ($jsonContent.targets -and $jsonContent.targets.Count -gt 0) {
			for ($i = 0; $i -lt $jsonContent.targets.Count; $i++) {
				$targetTexture = $jsonContent.targets[$i]
				$targetTexturePath = Join-Path -Path $scriptDir -ChildPath "..\..\.default\$targetTexture"
				$targetPalettePath = Join-Path -Path $paletteDir -ChildPath "target_${i}.png"
				
				# Only extract palette if it doesn't exist to avoid overwriting manual edits
				if (-not (Test-Path $targetPalettePath)) {
					Extract-Palette -texturePath $targetTexturePath -outputPath $targetPalettePath
				}
				
				# Verify color count matches origin texture (using image width as a proxy for color count)
				$targetColorCount = (& magick.exe $targetPalettePath -format "%w" info:)
				if ($targetColorCount -ne $originColorCount) {
					Write-Warning "Color count mismatch for ${targetTexture} #${i}: Has $targetColorCount colors, origin has $originColorCount colors"
				}
			}
		}

		Write-Host "Processed $($jsonFile.Name)..."
	}
	catch {
		Write-Error "Failed to process $($jsonFile.Name): $_"
	}
}

Write-Host "Palettes extraction completed!"

Write-Host "Starting texture recoloring process..."

# Function to recolor a texture using a palette
function Recolor-Texture {
	param(
		[string]$sourceTexture,
		[string]$originPalette,
		[string]$targetPalette,
		[string]$outputTexture
	)
	
	# Check if all required files exist
	if (-not (Test-Path $sourceTexture) -or -not (Test-Path $originPalette) -or -not (Test-Path $targetPalette)) {
		Write-Warning "Missing required files for recoloring: $sourceTexture, $originPalette, or $targetPalette"
		return $false
	}
	
	# Create output directory if it doesn't exist
	$outputDir = Split-Path -Parent $outputTexture
	if (-not (Test-Path $outputDir)) {
		New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
	}
	
	# Use ImageMagick to recolor the texture using the palettes
	try {
		# Get list of colors from origin and target palettes
		# Get width of the palette image
		$width = [int](& magick.exe $originPalette -format "%w" info:)
		# Get all colors by iterating over each pixel in the row
		$originColors = @()
		for ($x = 0; $x -lt $width; $x++) {
			$color = (& magick.exe $originPalette -format "%[pixel:u.p{$x,0}]" info:)
			$originColors += $color
		}
		Write-Host "Origin Colors: $originColors"

		$targetColors = @()
		for ($x = 0; $x -lt $width; $x++) {
			$color = (& magick.exe $targetPalette -format "%[pixel:u.p{$x,0}]" info:)
			$targetColors += $color
		}
		write-Host "Target Colors: $targetColors"
		
		# Check if color count matches
		if ($originColors.Count -ne $targetColors.Count) {
			Write-Warning "Color count mismatch: Origin ($($originColors.Count)) vs Target ($($targetColors.Count))"
			return $false
		}
		
		# Create a temporary copy of the source texture
		$tempTexture = "$env:TEMP\temp_texture_$(Get-Random).png"
		Copy-Item -Path $sourceTexture -Destination $tempTexture -Force
		
		# Replace each color individually
		for ($i = 0; $i -lt $originColors.Count; $i++) {
			$originColor = $originColors[$i]
			$targetColor = $targetColors[$i]
			
			& magick.exe $tempTexture -fill $targetColor -opaque $originColor $tempTexture
		}
		
		# Save the final result
		Move-Item -Path $tempTexture -Destination $outputTexture -Force
		return $true
	}
	catch {
		Write-Warning "Failed to recolor texture: $_"
		return $false
	}
}

# Process each JSON file for recoloring
foreach ($jsonFile in $jsonFiles) {
	Write-Host "Recoloring textures for $($jsonFile.Name)..."
	
	$paletteDir = Join-Path -Path $scriptDir -ChildPath "$($jsonFile.BaseName)"
	$originPalette = Join-Path -Path $paletteDir -ChildPath "origin.png"
	
	# Skip if origin palette doesn't exist
	if (-not (Test-Path $originPalette)) {
		Write-Warning "Origin palette not found for $($jsonFile.Name), skipping recoloring"
		continue
	}
	
	try {
		$jsonContent = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
		$originTexture = $jsonContent.origin
		$originTexturePath = Join-Path -Path $scriptDir -ChildPath "..\..\assets\$originTexture"
		
		if ($jsonContent.targets -and $jsonContent.targets.Count -gt 0) {
			for ($i = 0; $i -lt $jsonContent.targets.Count; $i++) {
				$targetTexture = $jsonContent.targets[$i]
				$targetPalette = Join-Path -Path $paletteDir -ChildPath "target_${i}.png"
				$outputTexturePath = Join-Path -Path $scriptDir -ChildPath "..\..\assets\$targetTexture"
				
				# Only attempt recoloring if both palettes exist
				if ((Test-Path $targetPalette) -and (Test-Path $originTexturePath)) {
					Write-Host "  Recoloring $targetTexture..."
					$success = Recolor-Texture -sourceTexture $originTexturePath `
												-originPalette $originPalette `
												-targetPalette $targetPalette `
												-outputTexture $outputTexturePath
					
					if ($success) {
						Write-Host "  Successfully recolored $targetTexture" -ForegroundColor Green
					}
				}
				else {
					Write-Warning "  Missing palette or texture for $targetTexture, skipping"
				}
			}
		}
	}
	catch {
		Write-Error "Failed to process recoloring for $($jsonFile.Name): $_"
	}
}

Write-Host "Texture recoloring completed!" -ForegroundColor Green