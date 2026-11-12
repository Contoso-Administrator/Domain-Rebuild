$SecretDir  = "C:\ProgramData\DomainRebuild"
$KeyFile    = "$SecretDir\aes.key"
$UserFile   = "$SecretDir\user.txt"
$SecretFile = "$SecretDir\join.txt"
$LocalAdmin = "Local Admin"

#Domain join variables
$Domain      = "contoso.com"
$OURoot      = "Corp"
$OUSite      = "Main Site"
$OUComputers = "Computers"   

$DomainDN = ($Domain.Split('.') | ForEach-Object { "DC=$_" }) -join ','
$OUPath   = "OU=$OUComputers,OU=$OUSite,OU=$OURoot,$DomainDN"

#AD credential test loop
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.DirectoryServices.AccountManagement

function Test-ADCredential {
    param(
        [string]$Domain,
        [string]$User,
        [SecureString]$Password
    )
    $Plain = [Net.NetworkCredential]::new('', $Password).Password
    $Ctx   = $null
    try {
        $Ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)
        if ($Ctx.ValidateCredentials($User, $Plain,
            [System.DirectoryServices.AccountManagement.ContextOptions]::Negotiate)) { 'Valid' } else { 'Invalid' }
    }
    catch {
        'Unreachable'
    }
    finally {
        if ($Ctx) { $Ctx.Dispose() }
        $Plain = $null
    }
}

$Key      = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($KeyFile), $null, 'LocalMachine')
$Username = [Net.NetworkCredential]::new('', ((Get-Content -Path $UserFile -Raw).Trim() | ConvertTo-SecureString -Key $Key)).Password
$Secure   = (Get-Content -Path $SecretFile -Raw).Trim() | ConvertTo-SecureString -Key $Key
$Attempt = 0

do {
    $Attempt++
    $Result = Test-ADCredential -Domain $Domain -User $Username -Password $Secure

    switch ($Result) {
        'Unreachable' {
            Write-Host "Cannot reach a $Domain domain controller (attempt $Attempt)" -ForegroundColor Red
            Write-Host "Retrying in 15 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 15
        }
        'Invalid' {
            Write-Host "Invalid Credential" -ForegroundColor Red
            $Username = Read-Host "Enter username (without domain)"
            $Secure   = Read-Host "Enter password" -AsSecureString
        }
    }
} until ($Result -eq 'Valid')

$Cred = New-Object System.Management.Automation.PSCredential("$Domain\$Username", $Secure)

#Domain join after AD credentials are tested
Add-Computer -DomainName $Domain `
     -OUPath $OUPath `
     -Credential $Cred -Force -ErrorAction Stop

#Creates scheduled task to execute next script after logon
$PostRebootScript = "$env:SYSTEMDRIVE\Domain Rebuild\Resources\PostDomainRebuild.ps1"
$TaskName         = "PostDomainJoin"

#Creates scheduled task to execute next script 1min after Local Admin logon, to allow for GPOs to apply
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& '$PostRebootScript'; Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:COMPUTERNAME\$LocalAdmin"
$trigger.Delay = "PT1M"
$principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$LocalAdmin" -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null;
Unregister-ScheduledTask -TaskName "DomainJoin" -Confirm:$false -ErrorAction SilentlyContinue;

Restart-Computer -Force