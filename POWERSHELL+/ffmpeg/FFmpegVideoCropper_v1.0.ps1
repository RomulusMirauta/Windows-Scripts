# Helper function to wait for user input before continuing
param(
    [switch]$AutoDetect,
    [switch]$Preview,
    [string]$CustomWidth,
    [string]$CustomHeight,
    [string]$CustomX,
    [string]$CustomY
)


# Helper function to wait for user input before continuing
function Wait-ForUser {
    param(
        [string]$Message = 'Press Enter to continue'
    )
    Read-Host -Prompt $Message | Out-Null
}


# Helper function to calculate greatest common divisor (GCD) for aspect ratio simplification
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


# Helper function to maximize console window or expand it to available size
function ConsoleWindowMaximizer {
    # Check if we should relaunch in a new maximized window
    $scriptPath = $PSCommandPath
    
    # Only relaunch if running via context menu (detected by checking if launched from explorer context)
    # and if this is the first invocation (use environment variable to track)
    if (-not $env:FFmpeg_Maximized -and $scriptPath) {
        try {
            # Set environment variable to prevent infinite loops
            $env:FFmpeg_Maximized = $true
            
            # Relaunch script in a new maximized PowerShell window
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
        } catch {
            # If relaunch fails, continue with current window
        }
    }
    
    # If already in maximized window or relaunch failed, just try to expand current window
    try {
        $pshost = Get-Host
        $pswindow = $pshost.UI.RawUI
        
        # Try to set to max available size
        $maxWidth = $pswindow.MaxWindowSize.Width
        $maxHeight = $pswindow.MaxWindowSize.Height
        
        if ($maxWidth -gt 80 -and $maxHeight -gt 24) {
            $pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($maxWidth, $maxHeight)
            $pswindow.WindowSize = New-Object System.Management.Automation.Host.Size($maxWidth, $maxHeight)
        }
    } catch { }
}


# Resize/maximize console window
ConsoleWindowMaximizer


# Helper function to safely build alternatives array
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


# Helper function to display parameter with current value and alternatives
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


Write-Host "Video Cropper (with auto-detect and preview)`n" -ForegroundColor Gray


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



# BASE W/O INFO

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
    Write-Host "`nWARNING: No video files found in the current folder." -ForegroundColor Yellow
    Write-Host "Supported file extensions: $($videoExtensions -join ', ')`n"
    Wait-ForUser
    exit 1
}
if ($sourceMatches.Count -gt 1) {
    Write-Host "`nWARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
    Write-Host "Please keep only one video file and run the script again." -ForegroundColor Yellow
    Write-Host "`nFound files:" -ForegroundColor Cyan
    foreach ($file in $sourceMatches) {
        Write-Host "  - $($file.Name)" -ForegroundColor White
    }
    Write-Host ""
    Wait-ForUser
    exit 1
}

$inputFile = $sourceMatches[0]
$inputPath = [string]$inputFile.FullName

# Get comprehensive video information
$probeJson = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,codec_name,pix_fmt,color_space,bits_per_raw_sample,bit_rate -of json $inputPath
$probeAudio = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels,sample_rate,bit_rate -of json $inputPath
$probeDuration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputPath

$videoInfo = $probeJson | ConvertFrom-Json
$audioInfo = $probeAudio | ConvertFrom-Json

# Parse video duration
$durationSeconds = if ($probeDuration) { [int][double]$probeDuration } else { 0 }
$durationSecondsDecimal = if ($probeDuration) { [double]$probeDuration } else { 0 }
$durationHours = [math]::Floor($durationSeconds / 3600)
$durationMinutes = [math]::Floor(($durationSeconds % 3600) / 60)
$durationSecs = $durationSeconds % 60
$videoDuration = "{0:00}:{1:00}:{2:00}" -f $durationHours, $durationMinutes, $durationSecs

# Format duration in short form
$shortDuration = ""
if ($durationHours -gt 0) {
    $shortDuration = "{0}h {1}m {2}s" -f $durationHours, $durationMinutes, $durationSecs
} elseif ($durationMinutes -gt 0) {
    $shortDuration = "{0}m {1}s" -f $durationMinutes, $durationSecs
} else {
    $shortDuration = "{0:F1}s" -f $durationSecondsDecimal
}

# Extract video stream data
if ($videoInfo.streams -and $videoInfo.streams.Count -gt 0) {
    $vstream = $videoInfo.streams[0]
    $width = $vstream.width
    $height = $vstream.height
    
    # Parse frame rate from r_frame_rate (format: "30/1" or "24000/1001")
    if ($vstream.r_frame_rate) {
        $frParts = $vstream.r_frame_rate -split '/'
        if ($frParts.Count -eq 2) {
            $fps = [math]::Round([double]$frParts[0] / [double]$frParts[1], 3)
        }
    }
    
    $videoCodec = $vstream.codec_name
    $pixFormat = $vstream.pix_fmt
    $colorSpace = $vstream.color_space
    $colorDepthBits = $vstream.bits_per_raw_sample
    $colorDepth = if ($colorDepthBits) { "$colorDepthBits-bit" } else { "8-bit" }
    $videoBitrateKbps = if ($vstream.bit_rate) { 
        [int]$vstream.bit_rate / 1000
    } else { 0 }
    
    # Categorize video bitrate
    if ($videoBitrateKbps -ge 5000) {
        $videoBitrateCategory = "High"
    } elseif ($videoBitrateKbps -ge 1500) {
        $videoBitrateCategory = "Medium"
    } else {
        $videoBitrateCategory = "Low"
    }
    $videoBitrate = if ($videoBitrateKbps) { "$videoBitrateKbps kbps ($videoBitrateCategory)" } else { "Unknown" }
}

# Extract audio stream data
if ($audioInfo.streams -and $audioInfo.streams.Count -gt 0) {
    $astream = $audioInfo.streams[0]
    $audioCodec = $astream.codec_name
    $audioChannels = $astream.channels
    $audioSampleRateHz = if ($astream.sample_rate) { [int]$astream.sample_rate } else { 0 }
    
    # Categorize sample rate
    if ($audioSampleRateHz -ge 96000) {
        $audioSampleRateCategory = "High"
    } elseif ($audioSampleRateHz -ge 48000) {
        $audioSampleRateCategory = "Medium"
    } else {
        $audioSampleRateCategory = "Low"
    }
    $audioSampleRate = if ($audioSampleRateHz) { "$audioSampleRateHz Hz ($audioSampleRateCategory)" } else { "Unknown" }
    
    $audioBitrateKbps = if ($astream.bit_rate) { 
        [int]$astream.bit_rate / 1000
    } else { 0 }
    
    # Categorize audio bitrate
    if ($audioBitrateKbps -ge 320) {
        $audioBitrateCategory = "High"
    } elseif ($audioBitrateKbps -ge 128) {
        $audioBitrateCategory = "Medium"
    } else {
        $audioBitrateCategory = "Low"
    }
    $audioBitrate = if ($audioBitrateKbps) { "$audioBitrateKbps kbps ($audioBitrateCategory)" } else { "Unknown" }
}

# Get file size
$fileSizeMB = [math]::Round($inputFile.Length / 1MB, 2)

# Calculate aspect ratio
$g = Get-Gcd -a $width -b $height
$ratioW = [int]($width / $g)
$ratioH = [int]($height / $g)

# Display comprehensive video information
Write-Host "`n" -NoNewline
Write-Host "═════════════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "`nInput file: $($inputFile.Name)" -ForegroundColor Cyan

Write-Host "`nFILE INFORMATION:" -ForegroundColor Yellow

# File Size display
$fileSizeMB = [math]::Round($inputFile.Length / 1MB, 2)
Write-Host "  Size: " -ForegroundColor White -NoNewline
Write-Host "$fileSizeMB MB" -ForegroundColor Green

# File Extension display (all supported video formats, sorted by visual fidelity/resolution: low → high)
$videoExtensions = @('.3gp', '.flv', '.wmv', '.avi', '.mpeg', '.mpg', '.vob', '.ts', '.m2ts', '.mov', '.webm', '.m4v', '.mp4', '.mkv', '.ogv')

$currentExt = $inputFile.Extension.ToLower()
$extDisplay = @()
foreach ($ext in $videoExtensions) {
    if ($ext -eq $currentExt) {
        $extDisplay += $ext
    } else {
        $extDisplay += $ext
    }
}
$extIdx = [array]::IndexOf($videoExtensions, $currentExt)
Show-ParameterOptions "Format" $videoExtensions $extDisplay $extIdx

Write-Host "`nVIDEO INFORMATION:" -ForegroundColor Yellow

# Resolution display with common standards (sorted low to high)
$resolutionOptions = @("640x360", "854x480", "960x540", "1280x720", "1366x768", "1600x900", "1920x1080", "2048x1080", "2560x1440", "3840x2160", "7680x4320")
$resolutionLabels = @("360p", "480p", "540p", "720p", "768p", "900p", "1080p", "2K", "1440p", "4K", "8K")
$currentRes = "${width}x${height}"
$resDisplay = @()
for ($i = 0; $i -lt $resolutionOptions.Count; $i++) {
    if ($resolutionOptions[$i] -eq $currentRes) {
        $resDisplay += "$($resolutionLabels[$i]) - $($resolutionOptions[$i])"
    } else {
        $resDisplay += "$($resolutionLabels[$i]) - $($resolutionOptions[$i])"
    }
}
$resIdx = [array]::IndexOf($resolutionOptions, $currentRes)
Show-ParameterOptions "Resolution" $resolutionOptions $resDisplay $resIdx

Write-Host "  Duration: " -ForegroundColor White -NoNewline
Write-Host "$videoDuration ($shortDuration)" -ForegroundColor Green

# Aspect Ratio display with common options and descriptions (sorted by visual fidelity/resolution)
$aspectOptions = @("9:16", "2:3", "4:5", "1:1", "4:3", "3:2", "16:9", "21:9")
$aspectDescriptions = @(
    "Vertical 9:16 (Instagram Reels and TikTok)",
    "Portrait 2:3",
    "Social 4:5",
    "Square 1:1 (Instagram posts)",
    "Classic 4:3",
    "Classic 3:2",
    "Wide 16:9 (YouTube and streaming sites)",
    "Cinema 21:9"
)

$currentAspect = "$ratioW`:$ratioH"
$aspectDisplay = @()
for ($i = 0; $i -lt $aspectOptions.Count; $i++) {
    $label = "$($aspectDescriptions[$i])"
    if ($aspectOptions[$i] -eq $currentAspect) {
        $aspectDisplay += "$label"
    } else {
        $aspectDisplay += $label
    }
}
$aspectIdx = [array]::IndexOf($aspectOptions, $currentAspect)
Show-ParameterOptions "Aspect ratio" $aspectOptions $aspectDisplay $aspectIdx

# Frame rate display with common options
$fpsOptions = @(23.976, 24, 25, 29.97, 30, 50, 59.94, 60)
$fpsDisplay = @()
$fpsCurrentIdx = -1
$minDiff = [double]::MaxValue

# Find the closest FPS match
for ($i = 0; $i -lt $fpsOptions.Count; $i++) {
    $diff = [math]::Abs($fps - $fpsOptions[$i])
    if ($diff -lt $minDiff) {
        $minDiff = $diff
        $fpsCurrentIdx = $i
    }
}

# Build display array with only the closest match marked as current
foreach ($i in 0..($fpsOptions.Count-1)) {
    if ($i -eq $fpsCurrentIdx) {
        $fpsDisplay += "$($fpsOptions[$i]) fps"
    } else {
        $fpsDisplay += "$($fpsOptions[$i]) fps"
    }
}
Show-ParameterOptions "Frame rate" $fpsOptions $fpsDisplay $fpsCurrentIdx

# Video Codec display (sorted alphabetically by codec key)
$codecOptions = @("mpeg2video", "mpeg4", "h264", "vp9", "h265", "av1", "prores")
$codecLabels = @{
    "mpeg2video" = "MPEG-2 Video"
    "mpeg4" = "MPEG-4 Part 2"
    "h264" = "H.264 (AVC)"
    "vp9" = "VP9"
    "h265" = "H.265 (HEVC)"
    "av1" = "AV1"
    "prores" = "ProRes"
}
$codecDisplay = @()
foreach ($opt in $codecOptions) {
    $label = if ($codecLabels.ContainsKey($opt)) { $codecLabels[$opt] } else { $opt }
    if ($videoCodec -eq $opt) {
        $codecDisplay += $label
    } else {
        $codecDisplay += $label
    }
}
$codecCurrentIdx = [array]::IndexOf($codecOptions, $videoCodec)
Show-ParameterOptions "Codec" $codecOptions $codecDisplay $codecCurrentIdx

# Video Bitrate display with examples
Write-Host "  Bitrate: " -ForegroundColor White -NoNewline
$bitrateExamples = @(
    @{Kbps=400; Label="400 kbps (Low)"},
    @{Kbps=800; Label="800 kbps (Low - 360p)"},
    @{Kbps=2000; Label="2000 kbps (Medium - 480p)"},
    @{Kbps=4000; Label="4000 kbps (Medium - 720p)"},
    @{Kbps=8000; Label="8000 kbps (High - 1080p)"},
    @{Kbps=15000; Label="15000 kbps (High - 4K)"}
)
$bitrateDisplay = @()
foreach ($example in $bitrateExamples) {
    if ($videoBitrateKbps -ge ($example.Kbps - 500) -and $videoBitrateKbps -le ($example.Kbps + 500)) {
        $bitrateDisplay += "$videoBitrateKbps kbps ($videoBitrateCategory)"
        break
    }
}
if ($bitrateDisplay.Count -eq 0) {
    $bitrateDisplay = @("$videoBitrateKbps kbps ($videoBitrateCategory)")
}
foreach ($example in $bitrateExamples) {
    $bitrateDisplay += $example.Label
}
Write-Host $bitrateDisplay[0] -ForegroundColor Green -NoNewline
Write-Host " | " -ForegroundColor DarkGray -NoNewline
Write-Host ($bitrateDisplay[1..($bitrateDisplay.Count-1)] -join " | ") -ForegroundColor DarkGray

# Pixel Format display (sorted by visual fidelity/resolution: low → high)
$pixOptions = @("yuv420p", "yuvj420p", "yuv422p", "yuv444p", "rgb24", "rgba")

$pixDisplay = @()
foreach ($opt in $pixOptions) {
    if ($pixFormat -eq $opt) {
        $pixDisplay += "$opt"
    } else {
        $pixDisplay += $opt
    }
}
$pixCurrentIdx = [array]::IndexOf($pixOptions, $pixFormat)
Show-ParameterOptions "Pixel format" $pixOptions $pixDisplay $pixCurrentIdx

# Color Space display (sorted by visual fidelity/resolution: low → high)
$colorOptions = @("bt601", "srgb", "bt709", "bt2020-10", "bt2020-12")

$colorDisplay = @()
foreach ($opt in $colorOptions) {
    if ($colorSpace -eq $opt) {
        $colorDisplay += "$opt"
    } else {
        $colorDisplay += $opt
    }
}
$colorCurrentIdx = [array]::IndexOf($colorOptions, $colorSpace)
Show-ParameterOptions "Color space" $colorOptions $colorDisplay $colorCurrentIdx

# Color Depth display
$depthOptions = @("8-bit", "10-bit", "12-bit", "16-bit")
$depthDisplay = @()
foreach ($opt in $depthOptions) {
    if ($opt -eq $colorDepth) {
        $depthDisplay += "$opt"
    } else {
        $depthDisplay += $opt
    }
}
$currentIdx = $depthOptions.IndexOf($colorDepth)
Show-ParameterOptions "Color depth" $depthOptions $depthDisplay $currentIdx

if ($audioCodec) {
    Write-Host "`nAUDIO INFORMATION:" -ForegroundColor Yellow
    
    # Audio Codec display (sorted alphabetically)
    $audioCodecOptions = @("mp3", "aac", "ac3", "vorbis", "eac3", "opus", "flac")

    $audioCodecDisplay = @()
    foreach ($opt in $audioCodecOptions) {
        if ($audioCodec -eq $opt) {
            $audioCodecDisplay += "$opt"
        } else {
            $audioCodecDisplay += $opt
        }
    }
    $audioCodecIdx = [array]::IndexOf($audioCodecOptions, $audioCodec)
    Show-ParameterOptions "Codec" $audioCodecOptions $audioCodecDisplay $audioCodecIdx
    
    # Audio Channels display
    $channelOptions = @(1, 2, 2.1, 5.1, 7.1)
    $channelLabels = @("Mono", "Stereo", "2.1", "5.1 Surround", "7.1 Surround")
    $channelDisplay = @()
    for ($i = 0; $i -lt $channelOptions.Count; $i++) {
        if ($audioChannels -eq $channelOptions[$i]) {
            $channelDisplay += "$($channelLabels[$i])"
        } else {
            $channelDisplay += $channelLabels[$i]
        }
    }
    $channelIdx = [array]::IndexOf($channelOptions, $audioChannels)
    Show-ParameterOptions "Channels" $channelOptions $channelDisplay $channelIdx
    
    # Audio Sample Rate display
    $sampleOptions = @(44100, 48000, 96000, 192000)
    $sampleLabels = @("44.1 kHz (Low)", "48 kHz (Medium)", "96 kHz (High)", "192 kHz (High)")
    $sampleDisplay = @()
    for ($i = 0; $i -lt $sampleOptions.Count; $i++) {
        if ($audioSampleRateHz -eq $sampleOptions[$i]) {
            $sampleDisplay += "$($sampleLabels[$i])"
        } else {
            $sampleDisplay += $sampleLabels[$i]
        }
    }
    $sampleIdx = [array]::IndexOf($sampleOptions, $audioSampleRateHz)
    Show-ParameterOptions "Sample rate" $sampleOptions $sampleDisplay $sampleIdx
    
    # Audio Bitrate display with examples
    Write-Host "  Bitrate: " -ForegroundColor White -NoNewline
    $audioBitrateExamples = @(
        @{Kbps=48; Label="48 kbps (Low)"},
        @{Kbps=64; Label="64 kbps (Low)"},
        @{Kbps=96; Label="96 kbps (Medium)"},
        @{Kbps=128; Label="128 kbps (Medium)"},
        @{Kbps=192; Label="192 kbps (High)"},
        @{Kbps=256; Label="256 kbps (High)"},
        @{Kbps=320; Label="320 kbps (High)"}
    )
    $audioBitrateDisplay = @()
    foreach ($example in $audioBitrateExamples) {
        if ($audioBitrateKbps -ge ($example.Kbps - 20) -and $audioBitrateKbps -le ($example.Kbps + 20)) {
            $audioBitrateDisplay += "$audioBitrateKbps kbps ($audioBitrateCategory)"
            break
        }
    }
    if ($audioBitrateDisplay.Count -eq 0) {
        $audioBitrateDisplay = @("$audioBitrateKbps kbps ($audioBitrateCategory)")
    }
    foreach ($example in $audioBitrateExamples) {
        $audioBitrateDisplay += $example.Label
    }
    Write-Host $audioBitrateDisplay[0] -ForegroundColor Green -NoNewline
    Write-Host " | " -ForegroundColor DarkGray -NoNewline
    Write-Host ($audioBitrateDisplay[1..($audioBitrateDisplay.Count-1)] -join " | ") -ForegroundColor DarkGray
} else {
    Write-Host "`nAUDIO INFORMATION:" -ForegroundColor Yellow
    Write-Host "  No audio stream detected" -ForegroundColor Yellow
}
Write-Host "`n" -NoNewline
Write-Host "═════════════════════════════════════════════════════════════════`n" -ForegroundColor Gray

# BASE W/O INFO



# ============================================================================
# PREDEFINED CROPS
# ============================================================================
$crops = @{
    '0' = @{ 
        Label='AUTO-CROPPER - Centered'; 
        Desc='Variable output, uses smallest dimension';
        Width='ih'; Height='ih'; X='(iw-ih)/2'; Y='0'
    }
    '1' = @{ 
        Label='Centered Crop 640x480'; 
        Desc='Fixed output';
        Width=640; Height=480; X='(iw-640)/2'; Y='(ih-480)/2'
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

$methodLabel = if ($useAutoDetect) {
    "crop$cropChoice-auto-detect"
} else {
    "crop$cropChoice-$($selectedCrop.Label)"
}
$label = SanitizeFileName -Name $methodLabel
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
