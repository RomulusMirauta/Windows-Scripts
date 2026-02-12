# DO NOT FORGET !!!
# To modify UserOrOrgName variable according to the GitHub user or organization you want to backup repositories from.
# By default, it will clone all repositories of the current user or organization (if logged in with gh auth login).

$UserOrOrgName = ""

# Create backup folder name with current date (dd-MM-yyy)
$Date = Get-Date -Format 'dd-MM-yyy'
$BackupFolderName = ("!BackupGitHubAllRepos", $UserOrOrgName, $Date) -join "_"
$BackupFolderPath = Join-Path -Path (Get-Location) -ChildPath $BackupFolderName

# Check if folder already exists
if (Test-Path -LiteralPath $BackupFolderPath) {
    Write-Warning "Backup folder already exists: $BackupFolderPath"

    Write-Host ""
    $Message = "Press Enter to continue"
    Read-Host -Prompt $Message | Out-Null
    Exit

} else {
    New-Item -ItemType Directory -Path $BackupFolderPath -Force | Out-Null
    Write-Host "Created backup folder: $BackupFolderPath"

    # Go to backup folder
    Set-Location -Path $BackupFolderPath

    # Clone all repositories of the user or organization
    gh repo list $UserOrOrgName --limit 100 | ForEach-Object { gh repo clone $_.split()[0] }
}
