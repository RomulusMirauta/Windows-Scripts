
@echo off
taskkill /f /im explorer.exe
start explorer.exe


REM Command parameters: 
REM f = force (forces the command to be executed) 
REM im = image name (of the process) 