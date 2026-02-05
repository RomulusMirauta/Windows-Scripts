:: Hides command execution output for a cleaner display
@echo off
:: Aborts (-a) any active countdown for: shutdown, hibernation, restart or log-off. It does not affect system sleep timers!
shutdown -a
:: timeout /t 3600 - Waits for 3600 seconds (1 hour) before executing the next command
:: && shutdown /h /f – After the timeout, hibernates the system (/h) and forces all applications to close (/f)
timeout /t 3600 && shutdown /h /f