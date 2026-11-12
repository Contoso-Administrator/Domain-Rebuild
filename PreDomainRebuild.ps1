$SecretDir  = "C:\ProgramData\DomainRebuild"
$KeyFile    = "$SecretDir\aes.key"
$UserFile   = "$SecretDir\user.txt"
$SecretFile = "$SecretDir\join.txt"
$LocalAdmin = "Local Admin"

#Move folder to root
Move-Item -Path "$([Environment]::GetFolderPath('Desktop'))\Domain Rebuild" -Destination "$env:SYSTEMDRIVE\Domain Rebuild" -Force -ErrorAction Stop

#AD credentials stored as a secure string
Add-Type -AssemblyName System.Security
New-Item -Path $SecretDir -ItemType Directory -Force | Out-Null
icacls $SecretDir /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" | Out-Null
$Key = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($Key)
$ProtectedKey = [Security.Cryptography.ProtectedData]::Protect($Key, $null, 'LocalMachine')
[IO.File]::WriteAllBytes($KeyFile, $ProtectedKey)
Write-Host "Please enter credentials to domain join the computer" -ForegroundColor Yellow
$User   = Read-Host "Enter username (without domain)"
$Secure = Read-Host "Enter password" -AsSecureString
ConvertTo-SecureString $User -AsPlainText -Force | ConvertFrom-SecureString -Key $Key | Set-Content -Path $UserFile -Encoding ASCII
$Secure | ConvertFrom-SecureString -Key $Key | Set-Content -Path $SecretFile -Encoding ASCII

#VPN Install
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$env:SystemDrive\Domain Rebuild\Resources\VPN.msi`" /qn /norestart" -Wait;
Start-Process -FilePath "reg.exe" -ArgumentList "import `"$env:SystemDrive\Domain Rebuild\Resources\DomainJoinVPNconfig.reg`"" -Wait

#Creates scheduled task to execute next script after next Local Admin login
$PostRebootScript = "$env:SYSTEMDRIVE\Domain Rebuild\Resources\DomainRebuild.ps1"
$TaskName = "DomainJoin"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
-Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& '$PostRebootScript'; Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:COMPUTERNAME\$LocalAdmin"
$principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$LocalAdmin" -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
-Principal $principal -Settings $settings -Force | Out-Null;

#Reboot to apply VPN config
Restart-Computer -Force
