[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$csv = "D:\OneDrive_Microsoft\OneDrive - Microsoft\MWA\PS\UsersToLicense.csv",
    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [string]$usermodel= 'alextech2@alextech.us',
    [Parameter(Mandatory = $false)]
    [ValidateNotNullorEmpty()]
    [string]$OutputLogs = [Environment]::GetFolderPath("Desktop") + "\Logs_" + [DateTime]::Now.ToString("yyyy_MM_dd_HH_mm_ss") + ".csv"
)

Add-Type -AssemblyName System.Windows.Forms

$DesktopPath = [Environment]::GetFolderPath("Desktop")
#$outpath = 	$DesktopPath + "\Logs_" + [DateTime]::Now.ToString("yyyy_MM_dd_HH_mm_ss") + ".csv"
#$csv = "D:\OneDrive_Microsoft\OneDrive - Microsoft\MWA\PS\UsersToLicense.csv"
#$usermodel = 'test1@cubao365.com'

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

function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        $ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "PowerShell"
    $Toast.Group = "PowerShell"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
    $Notifier.Show($Toast);
}

function Show-MessageBoxWithButton {
    param (
        [string]$Message,
        [string]$Title = "Message",
        [string]$ButtonCaption = "OK",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OKCancel, $Icon)

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selected = "OK"
    } else {
        $selected = "Cancel"
    }

    return $selected
}

Connect-MgGraph -Scopes "Directory.ReadWrite.All", "User.ReadWrite.All" -NoWelcome
#Get-MgContext
#Select-MgProfile -Name beta --> This is not used anymore

#Validate if user model has a license
try {
    $userlic = Get-MgUserLicenseDetail -UserId $usermodel -ErrorAction Stop
    If(!$userlic){
        Write-Host "The user model doesn't have any license" -ForegroundColor Red -BackgroundColor Yellow
        Exit
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log -Message "Error: $($_.Exception.Message)" -Level ERROR -logfile $OutputLogs
}

#$userlic = Get-MgUserLicenseDetail -UserId $usermodel

# Import csv with users' UPN
if(Test-Path $csv){
    $userscvs = Import-Csv -Path $csv
}else{
    Write-Host "No csv found" -ForegroundColor Red -BackgroundColor Yellow
    Write-Log -Message "Error: $($_.Exception.Message)" -Level ERROR -logfile $OutputLogs
    Exit
}

$Totalusers = $userscvs.count
$c = 0

$addLicenses = @()
$licensescheck = @()

### Get All licenses assgned to the model user
ForEach ($lic in $userlic) {
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
        $selected = Show-MessageBoxWithButton -Title "Not enough licenses" -Message $text
        If($selected -eq "Cancel"){
            exit
            Write-Log -Message "No enough licenses desided to Cancel" -Level FATAL -logfile $OutputLogs
        }
        #$UserResponse= [System.Windows.Forms.MessageBox]::Show($text , "Not enough licenses")
    }
}

ForEach($user in $userscvs){
    $c++
    #Write-Host "User $($user.UserPrincipalName)`n" -ForegroundColor Yellow -NoNewline
    try {
        $porc = [math]::Round(($c / $Totalusers) * 100)
        Show-ProgressBar -PercentComplete $porc -status "$($user.UserPrincipalName)"
        Start-Sleep -Milliseconds 10
        $null = Set-MgUserLicense -UserId $user.UserPrincipalName -AddLicenses $addLicenses -RemoveLicenses @() -ErrorAction Stop
    }
    catch {
        Write-Log -Message "User: $($user.UserPrincipalName) Error: $($_.Exception.Message)" -Level ERROR -logfile $OutputLogs
    }

}


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


# Remove and Assign licenses at the same time

$LicenseParams = @{
    AddLicenses = @(
        @{
            DisabledPlans = @()
            SkuId = "b05e124f-c7cc-45a0-a6aa-8cf78c946968"
        }
        @{
            DisabledPlans = @()
            SkuId = "dcb1a3ae-b33f-4487-846a-a640262fadf4"
        }
    )
    RemoveLicenses = @(
        "efccb6f7-5641-4e0e-bd10-b4976e1bf68e"
    )
}
Set-MgUserLicense -UserId "deleteme2@alextech.us" -BodyParameter $LicenseParams




Get-MgSubscribedSku -All | Where SkuPartNumber -eq 'ENTERPRISEPREMIUM' |  select -ExpandProperty ServicePlans


$userDisabledPlans = $usermodel.ServicePlans | `
    Where ProvisioningStatus -eq "Disabled" | `
    Select -ExpandProperty ServicePlanId | select -Unique


($usermodel[0].ServicePlans | where ProvisioningStatus -eq "Disabled" | select ServicePlanId).ServicePlanId

#>

