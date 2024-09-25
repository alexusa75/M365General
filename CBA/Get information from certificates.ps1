# Load the necessary assembly for X509 certificates
Add-Type -AssemblyName System.Security

# Present a menu for the store location and get the user's choice
Write-Host "Select the certificate store location:"
Write-Host "1 - Personal"
Write-Host "2 - Machine"
$storeLocationChoice = Read-Host "Enter 1 for Personal (CurrentUser) or 2 for Machine (LocalMachine)"

# Determine the store location based on user input
switch ($storeLocationChoice) {
    "1" { $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser }
    "2" { $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine }
    default {
        Write-Host "Invalid input. Defaulting to CurrentUser."
        $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    }
}

# Specify the certificate store name
$storeName = [System.Security.Cryptography.X509Certificates.StoreName]::My

# Create a new X509 store object and open it
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, $storeLocation)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

# List all certificates and let the user choose one
Write-Host "Available certificates:" -ForegroundColor Green
for ($i = 0; $i -lt $store.Certificates.Count; $i++) {
    $cert = $store.Certificates[$i]
    Write-Host "    $($i): $($cert.Subject) - $($cert.FriendlyName)" -ForegroundColor Yellow
}
Write-Host "Enter the index of the certificate to display details: " -ForegroundColor Green -NoNewline
$selectedCertIndex = Read-Host #"Enter the index of the certificate to display details"
$selectedCert = $store.Certificates[$selectedCertIndex]

# Display the selected certificate's details
if ($selectedCert -ne $null) {
    # SHA1 Public Key Hash
    $sha1PublicKey = [System.Security.Cryptography.SHA1]::Create().ComputeHash($selectedCert.PublicKey.EncodedKeyValue.RawData)
    $sha1PublicKeyString = [BitConverter]::ToString($sha1PublicKey) -replace '-'
    Write-Output "SHA1 Public Key Hash: $sha1PublicKeyString"

    If($selectedCert.Extensions -ne $null){
        # Subject Key Identifier (SKI)
        $ski = ($selectedCert.Extensions | Where-Object {$_.Oid.FriendlyName -eq 'Subject Key Identifier'}).Format(0) | Out-Null
        If($ski -ne $null){
            Write-Output "Subject Key Identifier (SKI): $ski"
        }Else{
            Write-Host "No SKI" -ForegroundColor Red
        }

        # Subject Alternative Names (SANs)
        $san = ($selectedCert.Extensions | Where-Object {$_.Oid.FriendlyName -eq 'Subject Alternative Name'}).Format(1) | Out-Null
        If($san -ne $null){
            Write-Output "Subject Alternative Name (SAN): $san"
        }else{
            Write-Host "No Subject Alternative Name" -ForegroundColor Red
        }
    }else{
        Write-Host "No SKI" -ForegroundColor Red
        Write-Host "No Subject Alternative Name" -ForegroundColor Red
    }


    # Subject
    Write-Output "Subject: $($selectedCert.Subject)"

    # Issuer
    Write-Output "Issuer: $($selectedCert.Issuer)"

    # Serial Number
    Write-Output "Serial Number: $($selectedCert.SerialNumber)"
} else {
    Write-Host "Invalid certificate selection."
}

# Close the store
$store.Close()
