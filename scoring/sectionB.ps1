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
        [string]$StatusFile="results\V${CompetitorId}-sectionB.txt",
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

#B1 - FW.HARUKONTOR.EESTI.ASI
$B1M1_state = Invoke-VmCommand -VmName "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "nc -zv 192.168.20${CompetitorId}.5 22"
echo $B1M1_state
    if ($B1M1_state -like "*unreachable*") {
    $B1M1_state = "1"
}
Invoke-ScoreUpdate -Task "B1.M1" -Result "$B1M1_state"

$B1M2_state = if ((Resolve-DnsName -Name "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" -Server 198.51.100.20${CompetitorId} -Type A -QuickTimeout -ErrorAction SilentlyContinue).IPAddress) { echo 1 } else { echo 0 }
Invoke-ScoreUpdate -Task "B1.M2" -Result "$B1M2_state"

$B1M3_state = try { if ((Invoke-WebRequest -Uri http://198.51.100.20${CompetitorId}/ -ErrorAction SilentlyContinue -TimeoutSec 5)) { echo 1 } else { echo 0 } } catch { echo 0 }
Invoke-ScoreUpdate -Task "B1.M3" -Result "$B1M3_state"

$B1M4_state = Invoke-VmCommand -VmName "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'if curl -s http://block.nm24.ee | grep -q "EI TOHI"; then echo 0; else echo 1; fi'
Invoke-ScoreUpdate -Task "B1.M4" -Result "$B1M4_state"

# # B2 - SRV1.HARUKONTOR.EESTI.ASI
$B2M1_state = Invoke-VmCommand -VmName "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "dig harukontor.${CompetitorId}.eesti.asi. SOA @localhost | grep SOA"
if ($B2M1_state -like "*harukontor.${CompetitorID}*") {
    $B2M1_state = 1
}
Invoke-ScoreUpdate -Task "B2.M1" -Result "$B2M1_state"

$B2M2_state = Invoke-VmCommand -VmName "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'dig . @localhost NS +norecurse | grep 600'
if ($B2M2_state -like "*600*") {
    $B2M2_state = 1
}
Invoke-ScoreUpdate -Task "B2.M2" -Result "$B2M2_state"

$B2M3_state = Invoke-VmCommand -VmName "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'docker exec -it $(docker ps 2>/dev/null | grep -oP "[a-z0-9]{12}") bash -c "rndc flush" 2>/dev/null; rndc flush 2>/dev/null; if [ "$(dig bogus.bogus @localhost NS +tries=1 +time=1 | grep -o 203.0.113.1)" ==  "203.0.113.1" ]; then echo 1; else echo 0; fi;'
Invoke-ScoreUpdate -Task "B2.M3" -Result "$B2M3_state"

$B2M4_state = Invoke-VmCommand -VmName "SRV1.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "dig files.harukontor.${CompetitorID}.eesti.asi +norecurse @localhost"    
if ($B2M4_state -like "*10.20.101.11*") {
    $B2M4_state = "1"
}
Invoke-ScoreUpdate -Task "B2.M4" -Result "$B2M4_state"

$B3M1_state = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'netstat -tulpnd | grep -o ":80" | head -1'
if ($B3M1_state -like "*:80*") {
    $B3M1_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M1" -Result "$B3M1_state"

$B3M2_state = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "curl http://www.harukontor.${CompetitorId}.eesti.asi/ | grep html"
if ($B3M2_state -like "*</html>*") {
    $B3M2_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M2" -Result "$B3M2_state"

$B3M3_state = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "curl http://www.harukontor.${CompetitorId}.eesti.asi/ | grep wordpress"

if ($B3M3_state -like "*6.5.3*") {
    $B3M3_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M3" -Result "$B3M3_state"

$B3M4_state = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "curl http://files.harukontor.${CompetitorId}.eesti.asi/ | grep title"

if ($B3M4_state -like "*Index of*") {
    $B3M4_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M4" -Result "$B3M4_state"

$B3M5_state = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if netstat -tln | grep -o 21; then echo 1; else echo 0; fi;"
if ($B3M5_state -like "*1*") {
    $B3M5_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M5" -Result "$B3M5_state"


$B3M6_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "nc -zv 10.20.10${CompetitorId}.12 21 | grep open"
if ($B3M6_state -like "*open*") {
    $B3M6_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M6" -Result "$B3M6_state"

Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTi.ASI" -User "root" -UserPwd "M3ister2024!" -Script "sudo apt install lftp -y; touch /var/ftp/files/test.bogus"
$B3M7_state = "0"
$B3M7_state_anon = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'lftp -u anonymous, localhost -e "ls /; bye;" | grep bogus'
$B3M7_state_auth = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'lftp -u arendaja,Passw0rd! localhost -e "ls /; bye;" | grep bogus'
if ($B3M7_state_anon -like "*bog*" -or $B3M7_state_auth -like "*bog*") {
    $B3M7_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M7" -Result "$B3M7_state"

$B3M8_state = "0"
$B3M8_state_anon = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'lftp -u anonymous, localhost -e "ls; bye;" | grep bogus'
$B3M8_state_auth = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'lftp -u arendaja,Passw0rd! localhost -e "ls; bye;" | grep bogus'

if ($B3M8_state_anon -like "*bog*" -or $B3M8_state_auth -like "*bog*") {
    $B3M8_state = "1"
}
echo $B3M8_state_auth
Invoke-ScoreUpdate -Task "B3.M8" -Result "$B3M8_state"

$B3M9_state = Invoke-VmCommand -VmName "SRV2.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'lftp -u arendaja,Passw0rd! localhost -e "ls; bye;" | grep bogus'
echo $B3M9_state
if ($B3M9_state -like "*bog*") {
    $B3M9_state = "1"
}
Invoke-ScoreUpdate -Task "B3.M9" -Result "$B3M9_state"

$B4M1_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'if [ "$(ip a | grep -o 192.168.20[0-9].5 | grep -oP 5$)" == "5" ]; then echo 1; else echo 0; fi;'
Invoke-ScoreUpdate -Task "B4.M1" -Result "$B4M1_state"

$B4M2_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if curl -s http://10.20.10${CompetitorId}.12; then echo 'ALL OK'; else echo 0; fi"
if ($B4M2_state -like "*ALL OK*") {
    $B4M2_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M2" -Result "$B4M2_state"

$B4M3_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if curl -s http://www.peakontor.${CompetitorId}.eesti.asi; then echo 'ALL OK'; else echo 0; fi"
if ($B4M3_state -like "*ALL OK*") {
    $B4M3_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M3" -Result "$B4M3_state"

$B4M4_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if curl -s http://www.harukontor.${CompetitorId}.eesti.asi; then echo 'ALL OK'; else echo 0; fi"
if ($B4M4_state -like "*ALL OK*") {
    $B4M4_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M4" -Result "$B4M4_state"

$B4M5_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if curl -s http://www.nm24.ee; then echo 'ALL OK'; else echo 0; fi"
if ($B4M5_state -like "*ALL OK*") {
    $B4M5_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M5" -Result "$B4M5_state"

$B4M6_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "nc -zv 10.20.10${CompetitorId}.12 22 | grep open"
if ($B4M6_state -like "*open*") {
    $B4M6_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M6" -Result "$B4M6_state"

$B4M7_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" -User "root" -UserPwd "M3ister2024!" `
    -Script "ls -l /home/arendaja/.ssh/"
if ($B4M7_state -like "*.pub*") {
    $B4M7_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M7" -Result "$B4M7_state"

$B4M8_state = Invoke-VmCommand -VmName "ARENDAJA.HARUKONTOR.${CompetitorId}.EESTI.ASI" -User "arendaja" -UserPwd "Passw0rd!" `
    -Script "ssh arendaja@10.20.10${CompetitorId}.12 'echo HITHERE'"
if ($B4M8_state -like "*HITHERE*") {
    $B4M8_state = "1"
}
Invoke-ScoreUpdate -Task "B4.M8" -Result "$B4M8_state"
