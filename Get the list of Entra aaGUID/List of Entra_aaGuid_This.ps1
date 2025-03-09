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



# Install required modules if not already installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta.Users)) {
    Install-Module -Name Microsoft.Graph.Beta.Users -Force
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta.Identity.SignIns)) {
    Install-Module -Name Microsoft.Graph.Beta.Identity.SignIns -Force
}

# Import required modules
Import-Module Microsoft.Graph.Beta.Users
Import-Module Microsoft.Graph.Beta.Identity.SignIns

# Disconnect from Microsoft Graph
Disconnect-MgGraph

# Connect to Microsoft Graph with the required scopes (if not already connected)
Connect-MgGraph -Scopes User.Read.All, UserAuthenticationMethod.Read.All, Policy.ReadWrite.AuthenticationMethod

If(!(get-mgcontext | select -ExpandProperty scopes) -contains "Microsoft.Graph.Beta"){
    Write-Host "Connection to Microsoft Graph failed. Please check your credentials and permissions." -ForegroundColor Red
    exit
}

# Output file paths
$detailFile = "C:\Alex\aaGUID\AAGUID_UserDetails.csv"
$Users_numberofaaGUID = "C:\Alex\aaGUID\Users_numberofaaGUID.csv"
$aaguid_Summary = "C:\Alex\aaGUID\aaguid_Summary.csv"

# Retrieve all users
$UserArray = Get-MgBetaUser -All

# Hashtable to summarize AAGUID occurrences
$aaguidUsers = @()

$aaguidAll = @()

foreach ($user in $UserArray) {
    $userUPN = $user.UserPrincipalName
    $userId = $user.Id
    $userDisplayName = $user.DisplayName

    # Retrieve user's FIDO2 authentication methods
    $fidoMethods = Get-MgBetaUserAuthenticationFido2Method -UserId $userId

    if ($fidoMethods) {
        Write-Host "Processing user: $userDisplayName ($userUPN) with FIDO2 methods..." -ForegroundColor Yellow
        foreach ($fido in $fidoMethods) {
            $aaguid = $fido.AaGuid
            $model = $fido.Model
            $display = $fido.DisplayName

            # Append user details to the detail file
            "$userUPN,$userDisplayName,$aaguid,$model" | Out-File -FilePath $detailFile -Append

            $aaguidUsers += [PSCustomObject]@{
                user = $userDisplayName
                UPN = $userUPN
                UserId = $userId
                aaguid = $aaguid
                Name = $display
                Model = $model
            }
            If($aaguidAll -notcontains $aaguid) {
                $aaguidAll += [PSCustomObject]@{
                    aaguid = $aaguid
                    Name = $display
                    Model = $model
                }
            }
        }
    }#else {
     #   Write-Host "No FIDO2 methods found for user: $userDisplayName ($userUPN)" -ForegroundColor Red
   # }
}


### Output the result

# Users with AAGUIDs
Set-Content -Path $detailFile -Value 'User, UPN, UserID,AAGUID,Name,Model'
$aaguidUsers | Export-Csv -Path $detailFile -NoTypeInformation -Append


# Number of AAGUIDs per user
Set-Content -Path $Users_numberofaaGUID -Value 'User,UPN,UserID,Count'
$UsersSummary = @()
$aagrouped = $aaguidUsers | Group-Object user, UPN, UserId
foreach ($group in $aagrouped) {
    $UsersSummary += [PSCustomObject]@{
        User   = $group.Group[0].user
        UPN    = $group.Group[0].UPN
        UserId = $group.Group[0].UserId
        Count  = $group.Count
    }
}

$UsersSummary | Export-Csv -Path $Users_numberofaaGUID -NoTypeInformation -Append

# Number of AAGUIDs per AAGUID
Set-Content -Path $aaguid_Summary -Value 'AAGUID,Model,Count'
$aaGUIDSummary = @()
$aagrouped = $aaguidUsers | Group-Object aaguid, Model
foreach ($group in $aagrouped) {
    $aaGUIDSummary += [PSCustomObject]@{
        AAGUID = $group.Group[0].aaguid
        Model  = $group.Group[0].Model
        Count  = $group.Count
    }
}

# Output the result
$aaGUIDSummary | Export-Csv -Path $aaguid_Summary -NoTypeInformation -Append
Write-Host "Process completed. Files created:\nUser Details: $detailFile\nUsers with AAGUIDs: $Users_numberofaaGUID\nAAGUID Summary: $aaguid_Summary" -ForegroundColor Green

# Disconnect from Microsoft Graph

Clear-Host

Write-Host "Summary of aaGUIDs per user:" -ForegroundColor Green
$UsersSummary

Write-Host "Summary of aaGUIDs:" -ForegroundColor Green
$aaGUIDSummary







