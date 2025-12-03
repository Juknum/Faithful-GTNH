<#
.SYNOPSIS
	Displays an image in the PowerShell console using ANSI escape sequences and Unicode block characters.

.DESCRIPTION
	This script loads an image from a file path or URL and renders it in the PowerShell console using 
	ANSI 24-bit color codes and Unicode half-block characters. The script supports resizing images to 
	specific dimensions or fitting them to the console window with various fill modes. The image is 
	rendered using two pixels per character cell, with the top half and bottom half of each character 
	displaying different colors.

.PARAMETER Path
	The file path or URL to the image to display. Supports both local file paths and HTTP/HTTPS URLs.
	This parameter is mandatory.

.PARAMETER FillMode
	Determines how the image should be fitted to the console window. Valid values are:
	- Stretch: Stretches the image to fill the entire console window
	- ProportionalWidth: Scales the image proportionally to match the console width
	- ProportionalHeight: Scales the image proportionally to match the console height
	This parameter cannot be used together with Width and Height parameters.

.PARAMETER Width
	The target width in pixels when resizing the image. Must be used together with the Height parameter.
	Cannot be used with the FillMode parameter.

.PARAMETER Height
	The target height in pixels when resizing the image. Must be used together with the Width parameter.
	Cannot be used with the FillMode parameter.

.EXAMPLE
	.\display.ps1 -Path "C:\Images\photo.jpg"
	Displays the image at its original size in the console.

.EXAMPLE
	.\display.ps1 -Path "https://example.com/image.png" -FillMode ProportionalWidth
	Downloads and displays the image scaled proportionally to fit the console width while maintaining aspect ratio.

.EXAMPLE
	.\display.ps1 -Path "C:\Images\photo.jpg" -Width 100 -Height 50
	Displays the image resized to exactly 100x50 pixels.

.EXAMPLE
	.\display.ps1 -Path "C:\Images\logo.png" -FillMode Stretch
	Displays the image stretched to fill the entire console window.

.NOTES
	Requires PowerShell console with ANSI escape sequence support (Windows 10+ or PowerShell Core).
	The script uses System.Drawing assembly for image processing.
	Virtual Terminal Processing must be enabled for ANSI colors to display correctly.
	Each console character cell displays two pixels vertically using Unicode half-block characters (▀).

.LINK
	https://en.wikipedia.org/wiki/ANSI_escape_code

.OUTPUTS
	None. The script outputs ANSI-formatted text directly to the console.

.INPUTS
	None. This script does not accept pipeline input.
#>

#region Parameters

[CmdletBinding(DefaultParameterSetName = "Normal")]
param(
	[Parameter(Mandatory, ParameterSetName = "Normal")]
	[Parameter(Mandatory, ParameterSetName = "Resize")]
	[Parameter(Mandatory, ParameterSetName = "FillMode")]
	[String]$Path,
	
	[Parameter(Mandatory, ParameterSetName = "FillMode")]
	[ValidateSet("Stretch", "ProportionalWidth", "ProportionalHeight")]
	[String]$FillMode,
	
	[Parameter(Mandatory, ParameterSetName = "Resize")]
	[Int]$Width,
	
	[Parameter(Mandatory, ParameterSetName = "Resize")]
	[Int]$Height
)

#endregion

#region Functions

function RenderImage([System.Drawing.Image]$Image) {
	[Console]::CursorVisible = $false
	for ($y = 0; $y -lt $Image.Height; $y += 2) {
		$pixelStrings = for ($x = 0; $x -lt $Image.Width; $x++) {
			$f = $Image.GetPixel($x, $y)
			"$escape[38;2;$($f.R);$($f.G);$($f.b)m"
			
			if ($y -lt $Image.Height - 1) {
				$b = $Image.GetPixel($x, $y + 1)
				"$escape[48;2;$($b.R);$($b.G);$($b.B)m"
			}
			
			$halfCharString
		}
		[String]::Join('', $pixelStrings + "$escape[0m")
	}
	[Console]::CursorVisible = $true
}

function ResizeImage([System.Drawing.Image]$Image, $NewWidth, $NewHeight) {
	return $img.GetThumbnailImage($NewWidth, $NewHeight, $null, [IntPtr]::Zero)
}

function LoadImage() {
	$urlRegex = "^http[s]?://"
	if ($Path -match $urlRegex) {
		$webClient = [System.Net.WebClient]::new()
		$imageStream = [System.IO.MemoryStream]::new($webClient.DownloadData($Path))
		$webClient.Dispose()
	}
	else {
		$absolutePath = Resolve-Path $Path
		$imageStream = [System.IO.File]::OpenRead($absolutePath)
	}
	$img = [System.Drawing.Image]::FromStream($imageStream, $false, $false)
	$imageStream.Dispose()
	return $img
}

#endregion

#region Main flow

[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null

$escape = [Char]0x1B
$halfCharString = [Char]0x2580

$img = LoadImage

switch ($PSCmdlet.ParameterSetName) {
	"Resize" {
		$img = ResizeImage -Image $img -NewWidth $Width -NewHeight $Height
	}
	"FillMode" {
		switch ($FillMode) {
			"Stretch" {
				$w = [Console]::WindowWidth
				$h = [Console]::WindowHeight * 2
			}
			"ProportionalWidth" {
				$w = [Console]::WindowWidth
				$h = ($img.Height / $img.Width) * [Console]::WindowWidth
			}
			"ProportionalHeight" {
				$w = ($img.Height / $img.Width) * [Console]::WindowHeight * 2
				$h = [Console]::WindowHeight * 2
			}
		}
		
		$img = ResizeImage -Image $img -NewWidth $w -NewHeight $h
	}
}

RenderImage -Image $img 

$img.Dispose()

#endregion