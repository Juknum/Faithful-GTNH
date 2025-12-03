<#
.SYNOPSIS
	Watches for file changes and executes associated scripts based on configuration.

.DESCRIPTION
	This script monitors specified files and checks them against a watcher configuration file (watcher.jsonc).
	When a match is found, it executes the associated scripts with their configured arguments.
	The script handles various argument types including arrays, booleans, and strings.

.PARAMETER filenames
	An array of file paths that have been modified and need to be checked against the watcher configuration.

.EXAMPLE
	.\watch.ps1 -filenames "assets/minecraft/textures/blocks/stone.png"
	Checks if the stone.png file has associated scripts in watcher.jsonc and executes them.

.EXAMPLE
	.\watch.ps1 -filenames @("file1.json", "file2.png")
	Processes multiple files and executes their associated scripts if configured.

.NOTES
	- Requires a watcher.jsonc configuration file in .github/configs/ directory
	- The configuration file should map file paths to script definitions with arguments
	- Scripts are executed using PowerShell with Bypass execution policy
	- Each script execution is logged with visual separators for clarity

.INPUTS
	System.String[]
	Array of file paths to be processed.

.OUTPUTS
	None. The script outputs status messages to the console but does not return objects.
#>

param(
	[string[]]$filenames
)

# Verify watcher.jsonc if any of the modified files are under watcher paths
# if so, run the scripts referenced for that path
foreach ($file in $filenames) {
	Write-Host "> file: $file"

	$scripts = (Get-Content ".github/configs/watcher.jsonc" | ConvertFrom-Json).$file.scripts

	if ($scripts) {
		Write-Host "> Found $($scripts.Count) script(s) for given file" -ForegroundColor DarkGray
		
		foreach ($script in $scripts) {
			$argList = @()
			foreach ($key in $script.args.PSObject.Properties) {
				$value = $key.Value
				
				# Handle different types of arguments
				if ($value -is [System.Array]) {
					# For array values, add each item as a separate argument
					$argList += "-$($key.Name)"
					$argList += "`"$($value)`""
				}
				elseif ($value -is [System.Boolean]) {
					# For boolean values, add as switch parameters if true
					if ($value) {
						$argList += "-$($key.Name)"
					}
				}
				else {
					# For strings and other simple types
					$argList += "-$($key.Name)"
					$argList += $value.ToString()
				}
			}

			Write-Host "-------------------------" -ForegroundColor DarkGray
			Write-Host "> Running: $($script.name) $($argList)" -ForegroundColor Cyan

			# Call the script with the processed arguments
			Start-Process pwsh.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($PSScriptRoot)/$($script.name)`" $($argList)" -NoNewWindow -Wait

			Write-Host "-------------------------" -ForegroundColor DarkGray
		}

		Write-Host ""
	}
	else {
		Write-Host "> No scripts found for modified file" -ForegroundColor DarkGray
	}

	
}