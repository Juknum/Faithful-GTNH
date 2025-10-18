##############################################################
# PowerShell script to calculate and update resource pack progress
# in the README.md file based on extracted assets and a blacklist.
#
# Usage:
#   .\progress.ps1
#
##############################################################

$progressData      = @{}
$totalItemsAll     = 0
$completedItemsAll = 0

# Get all directories in assets
$defaultPath = Join-Path $PSScriptRoot "..\..\.default"
$assetDirs   = Get-ChildItem -Path $defaultPath -Directory

$progressJsonPath = Join-Path $PSScriptRoot "..\configs\progress.jsonc"
$progressJson     = Get-Content -Path $progressJsonPath -Raw | ConvertFrom-Json

foreach ($dir in $assetDirs) {
	$dirName = $dir.Name
	$defaultPath = ".default/$dirName"

	if (Test-Path $defaultPath) {
		# Count files in default directory
		$defaultFiles = Get-ChildItem -Path $defaultPath -Recurse -File
		$totalItems = $defaultFiles.Count

		# Count matching files in assets directory
		$completedItems = 0
		foreach ($file in $defaultFiles) {
			$relativePath = $file.FullName.Replace("$pwd\.default\$dirName\", "")
			$assetFilePath = Join-Path -Path $dirName -ChildPath $relativePath
			
			if (Test-Path "assets/$($assetFilePath)") {
				$completedItems++
			}
			# If the file is blacklisted, consider it as completed
			elseif ($progressJson.blacklist.Contains($assetFilePath.Replace("\", "/"))) {
				$completedItems++
			}
			elseif ($progressJson.transparents.Contains($assetFilePath.Replace("\", "/"))) {
				$totalItems--
			}
		}

		# Calculate percentage
		$percentage = if ($totalItems -gt 0) { [math]::Round(($completedItems / $totalItems) * 100, 2) } else { 0 }

		# Store progress data
		$progressData[$dirName] = @{
			"Total" = $totalItems
			"Completed" = $completedItems
			"Percentage" = $percentage
		}

		$totalItemsAll += $totalItems
		$completedItemsAll += $completedItems
	}
}

# Calculate overall percentage
$overallPercentage = if ($totalItemsAll -gt 0) { [math]::Round(($completedItemsAll / $totalItemsAll) * 100, 2) } else { 0 }

# Generate progress section for README
$readmeContent = Get-Content -Path "README.md" -Raw

$progressSection = "## Resource Pack Progress`n`n"
$progressSection += "Overall Progress: $completedItemsAll/$totalItemsAll ($overallPercentage%)`n"
$progressSection += "`n"
$progressSection += "| Namespace | Completed | Total | Percentage |`n"
$progressSection += "|-----------|-----------|-------|------------|`n"

foreach ($key in ($progressData.Keys | Sort-Object)) {
	$item = $progressData[$key]
	$bar = ("█" * [math]::Floor($item.Percentage / 10)) + ("░" * (10 - [math]::Floor($item.Percentage / 10)))
	$progressSection += "| $key | $($item.Completed) | $($item.Total) | $bar $($item.Percentage)% |`n"
}

$progressSection += "`n"
$progressSection += "> See [ignored items](https://github.com/Juknum/Faithful-GTNH/blob/2.8.0/.github/configs/progress.jsonc)  "
$progressSection += "`n"

# Update or add the progress section in README
if ($readmeContent -match "\#\# Resource Pack Progress(\r?\n[\s\S]*?)(?=^\#\#|\z)") {
	# Create a pattern that captures only the progress section while preserving what comes after
	$pattern = "(\#\# Resource Pack Progress)(\r?\n[\s\S]*?)(?=^\#\#|\z)"
	$replacement = "${progressSection}`n"
	$readmeContent = $readmeContent -replace $pattern, $replacement
} else {
	$readmeContent += "`n`n$progressSection"
}

Set-Content -Path "README.md" -Value $readmeContent