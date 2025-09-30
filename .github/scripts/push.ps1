
param(
	[Parameter(Mandatory)]
	[string]$CommitMessage
)

if (git status --porcelain) {
	git add *
	git commit -m "chore: $($CommitMessage)"
	git push
} else {
	Write-Host "No changes to commit."
}