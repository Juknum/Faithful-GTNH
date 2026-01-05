<#
.SYNOPSIS
	Commits and pushes changes to a Git repository with a standardized commit message.

.DESCRIPTION
	This script checks if there are any uncommitted changes in the Git repository. If changes exist, it stages all 
	files, commits them with a "chore:" prefix followed by the provided message, and optionally pushes to the remote 
	repository. If no changes are detected, it displays a message and exits without performing any Git operations.

.PARAMETER CommitMessage
	The commit message to use. This message will be automatically prefixed with "chore: " in the Git commit.

.PARAMETER NoPush
	If specified, the script will commit changes but will not push them to the remote repository.

.EXAMPLE
	.\git.ps1 -CommitMessage "update resource pack textures"
	Commits all changes with the message "chore: update resource pack textures" and pushes to the remote repository.

.EXAMPLE
	.\git.ps1 -CommitMessage "fix transparency issues" -NoPush
	Commits all changes with the message "chore: fix transparency issues" without pushing to the remote repository.

.NOTES
	This script requires Git to be installed and accessible in the system PATH.
	The script stages all files using 'git add *', which may include unintended files.
	Ensure you are in the correct Git repository directory before running this script.

.OUTPUTS
	System.String
	Outputs status messages to the console indicating whether changes were committed or if there were no changes to commit.

.INPUTS
	None
	This script does not accept pipeline input.
#>

param(
	[Parameter(Mandatory)]
	[string]$CommitMessage,
	
	[Parameter()]
	[switch]$NoPush
)

if (git status --porcelain) {
	git add *
	git commit -m "chore: $($CommitMessage)"
	
	if (-not $NoPush) {
		git push
	}
	else {
		Write-Host "Changes committed but not pushed (NoPush flag was specified)."
	}
}
else {
	Write-Host "No changes to commit."
}