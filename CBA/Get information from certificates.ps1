# Load the necessary assembly for X509 certificates
Add-Type -AssemblyName System.Security

# Present a menu for the store location and get the user's choice
Write-Host "Select the certificate store location:" -ForegroundColor Cyan
Write-Host "1 - Personal (CurrentUser)"
Write-Host "2 - Machine (LocalMachine)"
$storeLocationChoice = Read-Host "Enter your choice (1 or 2)"

# Determine the store location based on user input
$storeLocation = switch ($storeLocationChoice) {
    "1" { [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser }
    "2" { [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine }
    default {
        Write-Host "Invalid input. Defaulting to CurrentUser." -ForegroundColor Yellow
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    }
}

# Specify the certificate store name
$storeName = [System.Security.Cryptography.X509Certificates.StoreName]::My

# Create a new X509 store object and open it
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, $storeLocation)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

try {
    # Check if there are any certificates
    if ($store.Certificates.Count -eq 0) {
        Write-Host "No certificates found in the selected store." -ForegroundColor Red
        return
    }

    # List all certificates and let the user choose one
    Write-Host "`nAvailable certificates:" -ForegroundColor Green
    for ($i = 0; $i -lt $store.Certificates.Count; $i++) {
        $cert = $store.Certificates[$i]
        $friendlyName = if ($cert.FriendlyName) { $cert.FriendlyName } else { "<No Friendly Name>" }
        Write-Host ("    [{0}] {1} - {2}" -f $i, $cert.Subject, $friendlyName) -ForegroundColor Yellow
    }

    Write-Host "`nEnter the index of the certificate to display details: " -ForegroundColor Green -NoNewline
    $selectedCertIndex = Read-Host

    # Validate user input
    if ($selectedCertIndex -match '^\d+$' -and [int]$selectedCertIndex -lt $store.Certificates.Count) {
        $selectedCert = $store.Certificates[[int]$selectedCertIndex]

        Write-Host "`nCertificate Details:" -ForegroundColor Cyan
        Write-Host "===================" -ForegroundColor Cyan

        # SHA1 Public Key Hash
        $sha1PublicKey = [System.Security.Cryptography.SHA1]::Create().ComputeHash($selectedCert.PublicKey.EncodedKeyValue.RawData)
        $sha1PublicKeyString = [BitConverter]::ToString($sha1PublicKey) -replace '-'
        Write-Host "SHA1 Public Key Hash: " -NoNewline
        Write-Host $sha1PublicKeyString -ForegroundColor White

        if ($selectedCert.Extensions) {
            # Subject Key Identifier (SKI)
            $skiExt = $selectedCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Key Identifier' }
            if ($skiExt) {
                $ski = $skiExt.Format($false)
                Write-Host "Subject Key Identifier (SKI): " -NoNewline
                Write-Host $ski.Trim() -ForegroundColor White
            } else {
                Write-Host "Subject Key Identifier (SKI): " -NoNewline
                Write-Host "Not Present" -ForegroundColor Red
            }

            # Subject Alternative Names (SANs)
            $sanExt = $selectedCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }
            if ($sanExt) {
                $san = $sanExt.Format($true)
                Write-Host "Subject Alternative Name (SAN): " -NoNewline
                Write-Host $san.Trim() -ForegroundColor White
            } else {
                Write-Host "Subject Alternative Name (SAN): " -NoNewline
                Write-Host "Not Present" -ForegroundColor Red
            }
        }

        # Basic certificate information
        Write-Host "Subject: " -NoNewline
        Write-Host $selectedCert.Subject -ForegroundColor White

        Write-Host "Issuer: " -NoNewline
        Write-Host $selectedCert.Issuer -ForegroundColor White

        Write-Host "Serial Number: " -NoNewline
        Write-Host $selectedCert.SerialNumber -ForegroundColor White

        Write-Host "Valid From: " -NoNewline
        Write-Host $selectedCert.NotBefore.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White

        Write-Host "Valid To: " -NoNewline
        Write-Host $selectedCert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White

        Write-Host "Thumbprint: " -NoNewline
        Write-Host $selectedCert.Thumbprint -ForegroundColor White
    } else {
        Write-Host "Invalid certificate selection." -ForegroundColor Red
    }
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Close the store
    $store.Close()
}