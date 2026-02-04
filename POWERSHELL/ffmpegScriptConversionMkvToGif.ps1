function Wait-ForUser {
    param(
        [string]$Message = 'Press Enter to continue'
    )
    Read-Host -Prompt $Message | Out-Null
}

# Ensure ffmpeg exists
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR! ffmpeg was not found!" -ForegroundColor Red
    Write-Host ""

    while ($true) {
        $choice = Read-Host -Prompt "Install ffmpeg now? (y/n)"
        if ($choice -match '^[Yy]$') {
            Write-Host "Attempting to install ffmpeg..." -ForegroundColor Cyan
            $installExit = 1

            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $args = 'install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements'
                $proc = Start-Process -FilePath 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru
                $installExit = $proc.ExitCode
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                $proc = Start-Process -FilePath 'choco' -ArgumentList 'install ffmpeg -y' -Wait -NoNewWindow -PassThru
                $installExit = $proc.ExitCode
            } else {
                Write-Host "No supported package manager found (winget or choco). Please install ffmpeg manually." -ForegroundColor Yellow
                Wait-ForUser
                exit 1
            }

            if ($installExit -ne 0) {
                Write-Host "Installation failed (exit code $installExit). Please install ffmpeg manually." -ForegroundColor Red
                Pause-ForUser
                exit 1
            }

            # Re-check availability
            if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "ffmpeg still not found after installation. You may need to restart your shell or manually add it to PATH." -ForegroundColor Yellow
                Wait-ForUser
                exit 1
            } else {
                Write-Host "ffmpeg installed successfully." -ForegroundColor Green
                break
            }
        } elseif ($choice -match '^[Nn]$') {
            Write-Host "ffmpeg is required. Exiting the script..." -ForegroundColor Yellow
            Pause-ForUser
            exit 1
        } else {
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Yellow
        }
    }
}

# File names
$inputBase = 'input'
$palette = 'palette.png'
$output = 'output.gif'

# Ensure file exists: input (any extension)
$inputMatches = Get-ChildItem -File -Filter "$inputBase.*" -ErrorAction SilentlyContinue
if (-not $inputMatches -or $inputMatches.Count -eq 0) {
    Write-Host ""
    Write-Host "WARNING! Required file was not found: $inputBase.*" -ForegroundColor Yellow
    Write-Host "Please add the aforementioned file and run the script again."
    Write-Host ""
    Pause-ForUser
    exit 1
}
if ($inputMatches.Count -gt 1) {
    Write-Host ""
    Write-Host "WARNING! Multiple input files found: $inputBase.*" -ForegroundColor Yellow
    Write-Host "Please keep only one input file and run the script again."
    Write-Host ""
    Pause-ForUser
    exit 1
}
$input = $inputMatches[0].FullName

# Avoid overwriting an existing file: palette
if (Test-Path $palette) {
    Write-Host ""
    Write-Host "WARNING! File already found: $palette" -ForegroundColor Yellow
    Write-Host "Please [re]move the aforementioned file and run the script again."
    Write-Host ""
    Pause-ForUser
    exit 1
}

# Avoid overwriting an existing file: output
if (Test-Path $output) {
    Write-Host ""
    Write-Host "WARNING! File already found: $output" -ForegroundColor Yellow
    Write-Host "Please [re]move the aforementioned file and run the script again."
    Write-Host ""
    Pause-ForUser
    exit 1
}

# Generating palette
Write-Host ""
Write-Host "Generating palette file..."
& ffmpeg -n -i $input -vf "fps=15,scale=640:-1:flags=lanczos,palettegen" $palette
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR! Failed to generate file: $palette" -ForegroundColor Red
    Pause-ForUser
    exit 1
} else {
    Write-Host ""
    Write-Host "Palette file created, continuing script..." -ForegroundColor Green
    Write-Host ""
}

# Generating GIF
Write-Host "Generating GIF..."
& ffmpeg -n -i $input -i $palette -filter_complex "fps=15,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse" -loop 0 $output
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR! Failed to generate file: $output" -ForegroundColor Red
    Pause-ForUser
    exit 1
} else {
    Write-Host ""
	Write-Host ""
    Write-Host "Output file created."
    Write-Host "File conversion completed successfully!" -ForegroundColor Green
    Write-Host ""
    Wait-ForUser -Message 'Press Enter to clean-up and exit'
    Write-Host ""
}

# Cleaning-up the workspace by removing file: palette
if (-not (Test-Path $palette)) {
    Write-Host ""
    Write-Host "WARNING! File required for deletion was not found: $palette" -ForegroundColor Yellow
	Write-Host "Exiting the script..."
    Write-Host ""
    Pause-ForUser
    exit 1
} else {
    Remove-Item -Force $palette
    exit 0
}
