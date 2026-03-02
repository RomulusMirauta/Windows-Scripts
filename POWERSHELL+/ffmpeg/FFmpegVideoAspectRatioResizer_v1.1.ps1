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
    # Maximize PowerShell window
    try {
        $console = [System.Console]
        $console.WindowWidth = [System.Console]::LargestWindowWidth
        $console.WindowHeight = [System.Console]::LargestWindowHeight
    } catch {
        # If direct method fails, try alternative
        mode con: cols=200 lines=50 2>$null | Out-Null
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

# Maximize console window
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

$videoInfo = $probeJson | ConvertFrom-Json
$audioInfo = $probeAudio | ConvertFrom-Json

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
    $colorDepth = if ($vstream.bits_per_raw_sample) { "$($vstream.bits_per_raw_sample)-bit" } else { "8-bit" }
    $videoBitrate = if ($vstream.bit_rate) { 
        $br = [int]$vstream.bit_rate / 1000
        "$br kbps"
    } else { "Unknown" }
}

# Extract audio stream data
if ($audioInfo.streams -and $audioInfo.streams.Count -gt 0) {
    $astream = $audioInfo.streams[0]
    $audioCodec = $astream.codec_name
    $audioChannels = $astream.channels
    $audioSampleRate = if ($astream.sample_rate) { "$($astream.sample_rate) Hz" } else { "Unknown" }
    $audioBitrate = if ($astream.bit_rate) { 
        $br = [int]$astream.bit_rate / 1000
        "$br kbps"
    } else { "Unknown" }
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

Write-Host "`nVIDEO INFORMATION:" -ForegroundColor Yellow
Write-Host "  Resolution: $width x $height" -ForegroundColor White
Write-Host "  Aspect ratio: $ratioW`:$ratioH" -ForegroundColor White
Write-Host "  Frame rate: $fps fps" -ForegroundColor White
Write-Host "  Codec: $videoCodec" -ForegroundColor White
Write-Host "  Bitrate: $videoBitrate" -ForegroundColor White
Write-Host "  Pixel format: $pixFormat" -ForegroundColor White
Write-Host "  Color space: $colorSpace" -ForegroundColor White
Write-Host "  Color depth: $colorDepth" -ForegroundColor White

if ($audioCodec) {
    Write-Host "`nAUDIO INFORMATION:" -ForegroundColor Yellow
    Write-Host "  Codec: $audioCodec" -ForegroundColor White
    Write-Host "  Channels: $audioChannels" -ForegroundColor White
    Write-Host "  Sample rate: $audioSampleRate" -ForegroundColor White
    Write-Host "  Bitrate: $audioBitrate" -ForegroundColor White
}

Write-Host "`nFILE INFORMATION:" -ForegroundColor Yellow
Write-Host "  Size: $fileSizeMB MB" -ForegroundColor White
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
