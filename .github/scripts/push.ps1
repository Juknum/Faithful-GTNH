##############################################################
# PowerShell script to add, commit, and push changes to the Git repository.
#
# Usage:
#   .\push.ps1 -CommitMessage "Your commit message here"
#
##############################################################

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