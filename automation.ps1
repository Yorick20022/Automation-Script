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
    [string]$domainNetBiosName = "automation"
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

# Define the folder path and script content
$folderPath = "C:\ps"
$scriptContent = 'Add-DhcpServerInDC -DnsName "automation.local" -IPAddress "192.168.1.15"'

# Check if the folder exists, and create it if it doesn't
if (-not (Test-Path -Path $folderPath -PathType Container)) {
    New-Item -Path $folderPath -ItemType Directory
}

# Create the authorize.ps1 script file with the specified content
$scriptPath = Join-Path -Path $folderPath -ChildPath "authorize.ps1"
$scriptContent | Out-File -FilePath $scriptPath

Write-Host "Created the file in $folderPath"

Start-Sleep -Seconds 5

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable --name=allowGlobalConfirmation

$preInstalledApps = @("winscp", "firefox")

foreach ($preInstalledApp in $preInstalledApps) {
    choco install $preInstalledApp
}

$dhcpRole = Get-WindowsFeature -Name DHCP*

if (!$dhcpRole.installed) {
    Write-Host "DHCP role is not installed, installing right now."
    # Install DHCP role
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    # Create DHCP scope
    Add-DhcpServerv4Scope -Name $dhcpScopeName -StartRange $dhcpScopeStartRange -EndRange $dhcpScopeEndRange -SubnetMask $dhcpScopeSubnetMask
    # Remove configuration warning in server manager
    Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2
}
else {
    Write-Host "DHCP role is installed"
}

Register-ScheduledTask -TaskName "Authorize DHCP" -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "C:\ps\authorize.ps1") -Trigger (New-ScheduledTaskTrigger -AtLogOn) -User "NT AUTHORITY\SYSTEM" -Force
Start-Sleep -Seconds 5
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
$securePassword = ConvertTo-SecureString -String "BrownGreen78!" -AsPlainText -Force
Install-ADDSForest -DomainName $domainName -DomainNetbiosName $domainNetBiosName -ForestMode default -DomainMode default -NoRebootOnCompletion -SafeModeAdministratorPassword $securePassword -Confirm:$false
Restart-Computer -Force