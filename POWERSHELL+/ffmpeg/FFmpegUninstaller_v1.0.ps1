function Wait-ForUser {
    param(
        [string]$Message = 'Press Enter to continue'
    )
    Read-Host -Prompt $Message | Out-Null
}

winget uninstall --id Gyan.FFmpeg

Write-Host ""
Wait-ForUser
