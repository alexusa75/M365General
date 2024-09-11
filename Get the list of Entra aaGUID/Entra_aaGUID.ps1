
##################
#  Entra aaGUID  #
##################

Connect-MgGraph -Scopes "AuditLog.Read.All", "UserAuthenticationMethod.Read.All"

$csvoutput = "c:\alex\EntraPassKeysaaGUID.csv"
$Results = @()

$PasskeyUsers = Invoke-MgGraphRequest -Method GET `
-Uri "beta/reports/authenticationMethods/userRegistrationDetails?`$filter=methodsRegistered/any(i:i eq 'passKeyDeviceBound') OR methodsRegistered/any(i:i eq 'passKeyDeviceBoundAuthenticator')" `
-OutputType PSObject | Select -expand Value

Foreach ($user in $PasskeyUsers) {
    $passkey = Invoke-MgGraphRequest -Method GET -Uri "beta/users/$($user.id)/authentication/fido2Methods" -OutputType PSObject | Select -Expand Value
    $obj = [PSCustomObject][ordered]@{
        "User" = $user.UserPrincipalName
        "Passkey" = $passkey.displayName
        "Model" = $passkey.model
        "aaGuid" = $passkey.aaGuid
        "Date created" = $passkey.createdDateTime
    }
    $Results += $obj
}

$Results | Export-Csv -Path c:\alex\EntraPassKeysaaGUID.csv -NoTypeInformation