###########################################################################
# The sample scripts are not supported under any Microsoft standard support
# program or service. The sample scripts are provided AS IS without warranty
# of any kind. Microsoft further disclaims all implied warranties including,
# without limitation, any implied warranties of merchantability or of fitness
# for a particular purpose. The entire risk arising out of the use or
# performance of the sample scripts and documentation remains with you. In no
# event shall Microsoft, its authors, or anyone else involved in the creation,
# production, or delivery of the scripts be liable for any damages whatsoever
# (including, without limitation, damages for loss of business profits,
# business interruption, loss of business information, or other pecuniary
# loss) arising out of the use of or inability to use the sample scripts or
# documentation, even if Microsoft has been advised of the possibility of such
# damages.
############################################################################



# This script is designed to update the AAGUIDs in the FIDO2 authentication method configuration in Microsoft Entra ID (Azure AD).
# Parameters:
[CmdletBinding()]
param (
    [string]$aaguidFilePath = "C:\Alex\aaGUID\aaguid_Summary.csv"
)


# Function to upload AAGUIDs to the FIDO2 authentication method configuration
Function upload-aaGUIDs {
    param (
        [array]$aaGUIDSummary
    )
    $result = $false
    # Extract just the AAGUIDs from your summary variable
    $aaGuidsToAdd = $aaGUIDSummary | Select-Object -ExpandProperty AAGUID

    # First get the current configuration to preserve existing AAGUIDs
    $currentConfig = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/authenticationMethodsPolicy/authenticationMethodConfigurations/FIDO2"

    # Extract current AAGUIDs
    $currentAaGuids = $currentConfig.keyRestrictions.aaGuids

    # Combine current and new AAGUIDs, removing any duplicates
    $allAaGuids = ($currentAaGuids + $aaGuidsToAdd) | Select-Object -Unique
    $allAaGuids = $allAaGuids | ForEach-Object { $_.ToString() }

    # Prepare the request body
    $requestBody = @{
        "@odata.type" = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
        "isAttestationEnforced" = $true
        "keyRestrictions" = @{
            "isEnforced" = $true
            "enforcementType" = "allow"
            "aaGuids" = $allAaGuids
        }
    }

    # Convert to JSON
    $jsonBody = $requestBody | ConvertTo-Json -Depth 10

    # Update the configuration
    try {
        $updateResult = Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/authenticationMethodsPolicy/authenticationMethodConfigurations/FIDO2" -Body $requestBody
        $result = $true
        Write-Host "Successfully updated FIDO2 configuration with the following AAGUIDs:" -ForegroundColor Yellow
        $allAaGuids | ForEach-Object {
            Write-Host "    - $_" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Failed to update FIDO2 configuration: $_"
        if ($_.Exception.Response) {
            Write-Error $_.Exception.Response
        }
    }
    return $result
}

# Main script execution
# Check if the file exists  before attempting to Import-Csv
if (-not (Test-Path -Path $aaguidFilePath)) {
    Write-Host "The specified file does not exist: $aaguidFilePath" -ForegroundColor Red
    exit
}


# Install required modules if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force
}

# Import required modules
Import-Module Microsoft.Graph.Authentication

# Disconnect from Microsoft Graph
Disconnect-MgGraph

# Connect to Microsoft Graph with the required scopes (if not already connected)
Connect-MgGraph -Scopes User.Read.All, UserAuthenticationMethod.Read.All, Policy.ReadWrite.AuthenticationMethod, Policy.Read.All -NoWelcome

If(!(get-mgcontext | select -ExpandProperty scopes) -contains "Policy.ReadWrite.AuthenticationMethod"){
    Write-Host "Connection to Microsoft Graph failed. Please check your credentials and permissions." -ForegroundColor Red
    exit
}

# Import the CSV file containing the AAGUIDs and models
# Assuming the CSV has headers "aaguid" and "Model"
$aaGUIDSummary = Import-Csv -Path $aaguidFilePath -Delimiter "," | Select-Object -Property aaguid, Model

upload-aaGUIDs -aaGUIDSummary $aaGUIDSummary

Write-Host "AAGUIDs have been successfully uploaded to the FIDO2 authentication method configuration." -ForegroundColor Green
# Disconnect from Microsoft Graph
