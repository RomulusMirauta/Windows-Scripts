function Wait-ForUser {
	param(
		[string]$Message = 'Press Enter to continue'
	)
	Read-Host -Prompt $Message | Out-Null
}

Write-Host "Video Trimmer (seconds)" -ForegroundColor Gray
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
                Write-Host ""
                Write-Host "ffmpeg installed successfully." -ForegroundColor Green
                break
            }
        } elseif ($choice -match '^[Nn]$') {
            Write-Host ""
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
	Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
	Write-Host "Supported file extensions: $($videoExtensions -join ', ')"
	Write-Host ""
	Wait-ForUser
	exit 1
}
if ($sourceMatches.Count -gt 1) {
	Write-Host "WARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
	Write-Host "Please keep only one video file and run the script again." -ForegroundColor Yellow
	Write-Host ""
	Wait-ForUser
	exit 1
}

$inputFile = $sourceMatches[0]

# Store the full path as a plain string to safely handle spaces or special chars
$inputPath = [string]$inputFile.FullName

# Create output directory named "<BaseName>_trimmed" next to the input file
$outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_trimmed")
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}
# Choose trim position
Write-Host ""
Write-Host "Trim from where?" -ForegroundColor Cyan
Write-Host "[0] Beginning"
Write-Host "[1] End"
Write-Host "[2] Both"

$trimChoice = $null
while (-not $trimChoice) {
    Write-Host ""
    $choice = Read-Host -Prompt "Enter choice (0-2)" 
    if ($choice -in @('0','1','2')) {
        $trimChoice = $choice
    } else {
        Write-Host ""
        Write-Host "Invalid input. Please enter 0, 1, or 2." -ForegroundColor Yellow
    }
}

# Get trim seconds
$trimSecondsStart = 0
$trimSecondsEnd = 0

if ($trimChoice -eq '0' -or $trimChoice -eq '1') {
    $trimSeconds = $null
    while (-not $trimSeconds) {
        Write-Host ""

        if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
            Write-Host "ERROR: ffprobe was not found in PATH. Please re-install ffmpeg (which includes ffprobe) or manually add ffprobe to PATH." -ForegroundColor Red
            Wait-ForUser
            exit 1
        }

        $durationRaw = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputPath
        $duration = [double]$durationRaw
        Write-Host "Current video duration: $([math]::Round($duration, 2)) seconds"

        $secondsInput = Read-Host -Prompt "Enter number of seconds to trim (e.g., 5)"

        if ($secondsInput -match '^[1-9][0-9]*$') {
            $trimSeconds = [int]$secondsInput
        } else {
            Write-Host ""
            Write-Host "Invalid input. Please enter a higher than zero integer." -ForegroundColor Yellow
        }
    }

    while ($trimSeconds -ge $duration) {
        Write-Host ""
        Write-Host "ERROR: Trim seconds must be less than video duration ($([math]::Round($duration, 2))s)." -ForegroundColor Red
        $secondsInput = Read-Host -Prompt "Enter a valid number of seconds to trim"
        if ($secondsInput -match '^[1-9][0-9]*$') {
            $trimSeconds = [int]$secondsInput
        } else {
            Write-Host ""
            Write-Host "Invalid input. Please enter a higher than zero integer." -ForegroundColor Yellow
        }
    }

    if ($trimChoice -eq '0') {
        $trimSecondsStart = $trimSeconds
    } else {
        $trimSecondsEnd = $trimSeconds
    }
} else {
    # Both
    $trimSecondsStart = $null
    $trimSecondsEnd = $null
    if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: ffprobe was not found in PATH. Please re-install ffmpeg (which includes ffprobe) or manually add ffprobe to PATH." -ForegroundColor Red
        Wait-ForUser
        exit 1
    }
    $durationRaw = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputPath
    $duration = [double]$durationRaw
    Write-Host "Current video duration: $([math]::Round($duration, 2)) seconds"

    while ($null -eq $trimSecondsStart) {
        $startInput = Read-Host -Prompt "Enter number of seconds to trim from the beginning (e.g., 5)"
        if ($startInput -match '^[0-9]+$') {
            $trimSecondsStart = [int]$startInput
        } else {
            Write-Host ""
            Write-Host "Invalid input. Please enter a zero or positive integer." -ForegroundColor Yellow
        }
    }
    while ($null -eq $trimSecondsEnd) {
        $endInput = Read-Host -Prompt "Enter number of seconds to trim from the end (e.g., 5)"
        if ($endInput -match '^[0-9]+$') {
            $trimSecondsEnd = [int]$endInput
        } else {
            Write-Host ""
            Write-Host "Invalid input. Please enter a zero or positive integer." -ForegroundColor Yellow
        }
    }
    while (($trimSecondsStart + $trimSecondsEnd) -ge $duration) {
        Write-Host ""
        Write-Host "ERROR: The sum of trim seconds must be less than video duration ($([math]::Round($duration, 2))s)." -ForegroundColor Red
        $trimSecondsStart = $null
        $trimSecondsEnd = $null
        while ($null -eq $trimSecondsStart) {
            $startInput = Read-Host -Prompt "Enter number of seconds to trim from the beginning (e.g., 5)"
            if ($startInput -match '^[0-9]+$') {
                $trimSecondsStart = [int]$startInput
            } else {
                Write-Host ""
                Write-Host "Invalid input. Please enter a zero or positive integer." -ForegroundColor Yellow
            }
        }
        while ($null -eq $trimSecondsEnd) {
            $endInput = Read-Host -Prompt "Enter number of seconds to trim from the end (e.g., 5)"
            if ($endInput -match '^[0-9]+$') {
                $trimSecondsEnd = [int]$endInput
            } else {
                Write-Host ""
                Write-Host "Invalid input. Please enter a zero or positive integer." -ForegroundColor Yellow
            }
        }
    }
}

$trimLabel = if ($trimChoice -eq '0') { 'beginning' } elseif ($trimChoice -eq '1') { 'end' } else { 'both' }

# Perform trim
function Resolve-OutputPathAndSwitch {
    param(
        [string]$OutputDir,
        [string]$Filename
    )
    $out = Join-Path -Path $OutputDir -ChildPath $Filename
    if (Test-Path -Path $out) {
        while ($true) {
            Write-Host ""
            Write-Host "Output already exists: $out."
            Write-Host ""
            $ans = Read-Host -Prompt  "Overwrite? (y/n)"
            if ($ans -match '^[Yy]$') {
                return @{ Output = $out; Switch = '-y' }
            } elseif ($ans -match '^[Nn]$') {
                Write-Host ""
                Write-Host "Operation canceled by user. Exiting script..." -ForegroundColor Yellow
                Wait-ForUser
                exit 0
            } else {
                Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Yellow
            }
        }
    } else {
        return @{ Output = $out; Switch = '-n' }
    }
}
if ($trimChoice -eq '0') {
    $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsStart}$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    Write-Host "" 
    Write-Host "Trimming $trimSecondsStart second(s) from the beginning..."
    Write-Host ""
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch
    & ffmpeg $overwriteSwitch -ss $trimSecondsStart -i $inputPath -c copy $output
} elseif ($trimChoice -eq '1') {
    $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsEnd}$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    Write-Host ""
    Write-Host "Trimming $trimSecondsEnd second(s) from the end..."
    Write-Host ""
    $targetDuration = $duration - $trimSecondsEnd
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch
    & ffmpeg $overwriteSwitch -i $inputPath -t $targetDuration -c copy $output
} else {
    $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsStart}start_${trimSecondsEnd}end$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    Write-Host ""
    Write-Host "Trimming $trimSecondsStart second(s) from the beginning and $trimSecondsEnd second(s) from the end..."
    Write-Host ""
    $targetDuration = $duration - $trimSecondsStart - $trimSecondsEnd
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch
    & ffmpeg $overwriteSwitch -ss $trimSecondsStart -i $inputPath -t $targetDuration -c copy $output
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Trim failed. Exiting the script..." -ForegroundColor Red
    Write-Host ""
    Wait-ForUser
    exit 1
}

Write-Host "" 
Write-Host "Output created: $output" -ForegroundColor Green
Write-Host ""
