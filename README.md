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
