Write-Host "Video Trimmer (seconds)`n" -ForegroundColor Gray

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
                Write-Host "WARNING: Could not refresh PATH automatically. Please run the script again or manually add FFmpeg to PATH." -ForegroundColor Yellow
            }

            # Re-check availability
            if (-not (Get-Command FFmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "FFmpeg still not found after installation. You may need to restart your shell or manually add it to PATH." -ForegroundColor Yellow
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



# # Supported video file extensions (case-insensitive)
# $videoExtensions = @(
# 	'.mkv', '.mp4', '.webm', '.mov', '.avi', '.wmv',
# 	'.flv', '.mpeg', '.mpg', '.m4v', '.3gp', '.ts',
# 	'.m2ts', '.ogv', '.vob'
# )

# # Find video files in current directory
# $sourceMatches = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
# 	$videoExtensions -contains $_.Extension.ToLower()
# }

# if (-not $sourceMatches -or $sourceMatches.Count -eq 0) {
# 	Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
# 	Write-Host "Supported file extensions: $($videoExtensions -join ', ')"
# 	Write-Host ""
# 	Wait-ForUser
# 	exit 1
# }
# if ($sourceMatches.Count -gt 1) {
# 	Write-Host "WARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
# 	Write-Host "Please keep only one video file and run the script again." -ForegroundColor Yellow
# 	Write-Host ""
# 	Wait-ForUser
# 	exit 1
# }



# Choose trim method
Write-Host ""
Write-Host "Select trim method:" -ForegroundColor Cyan
Write-Host "[0] Default (fast) - stream copy, no re-encoding"
Write-Host "[1] Re-encode (slow) - frame-accurate, better precision"

$trimMethod = $null
while (-not $trimMethod) {
    Write-Host ""
    $methodChoice = Read-Host -Prompt "Enter choice (0-1)"
    if ($methodChoice -in @('0','1')) {
        $trimMethod = $methodChoice
    } else {
        Write-Host ""
        Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
    }
}

# Choose trim position
Write-Host ""
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

        if (-not (Get-Command FFprobe -ErrorAction SilentlyContinue)) {
            Write-Host "ERROR: FFprobe was not found in PATH. Please re-install FFmpeg (which includes FFprobe) or manually add FFprobe to PATH." -ForegroundColor Red
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
$methodLabel = if ($trimMethod -eq '0') { 'fast' } else { 're-encode' }

# Create output directory named "<BaseName>_VideoTrimmer" next to the input file
$outputDir = Join-Path -Path $inputFile.DirectoryName -ChildPath ("$($inputFile.BaseName)_VideoTrimmer")
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

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
            Write-Host "WARNING: Output already exists:`n$out" -ForegroundColor Yellow
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
    $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsStart}_${methodLabel}$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    Write-Host "" 
    Write-Host "Trimming $trimSecondsStart second(s) from the beginning..."
    Write-Host ""
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch
    if ($trimMethod -eq '0') {
        & ffmpeg $overwriteSwitch -ss $trimSecondsStart -i $inputPath -c copy $output
    } else {
        & ffmpeg $overwriteSwitch -ss $trimSecondsStart -i $inputPath -c:v libx264 -c:a aac $output
    }
} elseif ($trimChoice -eq '1') {
    $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsEnd}_${methodLabel}$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    Write-Host ""
    Write-Host "Trimming $trimSecondsEnd second(s) from the end..."
    Write-Host ""
    $targetDuration = $duration - $trimSecondsEnd
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch
    if ($trimMethod -eq '0') {
        & ffmpeg $overwriteSwitch -i $inputPath -t $targetDuration -c copy $output
    } else {
        & ffmpeg $overwriteSwitch -i $inputPath -t $targetDuration -c:v libx264 -c:a aac $output
    }
} else {
    $filename = "$($inputFile.BaseName)_trimmed_${trimLabel}_${trimSecondsStart}start_${trimSecondsEnd}end_${methodLabel}$($inputFile.Extension)"
    $output = Join-Path -Path $outputDir -ChildPath $filename
    Write-Host ""
    Write-Host "Trimming $trimSecondsStart second(s) from the beginning and $trimSecondsEnd second(s) from the end..."
    Write-Host ""
    $targetDuration = $duration - $trimSecondsStart - $trimSecondsEnd
    $info = Resolve-OutputPathAndSwitch -OutputDir $outputDir -Filename $filename
    $output = $info.Output
    $overwriteSwitch = $info.Switch
    if ($trimMethod -eq '0') {
        & ffmpeg $overwriteSwitch -ss $trimSecondsStart -i $inputPath -t $targetDuration -c copy $output
    } else {
        & ffmpeg $overwriteSwitch -ss $trimSecondsStart -i $inputPath -t $targetDuration -c:v libx264 -c:a aac $output
    }
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
