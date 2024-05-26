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
        [string]$StatusFile="results\V${CompetitorId}-sectionA.txt",
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

# A1 - FW.PEAKONTOR.EESTI.ASI
$A1M1_state = Invoke-SshCommand -SshIp 10.10.10${CompetitorId}.1 -Script 'get system interface physical port3'
if ($A1M1_state -like "*192.168.10${CompetitorId}*") {
    $A1M1_state = "1"
}
Invoke-ScoreUpdate -Task "A1.M1" -Result "$A1M1_state"

$A1M2_state = Invoke-SshCommand -SshIp 10.10.10${CompetitorId}.1 -Script "show system dhcp server | grep 192.168.10${CompetitorId}"
if ($A1M2_state -like "*set start-ip 192.168.10${CompetitorId}.100*") {
    $A1M2_state = "1"
}
Invoke-ScoreUpdate -Task "A1.M2" -Result "$A1M2_state"

$A1M3_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'if ((Invoke-WebRequest -Uri http://203.0.113.3/client-ip -TimeoutSec 5 -UseBasicParsing).RawContent -Like "*198.51.100.10*") { return 1 } else { return 0 }'
Invoke-ScoreUpdate -Task "A1.M3" -Result "$A1M3_state"

$A1M4_state = if ((Resolve-DnsName -Name "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" -Server 198.51.100.10${CompetitorId} -Type A -QuickTimeout -ErrorAction SilentlyContinue).IPAddress -like "*10.10*") { echo 1 } else { echo 0 }
Invoke-ScoreUpdate -Task "A1.M4" -Result "$A1M4_state"

$A1M5_state = try { if ((Invoke-WebRequest -Uri http://198.51.100.10${CompetitorId}/ -ErrorAction SilentlyContinue -TimeoutSec 5)) { echo 1 } else { echo 0 } } catch { echo 0 }
Invoke-ScoreUpdate -Task "A1.M5" -Result "$A1M5_state"

# A2 - SRV1.PEAKONTOR.EESTI.ASI

$A2M1_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'try { if ((Get-ADForest | Select Name) -Like "*peakontor*eesti.asi*") { return 1 } else { return 0 } } catch { return 0 }'

Invoke-ScoreUpdate -Task "A2.M1" -Result "$A2M1_state"

$A2M2_state =  Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'try { if ((Get-DnsServerRootHint).IPAddress.RecordData.IPv4Address.IPAddressToString -Like "*203.0.113.1*") { return 1 } else { return 0 } } catch { return 0 }'
Invoke-ScoreUpdate -Task "A2.M2" -Result "$A2M2_state"

$A2M3_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script 'try { if ((Get-DnsServerForwarder).IPAddress.IPAddressToString -Like "*203.0.113.1*") { return 1 } else { return 0 } } catch { return 0 }'

Invoke-ScoreUpdate -Task "A2.M3" -Result "$A2M3_state"

$A2M4_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if (Resolve-DnsName -Name www.peakontor.${CompetitorId}.eesti.asi -ErrorAction SilentlyContinue) { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A2.M4" -Result "$A2M4_state"

$A2M5_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-ADUser zak.coates).Name -Like '*Zak*') { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A2.M5" -Result "$A2M5_state"

$A2M6_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-ADUser -Filter {samAccountName -eq 'zak.coates'} -Properties *).Title -Like '*Cashier*') { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A2.M6" -Result "$A2M6_state"

$A2M7_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-FileHash -Algorithm MD5 C:\Windows\PolicyDefinitions\PerformanceDiagnostics.admx).Hash -Like 'B0603D67D66D7DF907B9C2AACF31A14B' ) { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A2.M7" -Result "$A2M7_state"

$A2M8_state =  Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-WindowsFeature -Name FS-FileServer).InstallState -Like 'Installed') { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A2.M8" -Result "$A2M8_state"

$A2M9_state = Invoke-VmCommand -VmName "SRV1.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-IscsiServerTarget).Description -Like '*veebiserveri*' ) { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A2.M9" -Result "$A2M9_state"

# A3 - SRV2.PEAKONTOR.EESTI.ASI

$A3M1_state = Invoke-VmCommand -VmName "SRV2.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-WmiObject -Class Win32_ComputerSystem).Domain -Like 'peakontor*eesti.asi' ) { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A3.M1" -Result "$A3M1_state"

$A3M2_state = Invoke-VmCommand -VmName "SRV2.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-Item C:\inetpub).LinkType -Like 'Junction' ) { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A3.M2" -Result "$A3M2_state"

$A3M3_state = Invoke-VmCommand -VmName "SRV2.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-WindowsFeature -Name Web-Server).InstallState -Like 'Installed') { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A3.M3" -Result "$A3M3_state"

$A3M4_state = Invoke-VmCommand -VmName "SRV2.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if ((Invoke-WebRequest -Uri http://www.peakontor.${CompetitorId}.eesti.asi/ -TimeoutSec 5 -UseBasicParsing).RawContent -Like '*Eesti Asi*') { return 1 } else { return 0 }"
Invoke-ScoreUpdate -Task "A3.M4" -Result "$A3M4_state"

$A3M5_state = Invoke-VmCommand -VmName "SRV2.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-DfsnRoot).Path -Like '*FS*') { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A3.M5" -Result "$A3M5_state"

# A4 - KASUTAJA.PEAKONTOR.EESTI.ASI

$A4M1_state = Invoke-VmCommand -VmName "KASUTAJA.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "try { if ((Get-WmiObject -Class Win32_ComputerSystem).Domain -Like 'peakontor*eesti.asi' ) { return 1 } else { return 0 } } catch { return 0 }"
Invoke-ScoreUpdate -Task "A4.M1" -Result "$A4M1_state"

$A4M2_state = Invoke-VmCommand -VmName "KASUTAJA.PEAKONTOR.${CompetitorId}.EESTI.ASI" -User "peakontor\administrator" -UserPwd "Passw0rd!" `
    -Script 'Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"'
if ($A4M2_state -like "*Copilot : 1*") {
    $A4M2_state = 1
}
Invoke-ScoreUpdate -Task "A4.M2" -Result "$A4M2_state"

$A4M3_state = Invoke-VmCommand -VmName "KASUTAJA.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if ((Invoke-WebRequest -Uri http://10.10.10${CompetitorId}.12/ -TimeoutSec 5 -UseBasicParsing).RawContent -Like '*Eesti Asi*') { return 1 } else { return 0 }"
Invoke-ScoreUpdate -Task "A4.M3" -Result "$A4M3_state"

$A4M4_state = Invoke-VmCommand -VmName "KASUTAJA.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if ((Invoke-WebRequest -Uri http://www.peakontor.${CompetitorId}.eesti.asi/ -TimeoutSec 5 -UseBasicParsing).RawContent -Like '*Eesti Asi*') { return 1 } else { return 0 }"
Invoke-ScoreUpdate -Task "A4.M4" -Result "$A4M4_state"

$A4M5_state = Invoke-VmCommand -VmName "KASUTAJA.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if ((Invoke-WebRequest -Uri http://www.harukontor.${CompetitorId}.eesti.asi/ -TimeoutSec 5 -UseBasicParsing).RawContent -Like '*Eesti Asi*') { return 1 } else { return 0 }"
Invoke-ScoreUpdate -Task "A4.M5" -Result "$A4M5_state"

$A4M6_state = Invoke-VmCommand -VmName "KASUTAJA.PEAKONTOR.${CompetitorId}.EESTI.ASI" `
    -Script "if ((Invoke-WebRequest -Uri http://www.nm24.ee/ -TimeoutSec 5 -UseBasicParsing).RawContent -Like '*PEAVAD*') { return 1 } else { return 0 }"
Invoke-ScoreUpdate -Task "A4.M6" -Result "$A4M6_state"
