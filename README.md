# Windows OS Scripts Repository

### I. PowerShell - Mounting and Dismounting an ISO Image

<br>Purpose: creating a Virtual Drive from an ISO Image

<br>Utility: 
- you receive physical copies (CDs/DVDs), from the hospital, containing X-Ray (Radiography) software and imagery
- one of the devices (PC/laptop) that you/your doctor need(s) to use does not have an ODD (optical disc drive)
- you or the doctor need to check the imagery
- ***the imagery software only works while in a non-rewrittable environment***

<br>Instructions:
1. request from the hospital a copy of the files / gain access to a device that has an optical disc drive, insert the CD/DVD and copy the entire content to a new folder, on a USB stick *(for example)*
2. use a free software like PowerISO *(https://www.poweriso.com/download.htm)* in order to create an ISO image from the new folder utilized in the previous step (ISO filename: "rad")
3. download the script from here [Mount_ISO.ps1](https://raw.githubusercontent.com/RomulusMirauta/Windows-Scripts/main/PowerShell_MountDismount_DiskImageISO/Mount_ISO.ps1) *(right-click and choose "Save link as...")*
4. copy/move the script to the same directory that contains the created ISO image
5. execute the script by right-clicking on it and choosing "Run with PowerShell"
6. open Windows Explorer and go to This PC - alongside the Local Disk(s), a virtual drive will be shown
7. double-click on it and review the imagery

<br>*Workaround ***for step 5*** - if the script is not executing - follow these steps:
- right-click on it and choose Properties
- at the bottom, check the Unblock box
- click Apply and then OK
- attempt to execute the script again, by right-clicking on it and choosing "Run with PowerShell"

<br>**Workaround ***for step 7*** - if a folder is shown - follow these steps:
- double-click on the folder
- locate an executable file (.exe file extension), like "DicomViewer.exe"
- double-click on it and review the imagery

<br>Instructions - only for dismounting:
1. open Windows Explorer and go to This PC - alongside the Local Disk(s), a virtual drive will be shown
2. right-click on it and choose Eject
