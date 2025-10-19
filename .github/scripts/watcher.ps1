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