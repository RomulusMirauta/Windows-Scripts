
# MOUNT ISO IMAGE

PowerShell -Command "Mount-DiskImage -ImagePath '%path_to_your_file%\%file_name%.iso'"

<# 
Example: 'C:\Users\Romulus\Desktop\rad.iso'
PowerShell -Command "Mount-DiskImage -ImagePath 'C:\Users\Romulus\Desktop\rad.iso'"
#>



# DISMOUNT ISO IMAGE

Dismount-DiskImage -ImagePath "%path_to_your_file%\%file_name%.iso"

# Or just right-click on the created Drive and select Eject



# For Debugging
# Read-Host -Prompt "Press Enter to close this window"