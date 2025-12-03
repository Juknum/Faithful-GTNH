<#
.SYNOPSIS
	Monitors git commit changes and executes associated scripts based on configuration.

.DESCRIPTION
	This script watches for file changes in the latest git commit and executes 
	corresponding scripts defined in watcher.jsonc configuration file. It parses 
	the modified files from the latest commit, matches them against configured 
	paths, and runs the associated scripts with their specified arguments.

.EXAMPLE
	.\watcher.ps1
	Checks the latest git commit for modified files and runs configured scripts.

.NOTES
	- Requires git to be installed and available in PATH
	- Requires .github/configs/watcher.jsonc configuration file
	- Scripts are executed using pwsh.exe with Bypass execution policy
	- Arguments support arrays, booleans (as switches), and string values

.INPUTS
	None. This script does not accept pipeline input.

.OUTPUTS
	Console output showing:
	- Latest commit hash
	- Modified files being processed
	- Scripts found and executed for each file
	- Execution status messages
#>

Write-Host "Starting watcher script..." -ForegroundColor Green

$currentHash   = (git rev-parse HEAD).Trim()
$modifiedFiles = (git diff-tree --no-commit-id --name-only $currentHash -r).Trim() -split "`n"

Write-Host "Latest commit ($currentHash):" -ForegroundColor Cyan
Write-Host ""

# Verify watcher.jsonc if any of the modified files are under watcher paths
# if so, run the scripts referenced for that path
foreach ($file in $modifiedFiles) {
	Write-Host "> file: $file"

	$scripts = (Get-Content ".github/configs/watcher.jsonc" | ConvertFrom-Json).$file.scripts

	if ($scripts) {
		Write-Host "> Found $($scripts.Count) script(s) for modified file" -ForegroundColor DarkGray
		
		foreach ($script in $scripts) {
			$argList = @()
			foreach ($key in $script.args.PSObject.Properties) {
				$value = $key.Value
				
				# Handle different types of arguments
				if ($value -is [System.Array]) {
					# For array values, add each item as a separate argument
					$argList += $value
				} elseif ($value -is [System.Boolean]) {
					# For boolean values, add as switch parameters if true
					if ($value) {
						$argList += "-$($key.Name)"
					}
				} else {
					# For strings and other simple types
					$argList += "-$($key.Name)"
					$argList += $value.ToString()
				}
			}

			Write-Host "-------------------------" -ForegroundColor DarkGray
			Write-Host "> Running: $($script.name) $($argList)" -ForegroundColor Cyan

			# Call the script with the processed arguments
			Start-Process pwsh.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($PSScriptRoot)/$($script.name)`" $($argList)" -NoNewWindow -Wait
			# & ".github/scripts/$($script.name)" @argList

			Write-Host "-------------------------" -ForegroundColor DarkGray
		}

		Write-Host ""
	}
	else {
		Write-Host "> No scripts found for modified file" -ForegroundColor DarkGray
	}

	
}