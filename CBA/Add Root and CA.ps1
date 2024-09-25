Install-Module -Name AzureAD -RequiredVersion 2.0.0.33

Connect-AzureAD

Get-AzureADTrustedCertificateAuthority

$cert=Get-Content -Encoding byte "C:\Users\john\Documents\savilltechrootca.cer"
$new_ca=New-Object -TypeName Microsoft.Open.AzureAD.Model.CertificateAuthorityInformation
$new_ca.AuthorityType=0 #root CA
$new_ca.TrustedCertificate=$cert
$new_ca.crlDistributionPoint="<CRL Distribution URL>"
New-AzureADTrustedCertificateAuthority -CertificateAuthorityInformation $new_ca

Get-AzureADTrustedCertificateAuthority




