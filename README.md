# Assign Licenses Script

This script will help you to assign licenses in M365 using Microsoft Graph SDK

You need to install Microsoft.Graph Powershell Module:

```Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber -Force```

You need to manually assign the licenses to one user and then the script will assign those license to the users that are part of the csv file you need to create, the csv file must has the following format:

`UserPrincipalName, DisplayName`

You have to open the script and enter the right values to the following variables:
```powershell
$csv = <csv_file_path>
$usermodel = user@domain.com #This is the user you assigned the licenses manually

```

