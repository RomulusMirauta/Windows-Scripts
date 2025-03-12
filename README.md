# Windows Scripts

### I. PowerShell(Dis)MountDiskImageISO.ps1

Purpose: creating a Virtual Drive from an ISO file

Utility: 
- you receive physical copies (CDs/DVDs), from the hospital, containing X-Ray (Radiography) software and imagery
- one of the devices (PC/laptop) that you/your doctor need(s) to use does not have an ODD (optical disc drive)
- you or the doctor need to check the imagery
- ***the imagery software only works while in a non-rewrittable environment***

How to use:
1. request from the hospital a copy of the files / gain access to a device that has an optical disc drive, insert the CD/DVD and copy the entire content to a new folder, on a USB stick *(for example)*
2. use a free software like PowerISO *(https://www.poweriso.com/download.htm)* in order to create an ISO image from the new folder utilized in the previous step
3. download the script from here [PowerShell_MountDismount_DiskImageISO.ps1](https://raw.githubusercontent.com/RomulusMirauta/Windows-Scripts/main/PowerShell_MountDismount_DiskImageISO.ps1) *(right-click and choose "Save link as...")*
4. copy/move the script to the same directory that contains the created ISO image
5. execute the script by double-clicking on it

*If the script does not execute - follow this workaround:
- right-click on it and choose Properties
- at the bottom, check the Unblock box
- click Apply and then OK
- attempt to execute the script again, by double-clicking on it
