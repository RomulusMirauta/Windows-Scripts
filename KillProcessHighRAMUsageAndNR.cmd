
@echo off
taskkill /f /fi "memusage gt 3000000" /fi "status eq not responding"


REM Command parameters: 
REM f = force (forces the command to be executed) 
REM fi = filter 
REM memusage = memory usage (expressed in KB) 
REM gt = greater than 
REM eq = equal 