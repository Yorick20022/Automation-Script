param(
    [Parameter(Position = 0)]
    [string]$staticIp = "192.168.1.15",
    [Parameter(Position = 1)]
    [string]$defaultGatewayIp = "192.168.1.1",
    [Parameter(Position = 2)]
    [string]$subnetMask = "24",
    [Parameter(Position = 3)]
    [string]$dnsServers = "127.0.0.1, 8.8.8.8"
)

$ipAddresses = Get-NetIPAddress
$staticIpFound = $ipAddresses | Where-Object { $_.PrefixOrigin -eq 'Manual' }

if ($staticIpFound) {
    Write-Output "The computer has an existing network configuration, I will remove it"
    $adapterIndex = (Get-NetAdapter).InterfaceIndex
    Remove-NetRoute -InterfaceIndex $adapterIndex -DestinationPrefix 0.0.0.0/0 -Confirm:$false
    $networkAdapterName = "Ethernet0"  
    $networkAdapter = Get-NetAdapter | Where-Object { $_.Name -eq $networkAdapterName }
    $ifIndex = $networkAdapter.ifIndex
    Set-NetIPInterface -InterfaceIndex $ifIndex -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ResetServerAddresses
}
else {
    Write-Output "The computer does not have a static IP address. I will add it for you."
    New-NetIPAddress –IPAddress $staticIp -DefaultGateway $defaultGatewayIp -PrefixLength 24 -InterfaceIndex (Get-NetAdapter).InterfaceIndex -Confirm:$false
    Set-DNSClientServerAddress –InterfaceIndex (Get-NetAdapter).InterfaceIndex –ServerAddresses $dnsServers -Confirm:$false
    Write-Output "Done configuring network settings"
}

Start-Sleep -Seconds 5

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable --name=allowGlobalConfirmation

$preInstalledApps = @("winscp", "firefox")

foreach($preInstalledApp in $preInstalledApps) 
{
choco install $preInstalledApp
}

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
$securePassword = ConvertTo-SecureString -String "BrownGreen78!" -AsPlainText -Force
Install-ADDSForest -DomainName automation.local -DomainNetbiosName automation -ForestMode default -DomainMode default -NoRebootOnCompletion -SafeModeAdministratorPassword $securePassword -Confirm:$false
Restart-Computer -Force