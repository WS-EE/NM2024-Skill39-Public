Param (
    [string]$CompetitorId
)

Function Invoke-VmCommand {
    Param (
        [string]$VmName,
        [string]$Script,
        [string]$User="kohtunik",
        [string]$UserPwd="Hindan4usalt!",
        [string]$ScriptType,
        [switch]$raw=$False
    )

    $getVm = Get-VM -Name $VmName
    if (($getVm).PowerState -eq "PoweredOff") {
        return "Fail - VM $VmName is offline!"
    }
    if (($getVm | Get-View).Guest.ToolsStatus -eq "toolsNotRunning") {
        return "Fail - VMware Tools not running at $VmName!"
    }

    if ($ScriptType) {
        $cmd = Invoke-VMScript -VM $getVm -ScriptText $Script -GuestUser $User -GuestPassword $UserPwd -ScriptType $ScriptType -ErrorAction SilentlyContinue
    } else {
        $cmd = Invoke-VMScript -VM $getVm -ScriptText $Script -GuestUser $User -GuestPassword $UserPwd -ErrorAction SilentlyContinue
    }

    if ($raw) {
        $out_cmd = $cmd
    } else {
        $out_cmd = ($cmd).split('\s+')
    }
    return $out_cmd
}

Function Invoke-SshCommand {
    Param (
        [string]$SshIp,
        [string]$SshKey="C:\Users\Administrator\.ssh\nm24",
        [string]$SshUser="kohtunik",
        [string]$Script
    )

    $cmd = ssh -i $SshKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SshUser@$SshIp "$Script"

    return $cmd
}

Function Invoke-ScoreUpdate {
    Param (
        [string]$StatusFile="results\V${CompetitorId}-sectionD.txt",
        [string]$Task,
        [string]$Status,
        [string]$Result,
        [switch]$Default=$True
    )
    
    if (!(Test-Path $StatusFile)) {
        New-Item $StatusFile
    }

    if ($Default) {
        if ($Result -Like "Fail -*") {
            Write-Host $Result
        } elseif ($Result[0] -Eq "1") {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - OK"
        } else {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - NOT OK"
        }    
    } else {
        Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - $Status"
    }
}

$D1M1_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET1" `
    -Script "if curl localhost:80 | grep h1; then echo GUCCI; else echo 0; fi"
echo $D1M1_state
if ($D1M1_state -like "*GUCCI*") {
    $D1M1_state = 1
}
Invoke-ScoreUpdate -Task "D1.M1" -Result "$D1M1_state"

$D1M2_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET1" -User "root" -UserPwd "M3ister2024!" `
    -Script 'if docker inspect --format "{{ .HostConfig.RestartPolicy}}"  docker_web_1 | grep -oP "always|unless-stopped|on-failure"; then echo GUCCI; else echo 0; fi'
echo $D1M2_state
if ($D1M2_state -like "*GUCCI*") {
    $D1M2_state = 1
}
Invoke-ScoreUpdate -Task "D1.M2" -Result "$D1M2_state"

$D2M1_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET2" `
    -Script "if grep -o 10.24.2.21 /etc/fstab; then echo GUCCI; else echo 0; fi"
echo $D2M1_state
if ($D2M1_state -like "*GUCCI*") {
    $D2M1_state = 1
}
Invoke-ScoreUpdate -Task "D2.M1" -Result "$D2M1_state"

Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET2-FS" ` -User "root" -UserPwd "M3ister2024!" -Script "touch /var/nfs/general/bogus"
$D2M2_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET2" -User "root" -UserPwd "M3ister2024!" `
    -Script "if ls /home/arendaja/fileshare | grep -o bogus; then echo GUCCI; else echo 0; fi"
echo $D2M2_state
if ($D2M2_state -like "*GUCCI*") {
    $D2M2_state = 1
}
Invoke-ScoreUpdate -Task "D2.M2" -Result "$D2M2_state"

$D3M1_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET3" `
    -Script "if grep wheel /etc/group | grep -o arendaja; then echo GUCCI; else echo 0; fi"
echo $D3M1_state
if ($D3M1_state -like "*GUCCI*") {
    $D3M1_state = 1
}
Invoke-ScoreUpdate -Task "D3.M1" -Result "$D3M1_state"

$D3M2_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET3" `
    -Script "sudo su arendaja; if echo Passw0rd! | sudo -l | grep -o ALL; then echo GUCCI; else echo 0; fi"
echo $D3M2_state
if ($D3M2_state -like "*GUCCI*") {
    $D3M2_state = 1
}
Invoke-ScoreUpdate -Task "D3.M2" -Result "$D3M2_state"

$D4M1_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET4" `
    -Script "if ping -c 3 10.24.4.254 | grep -o ttl; then echo GUCCI; else echo 0; fi"
echo $D4M1_state
if ($D4M1_state -like "*GUCCI*") {
    $D4M1_state = 1
}
Invoke-ScoreUpdate -Task "D4.M1" -Result "$D4M1_state"

$D4M2_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET4-RTR" `
    -Script "if ping -c 3 10.24.4.20 | grep -o ttl; then echo 0; else echo GUCCI; fi"
echo $D4M2_state
if ($D2M2_state -like "*GUCCI*") {
    $D4M2_state = 1
}
Invoke-ScoreUpdate -Task "D4.M2" -Result "$D4M2_state"

$D5M1_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET5" `
    -Script 'if systemctl is-active miner | grep -o "inactive"; then echo GUCCI; else echo 0; fi;'
echo $D5M1_state
if ($D5M1_state -like "*GUCCI*") {
    $D5M1_state = 1
}
Invoke-ScoreUpdate -Task "D5.M1" -Result "$D5M1_state"

$D5M2_state = Invoke-VmCommand -VmName "MEISTER${CompetitorId}-TICKET5" `
    -Script 'if systemctl is-enabled miner 2>&1 | grep -oP "disabled|file"; then echo GUCCI; else echo 0; fi;'
echo $D5M2_state
if ($D5M2_state -like "*GUCCI*") {
    $D5M2_state = 1
}
Invoke-ScoreUpdate -Task "D5.M2" -Result "$D5M2_state"
