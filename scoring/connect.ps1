Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
$Server = 'esx.kehtna.mtk'
if (!(($global:DefaultVIServers).IsConnected -eq "False")) {
    Connect-VIServer -Server ${Server}
}
