Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Certificate Information Viewer"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

# Create store location group box
$storeGroupBox = New-Object System.Windows.Forms.GroupBox
$storeGroupBox.Location = New-Object System.Drawing.Point(20, 20)
$storeGroupBox.Size = New-Object System.Drawing.Size(840, 80)
$storeGroupBox.Text = "Certificate Store Location"

# Create store location combo box
$storeComboBox = New-Object System.Windows.Forms.ComboBox
$storeComboBox.Location = New-Object System.Drawing.Point(20, 30)
$storeComboBox.Size = New-Object System.Drawing.Size(300, 30)
$storeComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$storeComboBox.Items.AddRange(@("Personal (CurrentUser)", "Personal (LocalMachine)"))
$storeGroupBox.Controls.Add($storeComboBox)

# Create certificates group box
$certificatesGroupBox = New-Object System.Windows.Forms.GroupBox
$certificatesGroupBox.Location = New-Object System.Drawing.Point(20, 110)
$certificatesGroupBox.Size = New-Object System.Drawing.Size(840, 200)
$certificatesGroupBox.Text = "Available Certificates"

# Create certificates list view
$certificatesListView = New-Object System.Windows.Forms.ListView
$certificatesListView.Location = New-Object System.Drawing.Point(20, 30)
$certificatesListView.Size = New-Object System.Drawing.Size(800, 150)
$certificatesListView.View = [System.Windows.Forms.View]::Details
$certificatesListView.FullRowSelect = $true
$certificatesListView.GridLines = $true
$certificatesListView.Columns.Add("Subject", 400)
$certificatesListView.Columns.Add("Issuer", 200)
$certificatesListView.Columns.Add("Expiration", 150)
$certificatesGroupBox.Controls.Add($certificatesListView)

# Create certificate details group box
$detailsGroupBox = New-Object System.Windows.Forms.GroupBox
$detailsGroupBox.Location = New-Object System.Drawing.Point(20, 320)
$detailsGroupBox.Size = New-Object System.Drawing.Size(840, 320)
$detailsGroupBox.Text = "Certificate Details"

# Create certificate details text box
$detailsTextBox = New-Object System.Windows.Forms.RichTextBox
$detailsTextBox.Location = New-Object System.Drawing.Point(20, 30)
$detailsTextBox.Size = New-Object System.Drawing.Size(800, 270)
$detailsTextBox.ReadOnly = $true
$detailsTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$detailsTextBox.BackColor = [System.Drawing.Color]::White
$detailsGroupBox.Controls.Add($detailsTextBox)

# Add controls to form
$form.Controls.AddRange(@($storeGroupBox, $certificatesGroupBox, $detailsGroupBox))

# Store location change event handler
$storeComboBox_SelectedIndexChanged = {
    $certificatesListView.Items.Clear()
    $detailsTextBox.Clear()

    $storeLocation = if ($storeComboBox.SelectedIndex -eq 0) {
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    } else {
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    }

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::My,
        $storeLocation
    )

    try {
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        foreach ($cert in $store.Certificates) {
            $item = New-Object System.Windows.Forms.ListViewItem($cert.Subject)
            $item.SubItems.Add($cert.Issuer)
            $item.SubItems.Add($cert.NotAfter.ToString("yyyy-MM-dd"))
            $item.Tag = $cert
            $certificatesListView.Items.Add($item)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error accessing certificate store: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } finally {
        $store.Close()
    }
}

# Certificate selection change event handler
$certificatesListView_SelectedIndexChanged = {
    if ($certificatesListView.SelectedItems.Count -eq 0) {
        return
    }

    $cert = $certificatesListView.SelectedItems[0].Tag
    $details = New-Object System.Text.StringBuilder

    # Format certificate details
    $details.AppendLine("=== Basic Information ===`n")
    $details.AppendLine("Subject: $($cert.Subject)")
    $details.AppendLine("Issuer: $($cert.Issuer)")
    $details.AppendLine("Serial Number: $($cert.SerialNumber)")
    $details.AppendLine("Valid From: $($cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss'))")
    $details.AppendLine("Valid To: $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss'))")
    $details.AppendLine("Thumbprint: $($cert.Thumbprint)")

    # SHA1 Public Key Hash
    $sha1PublicKey = [System.Security.Cryptography.SHA1]::Create().ComputeHash($cert.PublicKey.EncodedKeyValue.RawData)
    $sha1PublicKeyString = [BitConverter]::ToString($sha1PublicKey) -replace '-'
    $details.AppendLine("`nSHA1 Public Key Hash: $sha1PublicKeyString")

    if ($cert.Extensions) {
        $details.AppendLine("`n=== Extensions ===`n")

        # Subject Key Identifier (SKI)
        $skiExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Key Identifier' }
        if ($skiExt) {
            $ski = $skiExt.Format($false)
            $details.AppendLine("Subject Key Identifier (SKI): $($ski.Trim())")
        }

        # Subject Alternative Names (SANs)
        $sanExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }
        if ($sanExt) {
            $san = $sanExt.Format($true)
            $details.AppendLine("`nSubject Alternative Name (SAN):")
            $details.AppendLine($san.Trim())
        }

        # Certificate Policies
        $policyExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Certificate Policies' }
        if ($policyExt) {
            $details.AppendLine("`nCertificate Policies:")
            $policies = $policyExt.Format($true)
            foreach ($line in ($policies -split "`n")) {
                if ($line -match 'Policy Identifier=(.+)') {
                    $details.AppendLine("    Policy OID: $($matches[1])")
                }
            }
        }
    }

    $detailsTextBox.Text = $details.ToString()
}

# Add event handlers
$storeComboBox.Add_SelectedIndexChanged($storeComboBox_SelectedIndexChanged)
$certificatesListView.Add_SelectedIndexChanged($certificatesListView_SelectedIndexChanged)

# Set initial store selection
$storeComboBox.SelectedIndex = 0

# Show the form
$form.ShowDialog()