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

# Choose trim position
Write-Host ""
Write-Host "Trim from where?" -ForegroundColor Cyan
Write-Host "[0] Beginning"
Write-Host "[1] End"

$trimChoice = $null
while (-not $trimChoice) {
    Write-Host ""
    $choice = Read-Host -Prompt "Enter choice (0-1)" 
	if ($choice -eq '0' -or $choice -eq '1') {
		$trimChoice = $choice
	} else {
        Write-Host ""
		Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
	}
}

# Get trim seconds
$trimSeconds = $null
while (-not $trimSeconds) {
    Write-Host ""

    if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: ffprobe was not found in PATH. Please re-install ffmpeg (which includes ffprobe) or manually add ffprobe to PATH." -ForegroundColor Red
        Wait-ForUser
        exit 1
    }

    $durationRaw = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputFile.FullName
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

$trimLabel = if ($trimChoice -eq '0') { 'beginning' } else { 'end' }
$output = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSeconds}$($inputFile.Extension)"

# Perform trim
if ($trimChoice -eq '0') {
    Write-Host "" 
    Write-Host "Trimming $trimSeconds seconds from the beginning..."
    Write-Host ""
    & ffmpeg -n -ss $trimSeconds -i $inputFile.FullName -c copy $output
} else {
    Write-Host ""
    Write-Host "Trimming $trimSeconds seconds from the end..."
    Write-Host ""
    $targetDuration = $duration - $trimSeconds
    & ffmpeg -n -t $targetDuration -i $inputFile.FullName -c copy $output
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
# Wait-ForUser
