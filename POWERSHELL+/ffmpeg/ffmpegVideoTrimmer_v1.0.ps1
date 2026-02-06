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
	Write-Host "ERROR: ffmpeg was not found in PATH." -ForegroundColor Red
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
	Write-Host "WARNING: No video files found in the current folder." -ForegroundColor Yellow
	Write-Host "Supported file extensions: $($videoExtensions -join ', ')"
	Wait-ForUser
	exit 1
}
if ($sourceMatches.Count -gt 1) {
	Write-Host "WARNING: Multiple video files found in the current folder." -ForegroundColor Yellow
	Write-Host "Please keep only one video file and run the script again." -ForegroundColor Yellow
	Wait-ForUser
	exit 1
}

$inputFile = $sourceMatches[0]
$output = "${($inputFile.BaseName)}_trimmed$($inputFile.Extension)"

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
		Write-Host "Invalid input. Please enter 0 or 1." -ForegroundColor Yellow
	}
}

# Get trim seconds
$trimSeconds = $null
while (-not $trimSeconds) {
    Write-Host ""
    Write-Host ""
	$secondsInput = Read-Host -Prompt "Enter number of seconds to trim (e.g., 5)"
	if ($secondsInput -match '^[1-9][0-9]*$') {
		$trimSeconds = [int]$secondsInput
	} else {
		Write-Host "Invalid input. Please enter a higher than zero integer." -ForegroundColor Yellow
	}
}

# Perform trim
if ($trimChoice -eq '1') {
	Write-Host "" 
	Write-Host "Trimming $trimSeconds seconds from the beginning..."
	& ffmpeg -n -ss $trimSeconds -i $inputFile.FullName -c copy $output
} else {
	Write-Host ""
	Write-Host "Trimming $trimSeconds seconds from the end..."
	& ffmpeg -n -i $inputFile.FullName -t "-$trimSeconds" -c copy $output
}

if ($LASTEXITCODE -ne 0) {
	Write-Host "ERROR: Trim failed." -ForegroundColor Red
	Wait-ForUser
	exit 1
}

Write-Host "" 
Write-Host "Output created: $output" -ForegroundColor Green
