## Automation-Script

You have to do a couple things before you can successfully run this script:

- Give the server a hostname
- Give the Admin account a strong password
- Make sure the user you are using has administrator permissions

## Hostname change:

```
Rename-Computer -NewName "WhateverYouWant"
```

## Set a strong password for the user:

```
$adminPassword = ConvertTo-SecureString -String "BrownGreen78!" -AsPlainText -Force
Set-LocalUser -Name "Administrator" -Password $adminPassword
```

## What does it do?

- Sets static IP + DNS
- Creates a directory + a file for the autorization of DHCP
- Installs WinSCP and Firefox using Chocolatey
- Installs DHCP
- Registers a scheduled task that runs without terminal to trigger DHCP authorization
- Install ADDS, DNS and promotes to Domain Controller
