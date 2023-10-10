# Hieronder define ik de variables die ik gebruik in de script.

param(
    [Parameter(Position = 0)]
    [string]$staticIp = "192.168.1.15",
    [Parameter(Position = 1)]
    [string]$defaultGatewayIp = "192.168.1.1",
    [Parameter(Position = 2)]
    [string]$subnetMask = "24",
    [Parameter(Position = 3)]
    [String[]]$dnsServers = ("127.0.0.1", "8.8.8.8"),
    [Parameter(Position = 4)]
    [string]$domainName = "automation.local",
    [Parameter(Position = 5)]
    [string]$dhcpScopeName = "Automation Scope",
    [Parameter(Position = 6)]
    [string]$dhcpScopeStartRange = "192.168.1.51",
    [Parameter(Position = 7)]
    [string]$dhcpScopeEndRange = "192.168.1.200",
    [Parameter(Position = 8)]
    [string]$dhcpScopeSubnetMask = "255.255.255.0",
    [Parameter(Position = 9)]
    [string]$domainNetBiosName = "automation",
    [Parameter(Position = 10)]
    [string]$passBeforeSecureString = "BrownGreen78!"
)

$ipAddresses = Get-NetIPAddress
$staticIpFound = $ipAddresses | Where-Object { $_.PrefixOrigin -eq 'Manual' }

# Als er een statisch IP is ingesteld dan wordt deze verwijderd en wordt er een DHCP ingesteld.

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

# Pad naar de map waar het script wordt opgeslagen
$folderPath = "C:\ps"

# Hier wordt de inhoud van het script gedefinieerd
$scriptContent = "Add-DhcpServerInDC -DnsName 'automation.local' -IPAddress '$staticIp'" + "`r`n"
$scriptContent += "Start-Sleep -Seconds 20" + "`r`n"
$scriptContent += "Unregister-ScheduledTask -TaskName 'Authorize DHCP' -Confirm:`$false"
# Check if the folder exists, and create it if it doesn't
if (-not (Test-Path -Path $folderPath -PathType Container)) {
    New-Item -Path $folderPath -ItemType Directory
}

# Hier wordt de inhoud van het script opgeslagen in een bestand
$scriptPath = Join-Path -Path $folderPath -ChildPath "authorize.ps1"
$scriptContent | Out-File -FilePath $scriptPath

# Dit is een bericht dat wordt weergegeven als het script is gemaakt
Write-Host "Created the file in $folderPath"

# Om problemen met connectie voorkomen na het instellen van de gegevens zal er 5 seconden worden gewacht.
Start-Sleep -Seconds 5

# Hier onder wordt Chocolatey geinstallleerd. Hiermee kan ik applicaties installeren zoals WinSCP en Firefox.
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable --name=allowGlobalConfirmation

# Hier define ik een list met applicaties die ik wil installeren.
$preInstalledApps = @("winscp", "firefox")

foreach ($preInstalledApp in $preInstalledApps) {
    choco install $preInstalledApp
}

$dhcpRole = Get-WindowsFeature -Name DHCP*

# Hier wordt gekeken of de DHCP role is geinstalleerd. Als dit niet het geval is dan wordt deze geinstalleerd.
if (!$dhcpRole.installed) {
    Write-Host "DHCP role is not installed, installing right now."
    # Install DHCP role
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    # Create DHCP scope
    Add-DhcpServerv4Scope -Name $dhcpScopeName -StartRange $dhcpScopeStartRange -EndRange $dhcpScopeEndRange -SubnetMask $dhcpScopeSubnetMask
    # Remove configuration warning in server manager
    Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2
    # Met de line hierboven zorg ik er voor dat de melding in de server manager weg gaat.
}
else {
    Write-Host "DHCP role is installed"
}

# Hier wordt de DHCP geauthoriseerd, een taak aangemaakt en ADDS geinstalleerd + DNS.
Register-ScheduledTask -TaskName "Authorize DHCP" -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "C:\ps\authorize.ps1") -Trigger (New-ScheduledTaskTrigger -AtLogOn) -User "NT AUTHORITY\SYSTEM" -Force
Start-Sleep -Seconds 5
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
$securePassword = ConvertTo-SecureString -String $passBeforeSecureString -AsPlainText -Force
Install-ADDSForest -DomainName $domainName -DomainNetbiosName $domainNetBiosName -ForestMode default -DomainMode default -NoRebootOnCompletion -SafeModeAdministratorPassword $securePassword -Confirm:$false
Restart-Computer -Force
