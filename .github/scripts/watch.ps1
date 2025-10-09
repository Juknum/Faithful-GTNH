
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
			Start-Process Powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($PSScriptRoot)/$($script.name)`" $($argList)" -NoNewWindow -Wait

			Write-Host "-------------------------" -ForegroundColor DarkGray
		}

		Write-Host ""
	}
	else {
		Write-Host "> No scripts found for modified file" -ForegroundColor DarkGray
	}

	
}