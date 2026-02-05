
# MOUNT ISO IMAGE

PowerShell -Command "Mount-DiskImage -ImagePath '%path_to_your_file%\%file_name%.iso'"

<# 
Example: 'C:\Users\Romulus\Desktop\rad_folder\rad.iso'
PowerShell -Command "Mount-DiskImage -ImagePath 'C:\Users\Romulus\Desktop\rad_folder\rad.iso'"
#>



<#
*Additional: The variable '$PSScriptRoot' can be used in order to simplify the ImagePath - by avoiding the hardcoding of file paths - but using it requires that the .ps1 script is located in the same folder as the .iso file.
'$PSScriptRoot' contains the full path to the directory of the script currently being run.
Example: '$PSScriptRoot\rad_folder\rad.iso'
PowerShell -Command "Mount-DiskImage -ImagePath '$PSScriptRoot\rad_folder\rad.iso'"
#>



# DISMOUNT ISO IMAGE

Dismount-DiskImage -ImagePath "%path_to_your_file%\%file_name%.iso"

# Or just right-click on the created Drive and select Eject



# For Debugging
# Read-Host -Prompt "Press Enter to close this window"