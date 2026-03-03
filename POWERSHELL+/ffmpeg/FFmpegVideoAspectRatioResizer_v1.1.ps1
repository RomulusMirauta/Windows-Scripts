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

function Maximize-ConsoleWindow {
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
            Write-Host ""
        }
    } else {
        Write-Host $DisplayArray[0] -ForegroundColor White
    }
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

Write-Host "Video Aspect Ratio Resizer" -ForegroundColor Gray
Write-Host ""

# Resize/maximize console window
Maximize-ConsoleWindow

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
    Write-Host "Supported file extensions: $($videoExtensions -join ', ')"
    Write-Host ""
    Wait-ForUser
    exit 1
}
if ($sourceMatches.Count -gt 1) {
    Write-Host "`nWARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
    Write-Host "Please keep only one video file and run the script again." -ForegroundColor Yellow
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

# File Extension display (all supported video formats)
$videoExtensions = @('.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob')
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

# 9:16 (0.56) - Vertical portrait
# 2:3 (0.67) - Portrait
# 4:5 (0.8) - Social
# 1:1 (1.0) - Square
# 4:3 (1.33) - Classic
# 3:2 (1.5) - Classic
# 16:9 (1.78) - Wide
# 21:9 (2.33) - Cinema (widest)

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

# yuv420p - 4:2:0 chroma subsampling (lowest)
# yuvj420p - 4:2:0 full-range
# yuv422p - 4:2:2 chroma subsampling
# yuv444p - 4:4:4 full chroma resolution
# rgb24 - Full RGB (no subsampling)
# rgba - Full RGB + Alpha channel (highest)

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

# bt601 - Oldest broadcast standard (limited gamut)
# srgb - Computer display standard
# bt709 - HD broadcast standard
# bt2020-10 - 10-bit UHD (wider gamut)
# bt2020-12 - 12-bit UHD (widest gamut, highest fidelity)

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

    # mp3 - Lossy, older, lower quality
    # aac - Lossy, moderate quality
    # ac3 - Lossy, surround
    # vorbis - Lossy, good quality
    # eac3 - Lossy, improved (Dolby Digital Plus)
    # opus - Lossy, modern, excellent quality
    # flac - Lossless (highest fidelity)

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
Write-Host "═════════════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host ""

# Define target formats (Label, ratio and optional short Description)
$formats = @{
    '0' = @{ Label='Wide 16:9'; W=16; H=9; Desc='YouTube and streaming sites' }
    '1' = @{ Label='Vertical 9:16'; W=9; H=16; Desc='Instagram Reels and TikTok' }
    '2' = @{ Label='Square 1:1'; W=1; H=1; Desc='Instagram posts' }
    '3' = @{ Label='Classic 4:3'; W=4; H=3; Desc=$null }
    '4' = @{ Label='Social 4:5'; W=4; H=5; Desc=$null }
    '5' = @{ Label='Cinema 21:9'; W=21; H=9; Desc=$null }
    '6' = @{ Label='Portrait 2:3'; W=2; H=3; Desc=$null }
}

Write-Host "Select target format:" -ForegroundColor Cyan
foreach ($k in $formats.Keys | Sort-Object) {
    $f = $formats[$k]
    if ($f.Desc) {
        $line = "[$k] $($f.Label) ($($f.Desc))"
    } else {
        $line = "[$k] $($f.Label)"
    }
    Write-Host $line
}

$targetChoice = $null
while (-not $targetChoice) {
    $choice = Read-Host -Prompt "`nEnter choice (0-6)"
    if ($choice -in $formats.Keys) {
        # Check if this aspect ratio matches the current video
        $testTarget = $formats[$choice]
        $g2Test = Get-Gcd -a $testTarget.W -b $testTarget.H
        $rtwTest = [int]($testTarget.W / $g2Test)
        $rthTest = [int]($testTarget.H / $g2Test)
        
        if ($rtwTest -eq $ratioW -and $rthTest -eq $ratioH) {
            Write-Host "`nWARNING: Selected format has the same aspect ratio as the current video ($ratioW`:$ratioH)." -ForegroundColor Yellow
            Write-Host "No conversion is needed. Please select a different format." -ForegroundColor Yellow
        } else {
            $targetChoice = $choice
        }
    } else {
        Write-Host "Invalid input. Please enter a number between 0 and 6." -ForegroundColor Yellow
    }
}

$target = $formats[$targetChoice]
$tw = $target.W
$th = $target.H

Write-Host "`nSelected: $($target.Label)" -ForegroundColor Green

# Reduce target ratio early to check compatibility
$g2 = Get-Gcd -a $tw -b $th
$rtw = [int]($tw / $g2)
$rth = [int]($th / $g2)

# Determine if rotation-only can achieve target (swap of input reduced ratio)
$isRotationOnly = ($rtw -eq $ratioH -and $rth -eq $ratioW)

# Check if target ratio matches current ratio (no conversion needed)
$isSameAspect = ($rtw -eq $ratioW -and $rth -eq $ratioH)

# Ask fast (metadata rotation) or re-encode
Write-Host "`n`nChoose method:" -ForegroundColor Cyan
Write-Host "[0] Fast (metadata rotation only, stream copy)"
if ($isRotationOnly) {
    Write-Host "     WARNING: Only changes metadata, not actual pixels. Output will still be $width x $height." -ForegroundColor Yellow
}
Write-Host "[1] Re-encode (apply scale/pad filters)"

$method = $null
while (-not $method) {
    $m = Read-Host -Prompt "`nEnter choice (0-1)"
    if ($m -in @('0','1')) { $method = $m } else { Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow }
}

function Resolve-OutputPathAndSwitch {
    param(
        [string]$OutputDir,
        [string]$Filename
    )
    $out = Join-Path -Path $OutputDir -ChildPath $Filename
    if (Test-Path -Path $out) {
        while ($true) {
            Write-Host ""
            Write-Host "`nWARNING: Output already exists:`n$out" -ForegroundColor Yellow
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

# Prepare output directory and filename
$outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_VideoAspectRatioResizer")
if (-not (Test-Path -Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory | Out-Null }

if ($method -eq '0' -and -not $isRotationOnly -and -not $isSameAspect) {
    Write-Host "Fast method (metadata rotation) cannot produce the selected aspect ratio for this input." -ForegroundColor Yellow
    Write-Host "Falling back to re-encode method." -ForegroundColor Yellow
    $method = '1'
}

if ($method -eq '0' -and ($isRotationOnly -or $isSameAspect)) {
    $label = "$($target.Label)_fast"
    $safeLabel = SanitizeFileName -Name $label
    $filename = "$($inputFile.BaseName)_$safeLabel$($inputFile.Extension)"
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch

    # Determine rotation value: rotate 90 if input is landscape -> target portrait, else 270
    if ($isRotationOnly) {
        if ($width -gt $height -and $th -gt $tw) { $rotateVal = 90 } else { $rotateVal = 270 }
        Write-Host "Applying metadata rotation ($rotateVal degrees) and copying streams..." -ForegroundColor Cyan
        Write-Host "WARNING: Metadata rotation only changes playback orientation, not actual pixel dimensions." -ForegroundColor Yellow
        Write-Host "The output file will still be $width x $height; players that respect rotation will display it as $height x $width." -ForegroundColor Yellow
        Write-Host "Note: Not all containers honor rotate metadata." -ForegroundColor Yellow
        $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-c', 'copy', '-metadata:s:v:0', "rotate=$rotateVal", $output)
    } else {
        Write-Host "Aspect ratio matches current video; using fast stream copy..." -ForegroundColor Cyan
        $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-c', 'copy', $output)
    }
    Write-Host "FFmpeg args: " ($ffArgs -join ' | ') -ForegroundColor DarkGray
    $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    $LASTEXITCODE = $rc

    if ($rc -ne 0) {
        Write-Host "Fast method failed; falling back to re-encode." -ForegroundColor Yellow
        # Build re-encode args (same logic as below)
        if ($tw -gt $th) {
            $outW = [int]([math]::Round([double]([math]::Max($width, $height))))
            $outH = [int]([math]::Round($outW * ($th / $tw)))
        } else {
            $outH = [int]([math]::Round([double]([math]::Max($width, $height))))
            $outW = [int]([math]::Round($outH * ($tw / $th)))
        }
        if ($outW -lt 2) { $outW = 2 }
        if ($outH -lt 2) { $outH = 2 }
        $label = "$($target.Label)_re-encode_${outW}x${outH}"
        $safeLabel = SanitizeFileName -Name $label
        $filename = "$($inputFile.BaseName)_$safeLabel$($inputFile.Extension)"
        $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
        $output = $info.Output
        $overwriteSwitch = $info.Switch
        $aspectExpr = "{0}/{1}" -f $tw, $th
        $vf = "scale='if(gt(a,{0}),{1},-2)':'if(gt(a,{0}),-2,{2})',pad={1}:{2}:(ow-iw)/2:(oh-ih)/2,setsar=1" -f $aspectExpr, $outW, $outH
        Write-Host "Re-encoding to $outW x $outH using scale+pad..." -ForegroundColor Cyan
        $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-vf', $vf, '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output)
        Write-Host "FFmpeg args: " ($ffArgs -join ' | ') -ForegroundColor DarkGray
        $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
        $LASTEXITCODE = $rc
    }

} else {
    # Re-encode path: compute output target dimensions based on largest original side
    if ($tw -gt $th) {
        $outW = [int]([math]::Round([double]([math]::Max($width, $height))))
        $outH = [int]([math]::Round($outW * ($th / $tw)))
    } else {
        $outH = [int]([math]::Round([double]([math]::Max($width, $height))))
        $outW = [int]([math]::Round($outH * ($tw / $th)))
    }

    if ($outW -lt 2) { $outW = 2 }
    if ($outH -lt 2) { $outH = 2 }

    $label = "$($target.Label)_re-encode_${outW}x${outH}"
    $safeLabel = SanitizeFileName -Name $label
    $filename = "$($inputFile.BaseName)_$safeLabel$($inputFile.Extension)"
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch

    # Build vf filter: scale to fit then pad to exact (use -f formatting to avoid PowerShell $var parsing in the filter)
    $aspectExpr = "{0}/{1}" -f $tw, $th
    $vf = "scale='if(gt(a,{0}),{1},-2)':'if(gt(a,{0}),-2,{2})',pad={1}:{2}:(ow-iw)/2:(oh-ih)/2,setsar=1" -f $aspectExpr, $outW, $outH

    Write-Host "Re-encoding to $outW x $outH using scale+pad..." -ForegroundColor Cyan
    $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-vf', $vf, '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-c:a', 'aac', '-b:a', '128k', $output)
    Write-Host "FFmpeg args: " ($ffArgs -join ' | ') -ForegroundColor DarkGray
    $rc = Invoke-FFmpeg -FfmpegArgs $ffArgs
    $LASTEXITCODE = $rc
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "" 
    Write-Host "ERROR: Format conversion failed. Exiting the script..." -ForegroundColor Red
    Write-Host ""
    Wait-ForUser
    exit 1
}

Write-Host "" 
Write-Host "Output created: $output" -ForegroundColor Green
Write-Host ""
