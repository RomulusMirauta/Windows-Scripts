@echo off

rem ensure ffmpeg exists
where ffmpeg >nul 2>&1
if errorlevel 1 (
  echo ERROR! ffmpeg was not found!
  pause >nul
  exit
)

rem ensure file exists: input1.mkv
if not exist "input1.mkv" (
	echo.
    echo WARNING! Required file was not found: input1.mkv
	echo Please add the aforementioned file and run the script again
	echo.
	echo Press any key to exit...
	echo.
	pause >nul
	exit
)

rem avoid overwriting an existing file: palette1.png 
if exist "palette1.png" (
	echo.
    echo WARNING! File already found: palette1.png
	echo Please [re]move the aforementioned file and run the script again
	echo.
	echo Press any key to exit...
	echo.
	pause >nul
	exit
)

rem avoid overwriting an existing file: output1.gif
if exist "output1.gif" (
	echo.
    echo WARNING! File already found: output1.gif
	echo Please [re]move the aforementioned file and run the script again
	echo.
	echo Press any key to exit...
	echo.
	pause >nul
	exit
)

ffmpeg -n -i "input1.mkv" -vf "fps=15,scale=640:-1:flags=lanczos,palettegen" "palette1.png"

if errorlevel 1 (
	echo.
	echo ERROR! Failed to generate file: palette1.png
	echo.
	echo Press any key to exit...
	echo.
  	pause >nul
  	exit
) else (
	echo.
	echo Palette file created, continuing script...
	echo.
)

ffmpeg -n -i "input1.mkv" -i "palette1.png" -filter_complex "fps=15,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse" -loop 0 "output1.gif"

if errorlevel 1 (
	echo.
	echo ERROR! Failed to generate file: output1.gif
	echo.
  	echo Press any key to exit...
	echo.
  	pause >nul
  	exit
) else (
	echo.
	echo.
	echo Output file created.
	echo File conversion completed successfully!
	echo.
	echo Press any key to clean-up and exit...
	echo.
	pause >nul
)

rem cleaning-up the workspace by removing file: palette1.png
if not exist "palette1.png" (
	echo.
    echo WARNING! Required file was not found: palette1.png
	echo.
	echo Press any key to exit...
	echo.
	pause >nul
	exit
) else (
	del "palette1.png"
	exit
)
