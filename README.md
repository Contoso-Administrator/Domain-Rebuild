# Domain-Rebuild

  The purpose of this script is to quickly rebuild the tech stack on a Windows computer to bring it back into your company's domain, if other options are not available. This script works in three separate phases and is automatically started via Task Scheduler at the login of ONLY the specified local admin account. The only user input needed to complete this process is to login to the specified local admin account (x3), and login to VPN (x2), everything else is automated. You will need edit the variables in the 'Variables to change' section below for this script to work.

The main advantage of this script is that it stores domain credentials as a secured (AES) string (which are then deleted as part of the final step) and there are loops in place to ensure domain connectivity for the domain join and group policy update (the connectivity loops also test domain credentials and allow you to re-enter them if invalid, pre-domain join). Below is a general overview of the domain rebuild and what to expect during each phase of the process.
<br /><br />
<ins>Phase 1:</ins> Login as local admin, copy over the 'Domain Rebuild' folder, start the ‘Domain Rebuild’ script, enter domain join credentials, the 'Domain Rebuild' folder is moved to root, VPN install, (1st) reboot

<ins>Phase 2:</ins> Login as local admin, the script will start and loop until the VPN is turned on, login to the VPN, wait for the script to confirm domain connectivity before it domain joins the computer, (2nd) reboot 

<ins>Phase 3:</ins> Domain join (takes ~4min, depending), Login as local admin, the script will start and loop until the VPN is turned on, login to VPN, script runs gpupdate to populate computer certificates, installs the tech stack, deletes the 'Domain Rebuild' folders, (3rd) reboot
<br /><br />
**Variables to change**
<br />
You will need to customize this script to specify the local admin that is being used (because Task Scheduler triggers the script based on the login of that account), configure installs, and set what location you would like your computer to domain joined to:
<br />
<ins>PreDomainRebuild.ps1</ins>
- Set the variable for $LocalAdmin to the local admin account you plan on using (line 5)
- Configure your VPN install for the domain join (lines 25 & 26)
<ins>DomainRebuild.ps1</ins>
- Set the variable for $LocalAdmin to the local admin account you plan on using (line 5)
- Set the variable for domain and OU location you plan on domain joining the computer to (lines 8-11)
<ins>PostDomainRebuild.ps1</ins>
- Configure the installs for your tech stack (lines 28-30)
- Configure the install for your user-facing VPN (lines 32-35)
<br /><br />
**Important things to know**
- System Drive and Desktop paths are variables and can be used with desktop re-direction/different system drive paths.
- The ‘Domain Rebuild’ folder must be placed on Desktop of specified local admin unaltered or it will break the script.
- DO NOT close any of the PowerShell windows that open, doing so will halt the script. Re-login to the specified local admin to restart that phase of the domain rebuild.
- It is very important that you wait for at least ~4min after logging into local admin post domain join, so you can let domain policies update and apply (depending on your environment). This may cause the computer to become slow and unresponsive after login and it is best to let group policy updates finish before proceeding. Re-login to the specified local admin login if necessary to restart that phase of the domain rebuild.
- The domain credentials are stored as a AES secure string in "$env:ProgramData\DomainRebuild", that folder is then deleted as part of the final step of Phase 3.
- Task Scheduler tasks are deleted as the script proceeds to the next phase, each task is named after the script that created it (ex. the PreDomainRebuild task starts DomainRebuild.ps1 after the 1st reboot).
- Task Scheduler tasks will only start at the login of the specified local admin account, even if the computer is on batteries and tasks are set to the highest run level.
