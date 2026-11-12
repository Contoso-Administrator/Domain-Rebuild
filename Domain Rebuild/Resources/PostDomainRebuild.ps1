#Group Policy update loop
$Attempt = 0

while ($true) {
    $Attempt++
    Write-Host "Updating Group Policy (attempt $Attempt)" -ForegroundColor yellow

    $p = Start-Process -FilePath "gpupdate.exe" -ArgumentList '/force' -PassThru -WindowStyle Hidden
    $null = $p.Handle

    if (-not $p.WaitForExit(180000)) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Host "gpupdate timed out after 3 minutes." -ForegroundColor Red
    }
    elseif ($p.ExitCode -eq 0) {
        Write-Host "Group Policy update successful." -ForegroundColor Green
        break
    }
    else {
        Write-Host "gpupdate failed (exit code: $($p.ExitCode)). Cannot reach a domain controller." -ForegroundColor Red
    }

    Write-Host "Retrying in 15 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
}

#EXE Application install
Start-Process -FilePath "$env:SystemDrive\Domain Rebuild\Resources\EXEapplication.exe" -ArgumentList '/S' -Wait
#MSI Application install
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$env:SystemDrive\Domain Rebuild\Resources\MSIapplication.msi`" /qn /norestart" -Wait;
#VPN install for the User configuration
Start-Process -FilePath "net.exe" -ArgumentList 'stop VPN' -Wait;
Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"$env:SystemDrive\Domain Rebuild\Resources\VPN.msi`" /qn /norestart" -Wait;
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$env:SystemDrive\Domain Rebuild\Resources\VPN.msi`" /qn /norestart ALLUSERS=1" -Wait;
Start-Process -FilePath "reg.exe" -ArgumentList "import `"$env:SystemDrive\Domain Rebuild\Resources\UserVPNconfig.reg`"" -Wait

#Delete Domain Rebuild Folders
Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout /t 1 /nobreak >nul & rmdir /s /q `"$env:SystemDrive\Domain Rebuild`""
Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout /t 6 /nobreak >nul & rmdir /s /q `"$env:ProgramData\DomainRebuild`""

#Delete last scheduled task before reboot
Unregister-ScheduledTask -TaskName "PostDomainJoin" -Confirm:$false -ErrorAction SilentlyContinue;
Start-Sleep -Seconds 60; Restart-Computer -Force