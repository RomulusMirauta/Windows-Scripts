param(
    [switch]$AutoDetect,
    [switch]$Preview,
    [string]$CustomWidth,
    [string]$CustomHeight,
    [string]$CustomX,
    [string]$CustomY
)

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

# Replace or remove characters that are invalid in Windows filenames
function SanitizeFileName {
    param(
        [string]$Name
    )
    if (-not $Name) { return $Name }
    # replace forbidden characters with hyphen, collapse whitespace to single underscore
    $out = $Name -replace '[:\\/\?\*"<>\|]', '-'
    $out = $out -replace '\s+', '_'
    return $out
}

# Helper to run FFmpeg with an argument array and show the full command for debugging
function Invoke-FFmpeg {
    param(
        [string[]]$FfmpegArgs
    )
    $cmdLine = 'FFmpeg ' + ($FfmpegArgs -join ' ')
    Write-Host "Executing: $cmdLine" -ForegroundColor DarkGray
    & FFmpeg @FfmpegArgs
    return $LASTEXITCODE
}

# Helper to run FFplay with arguments for preview
function Invoke-FFplay {
    param(
        [string[]]$FfplayArgs
    )
    $cmdLine = 'FFplay ' + ($FfplayArgs -join ' ')
    Write-Host "Executing: $cmdLine" -ForegroundColor DarkGray
    & FFplay @FfplayArgs
}

Write-Host "Video Cropper (with auto-detect and preview)" -ForegroundColor Gray
Write-Host ""

# Ensure FFmpeg exists
if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR: FFmpeg was not found." -ForegroundColor Red
    Write-Host ""

    while ($true) {
        $choice = Read-Host -Prompt "Install FFmpeg now? (y/n)"
        if ($choice -match '^[Yy]$') {
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
                exit 1
            }

            if ($installExit -ne 0) {
                Write-Host "Installation failed (exit code $installExit). Please install FFmpeg manually." -ForegroundColor Red
                Wait-ForUser
                exit 1
            }

            # Refresh PATH in this session
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
                exit 1
            } else {
                Write-Host ""
                Write-Host "FFmpeg installed successfully." -ForegroundColor Green
                break
            }
        } elseif ($choice -match '^[Nn]$') {
            Write-Host ""
            Write-Host "FFmpeg installation is mandatory. Exiting the script..." -ForegroundColor Yellow
            Wait-ForUser
            exit 1
        } else {
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ""
    Write-Host "FFmpeg found, continuing script..." -ForegroundColor Green
    Write-Host ""
}

if (-not (Get-Command FFprobe -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: FFprobe was not found in PATH. Please re-install FFmpeg (which includes FFprobe) or manually add FFprobe to PATH." -ForegroundColor Red
    Wait-ForUser
    exit 1
}

# Check for FFplay (optional, for preview feature)
$hasFFplay = $false
if (Get-Command FFplay -ErrorAction SilentlyContinue) {
    $hasFFplay = $true
}

# Supported video/image file extensions (case-insensitive)
$supportedExtensions = @(
    '.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob',
    '.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'
)

# Find media files in current directory
$sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
    $supportedExtensions -contains $_.Extension.ToLower()
}

if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
    Write-Host "`nWARNING: No video or image files found in the current folder." -ForegroundColor Yellow
    Write-Host "Supported file extensions: $($supportedExtensions -join ', ')"
    Write-Host ""
    Wait-ForUser
    exit 1
}
if ($sourceMatches.Count -gt 1) {
    Write-Host "`nWARNING: Multiple media files found in the current folder." -ForegroundColor Yellow
    Write-Host "Please keep only one media file and run the script again." -ForegroundColor Yellow
    Write-Host ""
    Wait-ForUser
    exit 1
}

$inputFile = $sourceMatches[0]
$inputPath = [string]$inputFile.FullName

# Get input resolution
$probe = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x $inputPath
if (-not $probe) {
    Write-Host "ERROR: Could not read video/image stream information from input file." -ForegroundColor Red
    Wait-ForUser
    exit 1
}
$parts = $probe -split 'x'
$width = [int]$parts[0]
$height = [int]$parts[1]

Write-Host "`nInput file: $($inputFile.Name)" -ForegroundColor Cyan
Write-Host "Resolution: $width x $height" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# PREDEFINED CROPS
# ============================================================================
$crops = @{
    '0' = @{ 
        Label='Centered Crop 640x480'; 
        Desc='Fixed output';
        Width=640; Height=480; X='(iw-640)/2'; Y='(ih-480)/2'
    }
    '1' = @{ 
        Label='AUTO-CROPPER - Centered Crop'; 
        Desc='Variable output, uses smallest dimension';
        Width='ih'; Height='ih'; X='(iw-ih)/2'; Y='0'
    }
    '2' = @{ 
        Label='Remove 100px Borders'; 
        Desc='Crop 100px from all sides';
        Width='iw-200'; Height='ih-200'; X='100'; Y='100'
    }
    '3' = @{ 
        Label='Wide 16:9'; 
        Desc='YouTube and streaming sites';
        Width='iw'; Height='iw*9/16'; X='0'; Y='(ih-ih*9/16)/2'
    }
    '4' = @{ 
        Label='Vertical 9:16'; 
        Desc='Instagram Reels and TikTok';
        Width='ih*9/16'; Height='ih'; X='(iw-iw*9/16)/2'; Y='0'
    }
    '5' = @{ 
        Label='Square 1:1'; 
        Desc='Instagram posts';
        Width='min(iw,ih)'; Height='min(iw,ih)'; X='(iw-min(iw,ih))/2'; Y='(ih-min(iw,ih))/2'
    }
    '6' = @{ 
        Label='Classic 4:3'; 
        Desc='Standard TV format';
        Width='iw'; Height='iw*3/4'; X='0'; Y='(ih-iw*3/4)/2'
    }
    '7' = @{ 
        Label='Social 4:5'; 
        Desc='Instagram Stories and Mobile';
        Width='iw'; Height='iw*5/4'; X='0'; Y='(ih-iw*5/4)/2'
    }
    '8' = @{ 
        Label='Cinema 21:9'; 
        Desc='Ultra-wide cinema format';
        Width='ih*21/9'; Height='ih'; X='(iw-ih*21/9)/2'; Y='0'
    }
    '9' = @{ 
        Label='Portrait 2:3'; 
        Desc='Portrait orientation';
        Width='ih*2/3'; Height='ih'; X='(iw-ih*2/3)/2'; Y='0'
    }
    '10' = @{ 
        Label='Horizontal 3:2'; 
        Desc='Classic landscape ratio';
        Width='iw'; Height='iw*2/3'; X='0'; Y='(ih-iw*2/3)/2'
    }
    '11' = @{ 
        Label='Custom'; 
        Desc='Define custom crop parameters';
        Custom=$true
    }
}

Write-Host "Select crop preset:" -ForegroundColor Cyan
foreach ($k in $crops.Keys | Sort-Object { [int]$_ }) {
    $c = $crops[$k]
    if ($c.Desc) {
        $line = "[$k] $($c.Label) ($($c.Desc))"
    } else {
        $line = "[$k] $($c.Label)"
    }
    Write-Host $line
}

$cropChoice = $null
$selectedCrop = $null

while (-not $cropChoice) {
    $choice = Read-Host -Prompt "`nEnter crop choice (0-11)"
    if ($choice -in $crops.Keys) {
        $cropChoice = $choice
        $selectedCrop = $crops[$choice]
    } else {
        Write-Host "Invalid input. Please enter a number between 0 and 11." -ForegroundColor Yellow
    }
}

Write-Host ""

# ============================================================================
# HANDLE CUSTOM CROP
# ============================================================================
if ($selectedCrop.Custom) {
    Write-Host "Enter custom crop parameters:" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Width (crop width in pixels or expression):" -ForegroundColor Yellow
    Write-Host "  Examples: 640, iw, iw-100, iw*2/3" -ForegroundColor DarkGray
    $w = Read-Host -Prompt "Width"
    
    Write-Host ""
    Write-Host "Height (crop height in pixels or expression):" -ForegroundColor Yellow
    Write-Host "  Examples: 480, ih, ih-100, ih*9/16" -ForegroundColor DarkGray
    $h = Read-Host -Prompt "Height"
    
    Write-Host ""
    Write-Host "Horizontal Offset X (pixels from left, or expression):" -ForegroundColor Yellow
    Write-Host "  Examples: 0, 100, (iw-w)/2 (center horizontally)" -ForegroundColor DarkGray
    $x = Read-Host -Prompt "X offset"
    
    Write-Host ""
    Write-Host "Vertical Offset Y (pixels from top, or expression):" -ForegroundColor Yellow
    Write-Host "  Examples: 0, 100, (ih-h)/2 (center vertically)" -ForegroundColor DarkGray
    $y = Read-Host -Prompt "Y offset"
    
    $selectedCrop = @{
        Label='Custom Crop';
        Width=$w;
        Height=$h;
        X=$x;
        Y=$y
    }
    
    Write-Host ""
} else {
    Write-Host "Selected: $($selectedCrop.Label)" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# AUTO-DETECT OPTION (using cropdetect filter)
# ============================================================================
$useAutoDetect = $false
if ($selectedCrop.Label -ne 'Custom Crop') {
    Write-Host "Would you like to use auto-detection to find black bars?" -ForegroundColor Cyan
    Write-Host "[0] No, use selected crop" -ForegroundColor Gray
    Write-Host "[1] Yes, auto-detect crop parameters" -ForegroundColor Gray
    
    $autoChoice = $null
    while (-not $autoChoice) {
        $choice = Read-Host -Prompt "`nEnter choice (0-1)"
        if ($choice -in @('0', '1')) {
            $autoChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
        }
    }
    
    if ($autoChoice -eq '1') {
        Write-Host ""
        Write-Host "Running cropdetect filter to find black bars..." -ForegroundColor Cyan
        Write-Host ""
        
        # Run cropdetect filter and capture the last crop value
        $cropdetectOutput = & ffmpeg -i $inputPath -vf cropdetect -f null - 2>&1 | Select-String -Pattern 'crop='
        
        if ($cropdetectOutput) {
            # Extract the crop value from the last match
            $lastCrop = $cropdetectOutput[-1]
            Write-Host "Detected: $lastCrop" -ForegroundColor Green
            
            # Parse the crop value: crop=w:h:x:y
            if ($lastCrop -match 'crop=(\d+):(\d+):(\d+):(\d+)') {
                $selectedCrop = @{
                    Label='Auto-Detected Crop';
                    Width=[int]$matches[1];
                    Height=[int]$matches[2];
                    X=[int]$matches[3];
                    Y=[int]$matches[4]
                }
                $useAutoDetect = $true
                Write-Host ""
            } else {
                Write-Host "WARNING: Could not parse cropdetect output. Using selected preset." -ForegroundColor Yellow
                Write-Host ""
            }
        } else {
            Write-Host "WARNING: cropdetect did not find suitable crop parameters. Using selected preset." -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

# ============================================================================
# BUILD CROP FILTER STRING
# ============================================================================
$w = $selectedCrop.Width
$h = $selectedCrop.Height
$x = $selectedCrop.X
$y = $selectedCrop.Y

# Ensure X and Y have default values if empty
if ([string]::IsNullOrWhiteSpace($x)) { $x = 0 }
if ([string]::IsNullOrWhiteSpace($y)) { $y = 0 }

if ($w -is [int] -and $h -is [int] -and $x -is [int] -and $y -is [int]) {
    $cropFilter = "crop=$w`:$h`:$x`:$y"
} else {
    $cropFilter = "crop=$w`:$h`:$x`:$y"
}

Write-Host "Crop parameters:" -ForegroundColor Cyan
Write-Host "  Width: $w" -ForegroundColor Yellow
Write-Host "  Height: $h" -ForegroundColor Yellow
Write-Host "  X offset: $x" -ForegroundColor Yellow
Write-Host "  Y offset: $y" -ForegroundColor Yellow
Write-Host "  Filter: $cropFilter" -ForegroundColor DarkGray
Write-Host ""

# ============================================================================
# PREVIEW OPTION (using ffplay)
# ============================================================================
if ($hasFFplay) {
    Write-Host "Would you like to preview the crop before processing?" -ForegroundColor Cyan
    Write-Host "[0] No, proceed to cropping" -ForegroundColor Gray
    Write-Host "[1] Yes, preview with ffplay" -ForegroundColor Gray
    
    $previewChoice = $null
    while (-not $previewChoice) {
        $choice = Read-Host -Prompt "`nEnter choice (0-1)"
        if ($choice -in @('0', '1')) {
            $previewChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
        }
    }
    
    if ($previewChoice -eq '1') {
        Write-Host ""
        Write-Host "Starting preview with ffplay (close window to continue)..." -ForegroundColor Cyan
        Write-Host ""
        $ffplayArgs = @('-vf', $cropFilter, $inputPath)
        Invoke-FFplay -FfplayArgs $ffplayArgs
        Write-Host ""
    }
}

# ============================================================================
# CODEC SELECTION
# ============================================================================
Write-Host "Select output codec:" -ForegroundColor Cyan
Write-Host "[0] H.264 (libx264) - Wide compatibility, good compression"
Write-Host "[1] H.265 (libx265) - Better compression, slower encoding"
Write-Host "[2] VP9 (libvpx-vp9) - WebM format, good quality"
Write-Host "[3] Copy (stream copy) - Fastest, no re-encoding (may lose audio sync)"

$codecChoice = $null
while (-not $codecChoice) {
    $choice = Read-Host -Prompt "`nEnter choice (0-3)"
    if ($choice -in @('0', '1', '2', '3')) {
        $codecChoice = $choice
    } else {
        Write-Host "Invalid input. Please enter 0-3." -ForegroundColor Yellow
    }
}

Write-Host ""

# ============================================================================
# PREPARE OUTPUT AND EXECUTE
# ============================================================================
$outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_VideoCropper")
if (-not (Test-Path -Path $outputDir)) { 
    New-Item -Path $outputDir -ItemType Directory | Out-Null 
}

$label = if ($useAutoDetect) { "auto-detect" } else { SanitizeFileName -Name $selectedCrop.Label }
$filename = "$($inputFile.BaseName)_cropped_$label$($inputFile.Extension)"
$output = Join-Path -Path $outputDir -ChildPath $filename

# Handle existing output file
if (Test-Path -Path $output) {
    while ($true) {
        Write-Host "WARNING: Output already exists:`n$output" -ForegroundColor Yellow
        Write-Host ""
        $ans = Read-Host -Prompt "Overwrite? (y/n)"
        if ($ans -match '^[Yy]$') {
            $overwriteSwitch = '-y'
            break
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
    $overwriteSwitch = '-n'
}

Write-Host ""
Write-Host "Cropping..." -ForegroundColor Cyan

# Build FFmpeg args based on codec choice
$ffArgs = @($overwriteSwitch, '-i', $inputPath)

switch ($codecChoice) {
    '0' {
        # H.264
        $ffArgs += @('-vf', $cropFilter, '-c:v', 'libx264', '-crf', '23', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output)
        Write-Host "Using H.264 codec (libx264)..." -ForegroundColor Cyan
    }
    '1' {
        # H.265
        $ffArgs += @('-vf', $cropFilter, '-c:v', 'libx265', '-crf', '23', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output)
        Write-Host "Using H.265 codec (libx265)..." -ForegroundColor Cyan
    }
    '2' {
        # VP9
        $ffArgs += @('-vf', $cropFilter, '-c:v', 'libvpx-vp9', '-crf', '23', '-b:v', '0', '-c:a', 'libopus', '-b:a', '128k', $output)
        Write-Host "Using VP9 codec (libvpx-vp9)..." -ForegroundColor Cyan
    }
    '3' {
        # Stream copy
        $ffArgs += @('-vf', $cropFilter, '-c', 'copy', $output)
        Write-Host "Using stream copy (no re-encoding)..." -ForegroundColor Cyan
    }
}

Write-Host "FFmpeg args: " ($ffArgs -join ' | ') -ForegroundColor DarkGray
Write-Host ""

$rc = Invoke-FFmpeg -FfmpegArgs $ffArgs

if ($rc -ne 0) {
    Write-Host "" 
    Write-Host "ERROR: Cropping failed (exit code $rc)." -ForegroundColor Red
    Write-Host ""
    Wait-ForUser
    exit 1
}

Write-Host "" 
Write-Host "Output created: $output" -ForegroundColor Green
Write-Host ""

Wait-ForUser
