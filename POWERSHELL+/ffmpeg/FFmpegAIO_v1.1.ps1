#=============================================================================
# FFmpeg All-In-One Script v1.0
# Integrated FFmpeg Tools: Uninstaller, Aspect Ratio Resizer, Cropper, 
# Video to GIF Converter, and Video Trimmer
#=============================================================================

# Write-Host "`n`nFFmpeg All-In-One Script`n" -ForegroundColor Gray
# Write-Host "Integrated Features: FFmpeg Install/Uninstall, Trim, Crop, Aspect Ratio Resizer, Video to GIF Converter`n`n" -ForegroundColor Gray



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
# TOOL: Display Video File Info ***
# ============================================================================

function Invoke-DisplayVideoFileInfo {
    Write-Host "`n"
    Write-Host "► Display Video File Info" -ForegroundColor Yellow
    Write-Host ""

# BASE W/O INFO

# # Supported video file extensions (case-insensitive)
# $supportedExtensionsForVideo = @(
#     '.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv',
#     '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts',
#     '.m2ts', '.ogv', '.vob'
# )

# Supported video/image file extensions (case-insensitive)
$supportedExtensionsForCropping = @(
    '.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv', '.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts', '.m2ts', '.ogv', '.vob',
    '.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff', '.webp'
)

# Find video files in current directory
$sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
    $supportedExtensionsForCropping -contains $_.Extension.ToLower()
}

if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
    Write-Host "`nWARNING: No video files found in the current folder." -ForegroundColor Yellow
    Write-Host "Supported file extensions: $($supportedExtensionsForCropping -join ', ')`n"
    Wait-ForUser
    return
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
    return
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
# Write-Host "`n" -NoNewline
# Write-Host "═════════════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "`nInput file found: $($inputFile.Name)" -ForegroundColor Cyan

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
# Write-Host "═════════════════════════════════════════════════════════════════`n" -ForegroundColor Gray

Wait-ForUser
}

# BASE W/O INFO



# ============================================================================
# TOOL: FFmpeg Manager (Install/Uninstall) ***
# ============================================================================

function Invoke-FFmpegManager {
    Write-Host "`n"
    Write-Host "► FFmpeg Manager" -ForegroundColor Yellow
    Write-Host ""
    
    # Check FFmpeg status
    $ffmpegInstalled = Get-Command FFmpeg -ErrorAction SilentlyContinue
    
    if ($ffmpegInstalled) {
        Write-Host "Status: " -ForegroundColor White -NoNewline
        Write-Host "✓ INSTALLED" -ForegroundColor Green
        
        # Get version
        try {
            $versionOutput = & ffmpeg -version 2>&1 | Select-Object -First 1
            Write-Host "Version: " -ForegroundColor White -NoNewline
            Write-Host $versionOutput -ForegroundColor Green
        } catch {
            Write-Host "Version: " -ForegroundColor White -NoNewline
            Write-Host "(unable to retrieve)" -ForegroundColor Yellow
        }
        
        # Get path
        try {
            $ffmpegPath = (Get-Command FFmpeg).Source
            Write-Host "Path: " -ForegroundColor White -NoNewline
            Write-Host $ffmpegPath -ForegroundColor Green
        } catch {
            Write-Host "Path: " -ForegroundColor White -NoNewline
            Write-Host "(system PATH)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Status: " -ForegroundColor White -NoNewline
        Write-Host "✗ NOT INSTALLED" -ForegroundColor Red
    }
    
    Write-Host ""
    
    while ($true) {
        Write-Host "`nOptions:" -ForegroundColor Cyan
        Write-Host "[i] Install FFmpeg"
        Write-Host "[u] Uninstall FFmpeg"
        if ($ffmpegInstalled) {
            Write-Host "[p] Update FFmpeg"
        }
        Write-Host "[q] Quit workflow and return to Main Menu"
        Write-Host ""
        
        Write-Host "Select option: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
             
        $managerChoice = [char]$key.Character
        Write-Host $managerChoice
        Write-Host ""
        
        switch ($managerChoice) {
            'i' { Install-FFmpeg }
            'u' { Uninstall-FFmpeg }
            'p' {
                if ($ffmpegInstalled) {
                    Update-FFmpeg
                } else {
                    Write-Host ""
                    Write-Host "FFmpeg is not installed. Use option [i] to install first." -ForegroundColor Yellow
                    Write-Host ""
                }
            }
            'q' { return }
            default {
                Write-Host ""
                Write-Host "Invalid choice. Please enter i, u, p, or q." -ForegroundColor Red
                Write-Host ""
                continue
            }
        }
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

function Update-FFmpeg {
    Write-Host ""
    Write-Host "Updating FFmpeg..." -ForegroundColor Cyan
    Write-Host ""
    
    $updateExit = 1
    
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $proc = Start-Process -FilePath 'winget' -ArgumentList 'upgrade --id Gyan.FFmpeg -e --accept-package-agreements' -Wait -NoNewWindow -PassThru
        $updateExit = $proc.ExitCode
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        $proc = Start-Process -FilePath 'choco' -ArgumentList 'upgrade FFmpeg -y' -Wait -NoNewWindow -PassThru
        $updateExit = $proc.ExitCode
    } else {
        Write-Host "No supported package manager found (winget or choco). Please update FFmpeg manually." -ForegroundColor Yellow
        Wait-ForUser
        return
    }
    
    if ($updateExit -eq 0) {
        Write-Host ""
        Write-Host "FFmpeg updated successfully." -ForegroundColor Green
        Write-Host ""
    } elseif ($updateExit -eq -1978335189) {
        Write-Host ""
        Write-Host "You already have the latest FFmpeg version." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "Update failed (exit code $updateExit). Please try again or update manually." -ForegroundColor Red
        Write-Host ""
    }
    
    Wait-ForUser
}

# ============================================================================
# TOOL: Video Trimmer ***
# ============================================================================

function Invoke-VideoTrimmer {
    Write-Host "`n"
    Write-Host "► Video Trimmer" -ForegroundColor Yellow
    Write-Host ""
    
    # Check FFmpeg
    if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: FFmpeg was not found." -ForegroundColor Red
        Write-Host "Install FFmpeg now? (y/n/Escape): " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $install = [char]$key.Character
        Write-Host $install
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
    Write-Host "[0] `e[3mthis is italicized`e[23m, ***`e[3mDefault`e[23m *Default* Re-encode (frame-accurate, best results)"
    Write-Host "[1] Fast (stream copy, no re-encoding)"
    Write-Host ""
    
    $trimMethod = $null
    while (-not $trimMethod) {
        Write-Host "Enter choice (0-1), or press Enter for Default. Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        # Check if Enter key was pressed (VirtualKeyCode 13)
        if ($key.VirtualKeyCode -eq 13) {
            Write-Host ""
            $trimMethod = '0' # Default to re-encode
        } else {
            $methodChoice = [char]$key.Character
            Write-Host $methodChoice
            if ($methodChoice -in @('0','1')) {
                $trimMethod = $methodChoice
            } else {
                Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
            }
        }
    }
    
    # Trim position
    Write-Host "`n"
    Write-Host "Trim from where?" -ForegroundColor Cyan
    Write-Host "[0] Beginning"
    Write-Host "[1] End"
    Write-Host "[2] Both"
    Write-Host ""
    
    $trimChoice = $null
    while (-not $trimChoice) {
        Write-Host "Enter choice (0-2). Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $choice = [char]$key.Character
        Write-Host $choice
        if ($choice -in @('0','1','2')) {
            $trimChoice = $choice
        } else {
            Write-Host "`nInvalid input. Please enter 0, 1, or 2. Press Escape to cancel workflow. " -ForegroundColor Yellow
        }
    }
    
    # Get trim seconds
    $trimSecondsStart = 0
    $trimSecondsEnd = 0
    
    Write-Host ""
    Write-Host "`nCurrent video duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Green
    Write-Host ""
    
    if ($trimChoice -eq '0' -or $trimChoice -eq '1') {
        $trimSeconds = $null
        while (-not $trimSeconds) {
            Write-Host "Enter number of seconds to trim (e.g., 5). Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
            $input = Read-Host
            if ($input -match "^\x1b") {
                Write-Host ""
                Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
                Write-Host ""
                return
            }
            if ($input -match '^[1-9][0-9]*$') {
                $trimSeconds = [int]$input
            }
        }
        
        while ($trimSeconds -ge $duration) {
            Write-Host "`nERROR: Trim seconds must be less than video duration." -ForegroundColor Red
            $secondsInput = Read-Host -Prompt "Enter a valid number of seconds to trim. Press Escape to cancel workflow "
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
    $methodLabel = if ($trimMethod -eq '0') { 're-encode' } else { 'fast' }
    
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
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-c:v', 'libx264', '-c:a', 'aac', $output)
        } else {
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-c', 'copy', $output)
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
            $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-t', $targetDuration, '-c:v', 'libx264', '-c:a', 'aac', $output)
        } else {
            $ffArgs = @($overwriteSwitch, '-i', $inputPath, '-t', $targetDuration, '-c', 'copy', $output)
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
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-t', $targetDuration, '-c:v', 'libx264', '-c:a', 'aac', $output)
        } else {
            $ffArgs = @($overwriteSwitch, '-ss', $trimSecondsStart, '-i', $inputPath, '-t', $targetDuration, '-c', 'copy', $output)
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
# TOOL: Video Cropper ***
# ============================================================================

function Invoke-VideoCropper {
    Write-Host "`n"
    Write-Host "► Video Cropper" -ForegroundColor Yellow
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
    
    Write-Host "Input file found: $($inputFile.Name)" -ForegroundColor Cyan
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
        Write-Host "Enter crop choice (0-8). Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $choice = [char]$key.Character
        Write-Host $choice
        if ($choice -in $crops.Keys) {
            $cropChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter a number between 0 and 8. Press Escape to cancel workflow. " -ForegroundColor Yellow
        }
    }
    
    $selectedCrop = $crops[$cropChoice]
    
    if ($selectedCrop.Custom) {
        Write-Host ""
        Write-Host "Enter custom crop parameters. Press Escape to cancel workflow: " -ForegroundColor Cyan
        $w = Read-Host -Prompt "Width (e.g., 640 or iw)"
        if ($w -eq $null -or $w -match "^\x1b") { Write-Host ""; Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow; Write-Host ""; return }
        $h = Read-Host -Prompt "Height (e.g., 480 or ih)"
        if ($h -eq $null -or $h -match "^\x1b") { Write-Host ""; Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow; Write-Host ""; return }
        $x = Read-Host -Prompt "X offset (e.g., 0 or (iw-w)/2)"
        if ($x -eq $null -or $x -match "^\x1b") { Write-Host ""; Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow; Write-Host ""; return }
        $y = Read-Host -Prompt "Y offset (e.g., 0 or (ih-h)/2)"
        if ($y -eq $null -or $y -match "^\x1b") { Write-Host ""; Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow; Write-Host ""; return }
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
        Write-Host "Enter choice (0-3). Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $choice = [char]$key.Character
        Write-Host $choice
        if ($choice -in @('0', '1', '2', '3')) {
            $codecChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter 0, 1, 2, or 3. Press Escape to cancel workflow. " -ForegroundColor Yellow
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
# TOOL: Video to GIF Converter ***
# ============================================================================

function Invoke-VideoToGifConverter {
    Write-Host ""
    Write-Host "► Video to GIF Converter" -ForegroundColor Yellow
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
        Write-Host "Enter choice (0-$($scaleOptions.Count - 1)) [default: 3]. Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $choice = [char]$key.Character
        Write-Host $choice
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $selectedScale = $scaleOptions[3].Value
        } elseif ($choice -match '^[0-9]+$') {
            $index = [int]$choice
            if ($index -ge 0 -and $index -lt $scaleOptions.Count) {
                $selectedScale = $scaleOptions[$index].Value
            } else {
                Write-Host "Invalid input. Please enter a number between 0 and $($scaleOptions.Count - 1). Press Escape to cancel workflow. " -ForegroundColor Yellow
            }
        } else {
            Write-Host "Invalid input. Please enter a number or press Enter for default. Press Escape to cancel workflow. " -ForegroundColor Yellow
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
# TOOL: Video Aspect Ratio Resizer ***
# ============================================================================

function Invoke-VideoAspectRatioResizer {
    Write-Host ""
    Write-Host "► Video Aspect Ratio Resizer" -ForegroundColor Yellow
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
        Write-Host "Enter choice (0-7). Press Escape to cancel workflow: " -NoNewline -ForegroundColor Gray
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Check if Escape key was pressed (VirtualKeyCode 27)
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host ""
            Write-Host ""
            Write-Host "Cancelled. Returning to Main Menu." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $choice = [char]$key.Character
        Write-Host $choice
        if ($choice -in $formats.Keys) {
            $targetChoice = $choice
        } else {
            Write-Host "Invalid input. Please enter a number between 0 and 7. Press Escape to cancel workflow. " -ForegroundColor Yellow
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



# ============================================================================
# MAIN MENU **
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
    
    Write-Host "`n`n"
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                  FFmpeg All-In-One Script - Main Menu" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[0] Video Trimmer" -ForegroundColor Yellow
    Write-Host "     Remove unwanted sections from beginning, end, or both (in seconds)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[1] Video Cropper" -ForegroundColor Yellow
    Write-Host "     Cut rectangular sections, remove black bars, or zoom in (in pixels)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[2] Video to GIF Converter" -ForegroundColor Yellow
    Write-Host "     Convert video clips into animated GIFs = GitHub/Web/Social Media-friendly loops" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[3] Video Aspect Ratio Resizer" -ForegroundColor Yellow
    Write-Host "     Adapt videos for different use cases - screens/platforms (vertical/horizontal/square)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[4] FFmpeg Manager" -ForegroundColor Yellow
    Write-Host "     Install, update, or uninstall FFmpeg" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[5] Display Video File Info" -ForegroundColor Yellow
    Write-Host "     General, video and audio information" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[6] Exit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Check for video files in current directory
    $videoExtensions = @("*.mkv", "*.mp4", "*.webm", "*.mov", "*.avi", "*.wmv", "*.flv", "*.mpeg", "*.mpg", "*.m4v", "*.3gp", "*.ts", "*.m2ts", "*.ogv", "*.vob")
    $videoFiles = Get-ChildItem -Path (Get-Location) -File | Where-Object { $_.Extension -in $videoExtensions -or $videoExtensions -contains ("*" + $_.Extension) }
    
    if ($videoFiles.Count -eq 1) {
        Write-Host "`n`nInput file found: $($videoFiles[0].Name)" -ForegroundColor Green
        Write-Host ""
    } elseif ($videoFiles.Count -gt 1) {
        Write-Host "`n`nWARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
        Write-Host "Please keep only one video file, and run the script again or press Enter to re-check." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Found files:" -ForegroundColor Yellow
        foreach ($file in $videoFiles) {
            Write-Host "  - $($file.BaseName)$($file.Extension)" -ForegroundColor Yellow
        }
        Write-Host "No video file was found in the current folder. " -ForegroundColor Yellow
    }
    
    Write-Host "`n"
    Write-Host "Select a workflow (0-6): " -NoNewline -ForegroundColor Gray
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $toolChoice = [char]$key.Character
    Write-Host $toolChoice
    
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
            Invoke-DisplayVideoFileInfo
        }
        "6" {
            Write-Host ""
            Write-Host "Exiting FFmpeg AIO Script..." -ForegroundColor Green
            Write-Host ""
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Invalid selection. Please enter a number between 0 and 6." -ForegroundColor Red
            Write-Host ""
        }
    }
}


