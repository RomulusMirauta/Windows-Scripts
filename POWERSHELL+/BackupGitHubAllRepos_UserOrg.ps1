# How to use:
# UserOrOrgName is a variable, its value is used to backup repositories from the matching user/organization name.
# Leave UserOrOrgName empty to auto-detect current gh user/organization; set to username/org to override.
# gh = GitHub; gh command = 'gh auth login'

$UserOrOrgName = ""

# If no user/org specified, get the currently authenticated GitHub user
if ([string]::IsNullOrWhiteSpace($UserOrOrgName)) {
    try {
        $UserOrOrgName = gh api user --jq .login
        Write-Host "Detected GitHub user: $UserOrOrgName"
    }
    catch {
        Write-Error "Could not determine GitHub user. Please set `"$UserOrOrgName`" explicitly. $_"
        return
    }
}

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
