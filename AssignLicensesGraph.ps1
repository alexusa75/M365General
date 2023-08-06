$DesktopPath = [Environment]::GetFolderPath("Desktop")
$outpath = 	$DesktopPath + "\assigned licenses.csv"
$csv = "D:\OneDrive_Microsoft\OneDrive - Microsoft\MWA\PS\UsersToLicense.csv"
$usermodel = 'test1@cubao365.com'

#Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber -Force
#Get-InstalledModule Microsoft.Graph

###############
#  Functions  #
###############
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $True)]
        [string]
        $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    #$Line = $Stamp + "," + $Level + "," + $Message
    $csvobject = New-Object system.collections.arraylist
    $csvobject = "" | Select-Object DateTime, Level, Message
    If(!(Test-Path $logfile)){$csvobject | Export-Csv $logfile -NoTypeInformation}
    $csvobject.DateTime = $Stamp
    $csvobject.Level = $Level
    $csvobject.Message = $Message
    $csvobject | Export-Csv $logfile -Append -NoTypeInformation

}

function Show-ProgressBar {
    param (
        [int]$PercentComplete,
        [string]$status
    )
    $ProgressBarLength = 50
    $CompletedLength = [math]::Round(($ProgressBarLength * $PercentComplete) / 100)
    $RemainingLength = $ProgressBarLength - $CompletedLength

    $ProgressBar = "[" + "-" * $CompletedLength + (" " * $RemainingLength) + "]"

    Write-Host "`r$ProgressBar $PercentComplete% Complete, --> $($status)" -NoNewline
}


Connect-MgGraph -Scopes "Directory.ReadWrite.All", "User.ReadWrite.All"
Select-MgProfile -Name beta

$usermodel = Get-MgUserLicenseDetail -UserId $usermodel
#| Where SkuPartNumber -eq 'ENTERPRISEPREMIUM'
if(Test-Path $csv){
    $userscvs = Import-Csv -Path $csv
}else{
    Write-Host "No csv found" -ForegroundColor Red -BackgroundColor Yellow
    Exit
}

$Totalusers = $userscvs.count
$c = 0
######## Thisss  ############

$addLicenses = @()
$licensescheck = @()

### Get All licenses assgned to the model user
ForEach ($lic in $usermodel) {
    $licensescheck += $lic.SkuId
    $addLicenses += @{
        "disabledPlans" = @($lic.ServicePlans | Where-Object { $_.ProvisioningStatus -eq "Disabled" }).ServicePlanId
        "skuId" = $lic.SkuId
    }
}

## Check if there are enough licenses to assign

$tenantId = (Get-MgOrganization).Id

ForEach($lischeck in $licensescheck){
    $tenantLic = Get-MgSubscribedSku -SubscribedSkuId "$($tenantId)_$lischeck" | Select AppliesTo, CapabilityStatus, ConsumedUnits, SkuId, SkuPartNumber
    $LicAssigned = $tenantLic.ConsumedUnits
    $TotalLicenses = (Get-MgSubscribedSku -SubscribedSkuId "$($tenantId)_$lischeck").PrepaidUnits.Enabled
    $available = $TotalLicenses - $LicAssigned
    If($available -lt $Totalusers){
        $text = "There are not enough licenses, Sku: $($tenantLic.SkuPartNumber), available:$available, and you want to assign $Totalusers `n`n If the user already has the license, it will check if any services need to be disabled, and if so, it will apply the changes. `n
        If the user does not have a license, the script will assign licenses until there are available licenses for the desired SKU."
        $UserResponse= [System.Windows.Forms.MessageBox]::Show($text , "Not enough licenses")
    }
}

ForEach($user in $userscvs){
    $c++
    #Write-Host "User $($user.UserPrincipalName)`n" -ForegroundColor Yellow -NoNewline
    $null = Set-MgUserLicense -UserId $user.UserPrincipalName -AddLicenses $addLicenses -RemoveLicenses @()
    $porc = [math]::Round(($c / $Totalusers) * 100)
    Show-ProgressBar -PercentComplete $porc -status "$($user.UserPrincipalName)"
    Start-Sleep -Milliseconds 10
}
Write-Host



<#

ForEach($lic in $usermodel){
    #Write-Progress -Activity "$($lic.)"
    $disableplans = ($lic.ServicePlans | where ProvisioningStatus -eq "Disabled" | select ServicePlanId).ServicePlanId
    $addLicenses = @(
        @{
            SkuId = $lic.SkuId
            DisabledPlans = $disableplans
        }
    )

    ForEach($user in $userscvs){
        Set-MgUserLicense -UserId $user.UserPrincipalName -AddLicenses $addLicenses -RemoveLicenses @()
    }

}

$LicenseParams = @{
    AddLicenses = @(
        @{
            DisabledPlans = @()
            SkuId = "4016f256-b063-4864-816e-d818aad600c9"
        }
        @{
            DisabledPlans = @()
            SkuId = "a403ebcc-fae0-4ca2-8c8c-7a907fd6c235"
        }
    )
    RemoveLicenses = @(
    )
}
Set-MgUserLicense -UserId John.West@office365itpros.com -BodyParameter $LicenseParams


#Remove licenses
$LicenseParams = @{
    AddLicenses = @()
    RemoveLicenses = @(
        "a403ebcc-fae0-4ca2-8c8c-7a907fd6c235"
        "4016f256-b063-4864-816e-d818aad600c9"  )
}
Set-MgUserLicense -UserId John.West@office365itpros.com -BodyParameter $LicenseParams



Set-MgUserLicense -UserId "test2@cubao365.com" -AddLicenses $addLicenses -RemoveLicenses @()

Get-MgSubscribedSku -All | Where SkuPartNumber -eq 'ENTERPRISEPREMIUM' |  select -ExpandProperty ServicePlans


$userDisabledPlans = $usermodel.ServicePlans | `
    Where ProvisioningStatus -eq "Disabled" | `
    Select -ExpandProperty ServicePlanId | select -Unique


($usermodel[0].ServicePlans | where ProvisioningStatus -eq "Disabled" | select ServicePlanId).ServicePlanId

#>