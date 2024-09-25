Connect-MgGraph -scopes "Directory.ReadWrite.All, OnPremDirectorySynchronization.ReadWrite.All"
$onPremSync = Get-MgDirectoryOnPremiseSynchronization
$onPremSync.Features.UserForcePasswordChangeOnLogonEnabled = $true
Update-MgDirectoryOnPremiseSynchronization -OnPremisesDirectorySynchronizationId $onPremSync.Id -Features $onPremSync.Features

Get-MgDirectoryOnPremiseSynchronization | fl
(Get-MgDirectoryOnPremiseSynchronization).Features | fl
((Get-MgDirectoryOnPremiseSynchronization).Configuration).AccidentalDeletionPrevention

