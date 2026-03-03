#=============================================================================
# FFmpeg All-In-One Script v1.0
# Integrated FFmpeg Tools: Uninstaller, Aspect Ratio Resizer, Cropper, 
# Video to GIF Converter, and Video Trimmer
#=============================================================================

Write-Host "`n`nFFmpeg All-In-One Script`n" -ForegroundColor Gray
Write-Host "Integrated Features: FFmpeg Install/Uninstall, Trim, Crop, Aspect Ratio Resizer, Video to GIF Converter`n`n" -ForegroundColor Gray

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Wait-ForUser {
    param(
        [string]$Message = 'Press Enter to continue'
    )
    Read-Host -Prompt $Message | Out-Null
}

function Get-Gcd {
    param(
        [int]$a,
        [int]$b
    )
    while ($b -ne 0) {
        $t = $b
        $b = $a % $b
        $a = $t
    }
    return [math]::Abs($a)
}

function SanitizeFileName {
    param(
        [string]$Name
    )
    if (-not $Name) { return $Name }
    $out = $Name -replace '[:\\/\?\*"<>\|]', '-'
    $out = $out -replace '\s+', '_'
    return $out
}

function ConsoleWindowMaximizer {
    $scriptPath = $PSCommandPath
    if (-not $env:FFmpeg_Maximized -and $scriptPath) {
        try {
            $env:FFmpeg_Maximized = $true
            $processArgs = @{
                FilePath = "powershell.exe"
                ArgumentList = @(
                    "-NoProfile",
                    "-ExecutionPolicy", "Bypass",
                    "-File", "`"$scriptPath`""
                )
                WindowStyle = "Maximized"
            }
            Start-Process @processArgs
            exit
        } catch { }
    }
    try {
        $pshost = Get-Host
        $pswindow = $pshost.UI.RawUI
        $maxWidth = $pswindow.MaxWindowSize.Width
        $maxHeight = $pswindow.MaxWindowSize.Height
        if ($maxWidth -gt 80 -and $maxHeight -gt 24) {
            $pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($maxWidth, $maxHeight)
            $pswindow.WindowSize = New-Object System.Management.Automation.Host.Size($maxWidth, $maxHeight)
        }
    } catch { }
}

function Get-AlternativesFromArray {
    param([array]$DisplayArray, [int]$CurrentIndex)
    $alternatives = @()
    for ($i = 0; $i -lt $DisplayArray.Count; $i++) {
        if ($i -ne $CurrentIndex) {
            $alternatives += $DisplayArray[$i]
        }
    }
    return $alternatives
}

function Show-ParameterOptions {
    param(
        [string]$ParameterName,
        [array]$OptionsArray,
        [array]$DisplayArray,
        [int]$CurrentIndex
    )
    Write-Host "  $ParameterName`: " -ForegroundColor White -NoNewline
    if ($CurrentIndex -ge 0) {
        Write-Host $DisplayArray[$CurrentIndex] -ForegroundColor Green -NoNewline
        if ($DisplayArray.Count -gt 1) {
            Write-Host " | " -ForegroundColor DarkGray -NoNewline
            $alternatives = Get-AlternativesFromArray $DisplayArray $CurrentIndex
            Write-Host ($alternatives -join " | ") -ForegroundColor DarkGray
        } else {
            Write-Host "`n"
        }
    } else {
        Write-Host $DisplayArray[0] -ForegroundColor White
    }
}

function Invoke-FFmpeg {
    param(
        [string[]]$FfmpegArgs
    )
    $cmdLine = 'FFmpeg ' + ($FfmpegArgs -join ' ')
    Write-Host "Executing: $cmdLine" -ForegroundColor DarkGray
    & FFmpeg @FfmpegArgs
    return $LASTEXITCODE
}

function Invoke-FFplay {
    param(
        [string[]]$FfplayArgs
    )
    $cmdLine = 'FFplay ' + ($FfplayArgs -join ' ')
    Write-Host "Executing: $cmdLine" -ForegroundColor DarkGray
    & FFplay @FfplayArgs
}

function Resolve-OutputFileOverwrite {
    param(
        [string]$OutputPath
    )
    if (Test-Path -Path $OutputPath) {
        while ($true) {
            Write-Host ""
            Write-Host "WARNING: Output file already exists:" -ForegroundColor Yellow
            Write-Host "$OutputPath" -ForegroundColor Yellow
            Write-Host ""
            $ans = Read-Host -Prompt "Overwrite? (y/n)"
            if ($ans -match '^[Yy]$') {
                return '-y'
            } elseif ($ans -match '^[Nn]$') {
                Write-Host ""
                Write-Host "Operation canceled by user." -ForegroundColor Yellow
                return $null
            } else {
                Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Yellow
            }
        }
    } else {
        return '-n'
    }
}

# ============================================================================
# MAIN MENU
# ============================================================================

ConsoleWindowMaximizer

while ($true) {
    # Check FFmpeg existence at startup
    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "WARNING: FFmpeg not found." -ForegroundColor Yellow
        Write-Host "Please run option [4] to install FFmpeg first." -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                  FFmpeg AIO - Main Menu" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[0] Video Trimmer (Length)" -ForegroundColor Yellow
    Write-Host "[1] Video Cropper (Dimensions)" -ForegroundColor Yellow
    Write-Host "[2] Video to GIF Converter" -ForegroundColor Yellow
    Write-Host "[3] Video Aspect Ratio Resizer" -ForegroundColor Yellow
    Write-Host "[4] FFmpeg Manager (Install/Uninstall)" -ForegroundColor Yellow
    Write-Host "[5] Exit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $toolChoice = Read-Host -Prompt "`n`nSelect a workflow (0-5)"
    
    switch ($toolChoice) {
        "0" {
            Invoke-VideoTrimmer
        }
        "1" {
            Invoke-VideoCropper
        }
        "2" {
            Invoke-VideoToGifConverter
        }
        "3" {
            Invoke-VideoAspectRatioResizer
        }
        "4" {
            Invoke-FFmpegManager
        }
        "5" {
            Write-Host ""
            Write-Host "Exiting FFmpeg AIO Script..." -ForegroundColor Green
            Write-Host ""
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Invalid selection. Please enter a number between 0 and 5." -ForegroundColor Red
            Write-Host ""
        }
    }
}

# ============================================================================
# TOOL: FFmpeg Manager (Install/Uninstall)
# ============================================================================

function Invoke-FFmpegManager {
    Write-Host ""
    Write-Host "FFmpeg Manager" -ForegroundColor Cyan
    Write-Host ""
    
    $managerChoice = Read-Host -Prompt "Install (i) or Uninstall (u) FFmpeg?"
    
    if ($managerChoice -match '^[Ii]$') {
        Install-FFmpeg
    } elseif ($managerChoice -match '^[Uu]$') {
        Uninstall-FFmpeg
    } else {
        Write-Host ""
        Write-Host "Invalid choice." -ForegroundColor Red
        Write-Host ""
    }
}

function Install-FFmpeg {
    Write-Host ""
    Write-Host "Attempting to install FFmpeg..." -ForegroundColor Cyan
    $installExit = 1

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $proc = Start-Process -FilePath 'winget' -ArgumentList 'install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements' -Wait -NoNewWindow -PassThru
        $installExit = $proc.ExitCode
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        $proc = Start-Process -FilePath 'choco' -ArgumentList 'install FFmpeg -y' -Wait -NoNewWindow -PassThru
        $installExit = $proc.ExitCode
    } else {
        Write-Host "No supported package manager found (winget or choco). Please install FFmpeg manually." -ForegroundColor Yellow
        Wait-ForUser
        return
    }

    if ($installExit -ne 0) {
        Write-Host "Installation failed (exit code $installExit). Please install FFmpeg manually." -ForegroundColor Red
        Wait-ForUser
        return
    }

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
        Write-Host "WARNING: Could not refresh PATH automatically. Please run the script again or manually add FFmpeg to PATH." -ForegroundColor Yellow
    }

    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "FFmpeg still not found after installation. You may need to restart your shell or manually add FFmpeg to PATH." -ForegroundColor Yellow
        Wait-ForUser
        return
    } else {
        Write-Host ""
        Write-Host "FFmpeg installed successfully." -ForegroundColor Green
        Write-Host ""
    }
}

function Uninstall-FFmpeg {
    Write-Host ""
    Write-Host "Uninstalling FFmpeg..." -ForegroundColor Cyan
    Write-Host ""
    
    winget uninstall --id Gyan.FFmpeg
    
    Write-Host ""
    Wait-ForUser
}

# ============================================================================
# TOOL: Video Trimmer
# ============================================================================

function Invoke-VideoTrimmer {
    Write-Host ""
    Write-Host "Video Trimmer" -ForegroundColor Cyan
    Write-Host ""
    
    # Check FFmpeg
    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: FFmpeg was not found." -ForegroundColor Red
        $install = Read-Host -Prompt "Install FFmpeg now? (y/n)"
        if ($install -match '^[Yy]$') {
            Install-FFmpeg
            if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "FFmpeg installation failed. Cannot continue." -ForegroundColor Red
                Wait-ForUser
                return
            }
        } else {
            Write-Host "FFmpeg is required. Exiting..." -ForegroundColor Yellow
            Wait-ForUser
            return
        }
    }
    
    # Find input file
    $sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
        @('.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob') -contains $_.Extension.ToLower()
    }
    
    if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
        Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
        Write-Host ""
        Wait-ForUser
        return
    }
    if ($sourceMatches.Count -gt 1) {
        Write-Host "WARNING: Multiple video files found. Using the first one." -ForegroundColor Yellow
        Write-Host ""
    }
    
    $inputFile = $sourceMatches[0]
    $inputPath = [string]$inputFile.FullName
    
    # Get duration
    $durationRaw = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputPath
    $duration = [double]$durationRaw
    
    # Trim method
    Write-Host "Select trim method:" -ForegroundColor Cyan
    Write-Host "[0] Fast (stream copy, no re-encoding)"
    Write-Host "[1] Re-encode (frame-accurate)"
    Write-Host ""
    
    $trimMethod = $null
    while (-not $trimMethod) {
        $methodChoice = Read-Host -Prompt "Enter choice (0-1)"
        if ($methodChoice -in @('0','1')) {
            $trimMethod = $methodChoice
        } else {
            Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
        }
    }
    
    # Trim position
    Write-Host ""
    Write-Host "Trim from where?" -ForegroundColor Cyan
    Write-Host "[0] Beginning"
    Write-Host "[1] End"
    Write-Host "[2] Both"
    Write-Host ""
    
    $trimChoice = $null
    while (-not $trimChoice) {
        $choice = Read-Host -Prompt "Enter choice (0-2)"
        if ($choice -in @('0','1','2')) {
            $trimChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter 0, 1, or 2." -ForegroundColor Yellow
        }
    }
    
    # Get trim seconds
    $trimSecondsStart = 0
    $trimSecondsEnd = 0
    
    Write-Host ""
    Write-Host "Current video duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Green
    Write-Host ""
    
    if ($trimChoice -eq '0' -or $trimChoice -eq '1') {
        $trimSeconds = $null
        while (-not $trimSeconds) {
            $secondsInput = Read-Host -Prompt "Enter number of seconds to trim (e.g., 5)"
            if ($secondsInput -match '^[1-9][0-9]*$') {
                $trimSeconds = [int]$secondsInput
            }
        }
        
        while ($trimSeconds -ge $duration) {
            Write-Host "ERROR: Trim seconds must be less than video duration." -ForegroundColor Red
            $secondsInput = Read-Host -Prompt "Enter a valid number of seconds to trim"
            if ($secondsInput -match '^[1-9][0-9]*$') {
                $trimSeconds = [int]$secondsInput
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
        while ($null -eq $trimSecondsStart) {
            $startInput = Read-Host -Prompt "Enter seconds to trim from beginning (e.g., 5)"
            if ($startInput -match '^[0-9]+$') {
                $trimSecondsStart = [int]$startInput
            }
        }
        while ($null -eq $trimSecondsEnd) {
            $endInput = Read-Host -Prompt "Enter seconds to trim from end (e.g., 5)"
            if ($endInput -match '^[0-9]+$') {
                $trimSecondsEnd = [int]$endInput
            }
        }
        while (($trimSecondsStart + $trimSecondsEnd) -ge $duration) {
            Write-Host "ERROR: Sum of trim seconds must be less than video duration." -ForegroundColor Red
            $trimSecondsStart = $null
            $trimSecondsEnd = $null
            while ($null -eq $trimSecondsStart) {
                $startInput = Read-Host -Prompt "Enter seconds to trim from beginning"
                if ($startInput -match '^[0-9]+$') {
                    $trimSecondsStart = [int]$startInput
                }
            }
            while ($null -eq $trimSecondsEnd) {
                $endInput = Read-Host -Prompt "Enter seconds to trim from end"
                if ($endInput -match '^[0-9]+$') {
                    $trimSecondsEnd = [int]$endInput
                }
            }
        }
    }
    
    $trimLabel = if ($trimChoice -eq '0') { 'beginning' } elseif ($trimChoice -eq '1') { 'end' } else { 'both' }
    $methodLabel = if ($trimMethod -eq '0') { 'fast' } else { 're-encode' }
    
    $outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_VideoTrimmer")
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory | Out-Null
    }
    
    Write-Host ""
    Write-Host "Trimming video..." -ForegroundColor Cyan
    
    if ($trimChoice -eq '0') {
        $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsStart}_${methodLabel}$($inputFile.Extension)"
        $output = Join-Path -Path $outputDir -ChildPath $filename
        $overwriteSwitch = Resolve-OutputFileOverwrite -OutputPath $output
        if ($null -eq $overwriteSwitch) { Wait-ForUser; return }
        Write-Host ""
        if ($trimMethod -eq '0') {
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-c', 'copy', $output)
        } else {
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-c:v', 'libx264', '-c:a', 'aac', $output)
        }
        $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    } elseif ($trimChoice -eq '1') {
        $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsEnd}_${methodLabel}$($inputFile.Extension)"
        $output = Join-Path -Path $outputDir -ChildPath $filename
        $targetDuration = $duration - $trimSecondsEnd
        $overwriteSwitch = Resolve-OutputFileOverwrite -OutputPath $output
        if ($null -eq $overwriteSwitch) { Wait-ForUser; return }
        Write-Host ""
        if ($trimMethod -eq '0') {
            $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-t', $targetDuration, '-c', 'copy', $output)
        } else {
            $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-t', $targetDuration, '-c:v', 'libx264', '-c:a', 'aac', $output)
        }
        $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    } else {
        $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsStart}start_${trimSecondsEnd}end_${methodLabel}$($inputFile.Extension)"
        $output = Join-Path -Path $outputDir -ChildPath $filename
        $targetDuration = $duration - $trimSecondsStart - $trimSecondsEnd
        $overwriteSwitch = Resolve-OutputFileOverwrite -OutputPath $output
        if ($null -eq $overwriteSwitch) { Wait-ForUser; return }
        Write-Host ""
        if ($trimMethod -eq '0') {
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-t', $targetDuration, '-c', 'copy', $output)
        } else {
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-t', $targetDuration, '-c:v', 'libx264', '-c:a', 'aac', $output)
        }
        $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Output created: $output" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "ERROR: Trim failed." -ForegroundColor Red
        Write-Host ""
    }
    
    Wait-ForUser
}

# ============================================================================
# TOOL: Video Cropper
# ============================================================================

function Invoke-VideoCropper {
    Write-Host ""
    Write-Host "Video Cropper" -ForegroundColor Cyan
    Write-Host ""
    
    # Check FFmpeg
    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: FFmpeg was not found." -ForegroundColor Red
        $install = Read-Host -Prompt "Install FFmpeg now? (y/n)"
        if ($install -match '^[Yy]$') {
            Install-FFmpeg
            if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "FFmpeg installation failed. Cannot continue." -ForegroundColor Red
                Wait-ForUser
                return
            }
        } else {
            Write-Host "FFmpeg is required. Exiting..." -ForegroundColor Yellow
            Wait-ForUser
            return
        }
    }
    
    # Find input file
    $sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
        @('.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob', '.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp') -contains $_.Extension.ToLower()
    }
    
    if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
        Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
        Write-Host ""
        Wait-ForUser
        return
    }
    if ($sourceMatches.Count -gt 1) {
        Write-Host "WARNING: Multiple files found. Using the first one." -ForegroundColor Yellow
        Write-Host ""
    }
    
    $inputFile = $sourceMatches[0]
    $inputPath = [string]$inputFile.FullName
    
    Write-Host "Input file: $($inputFile.Name)" -ForegroundColor Cyan
    Write-Host ""
    
    # Predefined crops
    $crops = @{
        '0' = @{ Label='AUTO - Centered'; Width='ih'; Height='ih'; X='(iw-ih)/2'; Y='0' }
        '1' = @{ Label='Centered 640x480'; Width=640; Height=480; X='(iw-640)/2'; Y='(ih-480)/2' }
        '2' = @{ Label='Wide 16:9'; Width='iw'; Height='iw*9/16'; X='0'; Y='(ih-ih*9/16)/2' }
        '3' = @{ Label='Vertical 9:16'; Width='ih*9/16'; Height='ih'; X='(iw-iw*9/16)/2'; Y='0' }
        '4' = @{ Label='Square 1:1'; Width='min(iw,ih)'; Height='min(iw,ih)'; X='(iw-min(iw,ih))/2'; Y='(ih-min(iw,ih))/2' }
        '5' = @{ Label='Classic 4:3'; Width='iw'; Height='iw*3/4'; X='0'; Y='(ih-iw*3/4)/2' }
        '6' = @{ Label='Social 4:5'; Width='iw'; Height='iw*5/4'; X='0'; Y='(ih-iw*5/4)/2' }
        '7' = @{ Label='Cinema 21:9'; Width='ih*21/9'; Height='ih'; X='(iw-ih*21/9)/2'; Y='0' }
        '8' = @{ Label='Custom'; Custom=$true }
    }
    
    Write-Host "Select crop preset:" -ForegroundColor Cyan
    foreach ($k in $crops.Keys | Sort-Object { [int]$_ }) {
        $c = $crops[$k]
        Write-Host "[$k] $($c.Label)"
    }
    
    Write-Host ""
    $cropChoice = $null
    while (-not $cropChoice) {
        $choice = Read-Host -Prompt "Enter crop choice (0-8)"
        if ($choice -in $crops.Keys) {
            $cropChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter a number between 0 and 8." -ForegroundColor Yellow
        }
    }
    
    $selectedCrop = $crops[$cropChoice]
    
    if ($selectedCrop.Custom) {
        Write-Host ""
        Write-Host "Enter custom crop parameters:" -ForegroundColor Cyan
        $w = Read-Host -Prompt "Width (e.g., 640 or iw)"
        $h = Read-Host -Prompt "Height (e.g., 480 or ih)"
        $x = Read-Host -Prompt "X offset (e.g., 0 or (iw-w)/2)"
        $y = Read-Host -Prompt "Y offset (e.g., 0 or (ih-h)/2)"
        $selectedCrop = @{ Label='Custom'; Width=$w; Height=$h; X=$x; Y=$y }
    }
    
    Write-Host ""
    Write-Host "Selected: $($selectedCrop.Label)" -ForegroundColor Green
    Write-Host ""
    
    # Codec selection
    Write-Host "Select output codec:" -ForegroundColor Cyan
    Write-Host "[0] H.264 (libx264)"
    Write-Host "[1] H.265 (libx265)"
    Write-Host "[2] VP9 (libvpx-vp9)"
    Write-Host "[3] Copy (no re-encoding)"
    Write-Host ""
    
    $codecChoice = $null
    while (-not $codecChoice) {
        $choice = Read-Host -Prompt "Enter choice (0-3)"
        if ($choice -in @('0', '1', '2', '3')) {
            $codecChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter 0, 1, 2, or 3." -ForegroundColor Yellow
        }
    }
    
    $outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_VideoCropper")
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory | Out-Null
    }
    
    $label = SanitizeFileName -Name "crop$cropChoice-$($selectedCrop.Label)"
    $filename = "$($inputFile.BaseName)_cropped_$label$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    
    $overwriteSwitch = Resolve-OutputFileOverwrite -OutputPath $output
    if ($null -eq $overwriteSwitch) { Wait-ForUser; return }
    
    Write-Host ""
    Write-Host "Cropping..." -ForegroundColor Cyan
    Write-Host ""
    
    $w = $selectedCrop.Width
    $h = $selectedCrop.Height
    $x = if ([string]::IsNullOrWhiteSpace($selectedCrop.X)) { 0 } else { $selectedCrop.X }
    $y = if ([string]::IsNullOrWhiteSpace($selectedCrop.Y)) { 0 } else { $selectedCrop.Y }
    $cropFilter = "crop=$w`:$h`:$x`:$y"
    
    $ffArgs = @($overwriteSwitch, '-i', $inputPath)
    switch ($codecChoice) {
        '0' { $ffArgs += @('-vf', $cropFilter, '-c:v', 'libx264', '-crf', '23', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output) }
        '1' { $ffArgs += @('-vf', $cropFilter, '-c:v', 'libx265', '-crf', '23', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output) }
        '2' { $ffArgs += @('-vf', $cropFilter, '-c:v', 'libvpx-vp9', '-crf', '23', '-b:v', '0', '-c:a', 'libopus', '-b:a', '128k', $output) }
        '3' { $ffArgs += @('-vf', $cropFilter, '-c', 'copy', $output) }
    }
    
    $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Output created: $output" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "ERROR: Crop failed." -ForegroundColor Red
        Write-Host ""
    }
    
    Wait-ForUser
}

# ============================================================================
# TOOL: Video to GIF Converter
# ============================================================================

function Invoke-VideoToGifConverter {
    Write-Host ""
    Write-Host "Video to GIF Converter" -ForegroundColor Cyan
    Write-Host ""
    
    # Check FFmpeg
    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: FFmpeg was not found." -ForegroundColor Red
        $install = Read-Host -Prompt "Install FFmpeg now? (y/n)"
        if ($install -match '^[Yy]$') {
            Install-FFmpeg
            if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "FFmpeg installation failed. Cannot continue." -ForegroundColor Red
                Wait-ForUser
                return
            }
        } else {
            Write-Host "FFmpeg is required. Exiting..." -ForegroundColor Yellow
            Wait-ForUser
            return
        }
    }
    
    # Find input file
    $sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
        @('.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob') -contains $_.Extension.ToLower()
    }
    
    if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
        Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
        Write-Host ""
        Wait-ForUser
        return
    }
    if ($sourceMatches.Count -gt 1) {
        Write-Host "WARNING: Multiple video files found. Using the first one." -ForegroundColor Yellow
        Write-Host ""
    }
    
    $inputFile = $sourceMatches[0]
    $inputPath = [string]$inputFile.FullName
    
    $outputFolder = Join-Path -Path $inputFile.DirectoryName -ChildPath "$($inputFile.BaseName)_VideoToGifConverter"
    
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
        @{ Label = '1920px width'; Value = '1920:-1' }
    )
    
    Write-Host "Select scaling option:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $scaleOptions.Count; $i++) {
        Write-Host "[$i] $($scaleOptions[$i].Label)"
    }
    
    Write-Host ""
    $selectedScale = $null
    while (-not $selectedScale) {
        $choice = Read-Host -Prompt "Enter choice (0-$($scaleOptions.Count - 1)) [default: 3]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $selectedScale = $scaleOptions[3].Value
        } elseif ($choice -match '^[0-9]+$') {
            $index = [int]$choice
            if ($index -ge 0 -and $index -lt $scaleOptions.Count) {
                $selectedScale = $scaleOptions[$index].Value
            } else {
                Write-Host "Invalid input. Please enter a number between 0 and $($scaleOptions.Count - 1)." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Invalid input. Please enter a number or press Enter for default." -ForegroundColor Yellow
        }
    }
    
    $scaleSuffix = ($selectedScale -split ':')[0]
    $palette = Join-Path $outputFolder "$($inputFile.BaseName).png"
    $output = Join-Path $outputFolder "$($inputFile.BaseName)_${scaleSuffix}.gif"
    
    # Create output folder
    if (-not (Test-Path $outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
        Write-Host ""
        Write-Host "Created output folder: $outputFolder" -ForegroundColor Green
    }
    
    $overwriteSwitch = Resolve-OutputFileOverwrite -OutputPath $output
    if ($null -eq $overwriteSwitch) { Wait-ForUser; return }
    
    Write-Host ""
    Write-Host "Generating palette..." -ForegroundColor Cyan
    $ffArgs = @($overwriteSwitch, '-i', $inputFile.FullName, '-vf', "fps=15,scale=${selectedScale}:flags=lanczos,palettegen", $palette)
    $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    
    if ($rc -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Failed to generate palette." -ForegroundColor Red
        Wait-ForUser
        return
    }
    
    Write-Host ""
    Write-Host "Generating GIF..." -ForegroundColor Cyan
    $ffArgs = @($overwriteSwitch, '-i', $inputFile.FullName, '-i', $palette, '-filter_complex', "fps=15,scale=${selectedScale}:flags=lanczos[x];[x][1:v]paletteuse", '-loop', '0', $output)
    $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    
    if ($rc -eq 0) {
        Write-Host ""
        Write-Host "Output created: $output" -ForegroundColor Green
        Write-Host ""
        Remove-Item -Force $palette -ErrorAction SilentlyContinue
    } else {
        Write-Host ""
        Write-Host "ERROR: GIF generation failed." -ForegroundColor Red
        Write-Host ""
    }
    
    Wait-ForUser
}

# ============================================================================
# TOOL: Video Aspect Ratio Resizer
# ============================================================================

function Invoke-VideoAspectRatioResizer {
    Write-Host ""
    Write-Host "Video Aspect Ratio Resizer" -ForegroundColor Cyan
    Write-Host ""
    
    # Check FFmpeg
    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: FFmpeg was not found." -ForegroundColor Red
        $install = Read-Host -Prompt "Install FFmpeg now? (y/n)"
        if ($install -match '^[Yy]$') {
            Install-FFmpeg
            if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "FFmpeg installation failed. Cannot continue." -ForegroundColor Red
                Wait-ForUser
                return
            }
        } else {
            Write-Host "FFmpeg is required. Exiting..." -ForegroundColor Yellow
            Wait-ForUser
            return
        }
    }
    
    # Find input file
    $sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
        @('.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob') -contains $_.Extension.ToLower()
    }
    
    if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
        Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
        Write-Host ""
        Wait-ForUser
        return
    }
    if ($sourceMatches.Count -gt 1) {
        Write-Host "WARNING: Multiple video files found. Using the first one." -ForegroundColor Yellow
        Write-Host ""
    }
    
    $inputFile = $sourceMatches[0]
    $inputPath = [string]$inputFile.FullName
    
    # Get video info
    $probeJson = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of json $inputPath
    $videoInfo = $probeJson | ConvertFrom-Json
    
    if ($videoInfo.streams -and $videoInfo.streams.Count -gt 0) {
        $width = $videoInfo.streams[0].width
        $height = $videoInfo.streams[0].height
    } else {
        Write-Host "ERROR: Could not get video dimensions." -ForegroundColor Red
        Wait-ForUser
        return
    }
    
    $g = Get-Gcd -a $width -b $height
    $ratioW = [int]($width / $g)
    $ratioH = [int]($height / $g)
    
    Write-Host "Current resolution: ${width}x${height} (Aspect ratio: $ratioW`:$ratioH)" -ForegroundColor Green
    Write-Host ""
    
    # Format selection
    $formats = @{
        '0' = @{ Label='Vertical 9:16'; W=9; H=16 }
        '1' = @{ Label='Portrait 2:3'; W=2; H=3 }
        '2' = @{ Label='Social 4:5'; W=4; H=5 }
        '3' = @{ Label='Square 1:1'; W=1; H=1 }
        '4' = @{ Label='Classic 4:3'; W=4; H=3 }
        '5' = @{ Label='Classic 3:2'; W=3; H=2 }
        '6' = @{ Label='Wide 16:9'; W=16; H=9 }
        '7' = @{ Label='Cinema 21:9'; W=21; H=9 }
    }
    
    Write-Host "Select target aspect ratio:" -ForegroundColor Cyan
    foreach ($k in $formats.Keys | Sort-Object) {
        $f = $formats[$k]
        Write-Host "[$k] $($f.Label)"
    }
    
    Write-Host ""
    $targetChoice = $null
    while (-not $targetChoice) {
        $choice = Read-Host -Prompt "Enter choice (0-7)"
        if ($choice -in $formats.Keys) {
            $targetChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter a number between 0 and 7." -ForegroundColor Yellow
        }
    }
    
    $target = $formats[$targetChoice]
    $tw = $target.W
    $th = $target.H
    
    Write-Host ""
    Write-Host "Selected: $($target.Label)" -ForegroundColor Green
    Write-Host ""
    
    # Check if same aspect ratio
    $g2 = Get-Gcd -a $tw -b $th
    $rtw = [int]($tw / $g2)
    $rth = [int]($th / $g2)
    
    if ($rtw -eq $ratioW -and $rth -eq $ratioH) {
        Write-Host "Selected format has the same aspect ratio as current video." -ForegroundColor Yellow
        Write-Host "No conversion needed." -ForegroundColor Yellow
        Write-Host ""
        Wait-ForUser
        return
    }
    
    # Output directory
    $outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_VideoAspectRatioResizer")
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory | Out-Null
    }
    
    Write-Host "Re-encoding to target aspect ratio..." -ForegroundColor Cyan
    Write-Host ""
    
    # Compute output dimensions
    if ($tw -gt $th) {
        $outW = [int]([math]::Round([double]([math]::Max($width, $height))))
        $outH = [int]([math]::Round($outW * ($th / $tw)))
    } else {
        $outH = [int]([math]::Round([double]([math]::Max($width, $height))))
        $outW = [int]([math]::Round($outH * ($tw / $th)))
    }
    
    if ($outW -lt 2) { $outW = 2 }
    if ($outH -lt 2) { $outH = 2 }
    
    $label = SanitizeFileName -Name "$($target.Label)_re-encode_${outW}x${outH}"
    $filename = "$($inputFile.BaseName)_$label$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    
    $overwriteSwitch = Resolve-OutputFileOverwrite -OutputPath $output
    if ($null -eq $overwriteSwitch) { Wait-ForUser; return }
    
    $aspectExpr = "{0}/{1}" -f $tw, $th
    $vf = "scale='if(gt(a,{0}),{1},-2)':'if(gt(a,{0}),-2,{2})',pad={1}:{2}:(ow-iw)/2:(oh-ih)/2,setsar=1" -f $aspectExpr, $outW, $outH
    
    $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-vf', $vf, '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output)
    $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    
    if ($rc -eq 0) {
        Write-Host ""
        Write-Host "Output created: $output" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "ERROR: Aspect ratio resizing failed." -ForegroundColor Red
        Write-Host ""
    }
    
    Wait-ForUser
}
