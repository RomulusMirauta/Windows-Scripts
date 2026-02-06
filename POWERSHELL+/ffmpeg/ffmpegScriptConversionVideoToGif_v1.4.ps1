function Wait-ForUser {
    param(
        [string]$Message = 'Press Enter to continue'
    )
    Read-Host -Prompt $Message | Out-Null
}

Write-Host "Video to GIF conversion script, by @echo off" -ForegroundColor Gray
Write-Host ""

# Ensure ffmpeg exists
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR: ffmpeg was not found." -ForegroundColor Red
    Write-Host ""

    while ($true) {
        $choice = Read-Host -Prompt "Install ffmpeg now? (y/n)"
        if ($choice -match '^[Yy]$') {
            Write-Host "Attempting to install ffmpeg..." -ForegroundColor Cyan
            $installExit = 1

            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $proc = Start-Process -FilePath 'winget' -ArgumentList 'install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements' -Wait -NoNewWindow -PassThru
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
                Wait-ForUser
                exit 1
            }

            # Refresh PATH in this session (avoid restart after install)
            try {
                $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
                if ($machinePath -and $userPath) {
                    $env:Path = "$machinePath;$userPath"
                } elseif ($machinePath) {
                    $env:Path = $machinePath
                } elseif ($userPath) {
                    $env:Path = $userPath
                }
            } catch {
                Write-Host "WARNING: Could not refresh PATH automatically. Please run the script again or manually add ffmpeg to PATH." -ForegroundColor Yellow
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
            Write-Host "ffmpeg installation is mandatory. Exiting the script..." -ForegroundColor Yellow
            Wait-ForUser
            exit 1
        } else {
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ""
    Write-Host "ffmpeg found, continuing script..." -ForegroundColor Green
    Write-Host ""
}

# Supported video file extensions (case-insensitive)
$videoExtensions = @(
    '.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv',
    '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts',
    '.m2ts', '.ogv', '.vob'
)

# Find video files in current directory
$sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
    $videoExtensions -contains $_.Extension.ToLower()
}

if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
    Write-Host ""
    Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
    Write-Host "Supported file extensions: $($videoExtensions -join ', ')"
    Write-Host "Please add a single video file and run the script again."
    Write-Host ""
    Wait-ForUser
    exit 1
}
if ($sourceMatches.Count -gt 1) {
    Write-Host ""
    Write-Host "WARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
    Write-Host "Supported file extensions: $($videoExtensions -join ', ')"
    Write-Host "Please keep only one video file and run the script again."
    Write-Host ""
    Wait-ForUser
    exit 1
}

$inputFile = $sourceMatches[0]

# File name (match input file base name)
$palette = "$($inputFile.BaseName).png"

# Scaling options
$scaleOptions = @(
    @{ Label = 'Keep original size'; Value = 'iw:-1' },
    @{ Label = '320px width'; Value = '320:-1' },
    @{ Label = '480px width'; Value = '480:-1' },
    @{ Label = '640px width (default)'; Value = '640:-1' },
    @{ Label = '960px width'; Value = '960:-1' },
    @{ Label = '1280px width'; Value = '1280:-1' },
    @{ Label = '1440px width'; Value = '1440:-1' },
    @{ Label = '1600px width'; Value = '1600:-1' },
    @{ Label = '1920px width'; Value = '1920:-1' },
    @{ Label = 'Custom width'; Value = 'custom' }
)

Write-Host ""
Write-Host "Please select the scaling option:" -ForegroundColor Cyan
for ($i = 0; $i -lt $scaleOptions.Count; $i++) {
    Write-Host "[$i] $($scaleOptions[$i].Label)"
}

Write-Host ""

$selectedScale = $null
while (-not $selectedScale) {
    $choice = Read-Host -Prompt "Enter choice (0-$($scaleOptions.Count - 1))"
    Write-Host ""
    if ($choice -match '^[0-9]+$') {
        $index = [int]$choice
        if ($index -ge 0 -and $index -lt $scaleOptions.Count) {
            $selectedScale = $scaleOptions[$index].Value
        }
    }
    if (-not $selectedScale) {
        Write-Host "Invalid input. Please enter a number between 0 and $($scaleOptions.Count - 1)." -ForegroundColor Yellow
    }
}

if ($selectedScale -eq 'custom') {
    while ($true) {
        Write-Host ""
        $customWidth = Read-Host -Prompt "Enter custom width in pixels (e.g., 720)"
        if ($customWidth -match '^[1-9][0-9]*$') {
            $selectedScale = "${customWidth}:-1"
            break
        } else {
            Write-Host ""
            Write-Host "Invalid width. Please enter a higher than zero integer." -ForegroundColor Yellow
        }
    }
}

# Output file name includes scale option info
$scaleSuffix = if ($selectedScale -eq 'iw:-1') {
    'orig'
} else {
    ($selectedScale -split ':')[0]
}
$output = "$($inputFile.BaseName)_${scaleSuffix}.gif"

# Avoid overwriting an existing file: palette
if (Test-Path $palette) {
    Write-Host ""
    Write-Host "WARNING: File already found: $palette" -ForegroundColor Yellow
    Write-Host "Please [re]move the aforementioned file and run the script again."
    Write-Host ""
    Wait-ForUser
    exit 1
}

# Avoid overwriting an existing file: output
if (Test-Path $output) {
    Write-Host ""
    Write-Host "WARNING: File already found: $output" -ForegroundColor Yellow
    Write-Host "Please [re]move the aforementioned file and run the script again."
    Write-Host ""
    Wait-ForUser
    exit 1
}

# Generating palette
Write-Host ""
Write-Host "Generating palette file..."
& ffmpeg -n -i $inputFile.FullName -vf "fps=15,scale=${selectedScale}:flags=lanczos,palettegen" $palette
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to generate file: $palette" -ForegroundColor Red
    Wait-ForUser
    exit 1
} else {
    Write-Host ""
    Write-Host "Palette file created, continuing script..." -ForegroundColor Green
    Write-Host ""
}

# Generating GIF
Write-Host "Generating GIF..."
& ffmpeg -n -i $inputFile.FullName -i $palette -filter_complex "fps=15,scale=${selectedScale}:flags=lanczos[x];[x][1:v]paletteuse" -loop 0 $output
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to generate file: $output" -ForegroundColor Red
    Wait-ForUser
    exit 1
} else {
    Write-Host ""
    Write-Host ""
    Write-Host "Output file created."
    Write-Host "File conversion completed successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "Script will clean-up and exit." -ForegroundColor Green
}

# Cleaning-up the workspace by removing file: palette
if (-not (Test-Path $palette)) {
    Write-Host ""
    Write-Host "WARNING: File required for deletion was not found: $palette" -ForegroundColor Yellow
    Write-Host "Exiting the script..."
    Write-Host ""
    Wait-ForUser
    exit 1
} else {
    Remove-Item -Force $palette
    exit 0
}
