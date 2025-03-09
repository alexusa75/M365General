Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

#Functions
# Function to convert DN to forward format
function Convert-DNToForward {
    param (
        [string]$dn
    )

    if ([string]::IsNullOrEmpty($dn)) {
        return ""
    }

    $dnParts = $dn -split ', ?'
    [array]::Reverse($dnParts)
    return $dnParts -join ','
}

# Function to convert serial number to forward format
function Convert-SerialNumberToForward {
    param (
        [string]$serialNumber
    )

    # Convert to pairs of characters
    $pairs = [Regex]::Matches($serialNumber, '.{2}') | ForEach-Object { $_.Value }
    [array]::Reverse($pairs)
    return ($pairs -join '')
}



# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Certificate Information Viewer"
$form.Size = New-Object System.Drawing.Size(900, 900)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

# Create identity group box
$identityGroupBox = New-Object System.Windows.Forms.GroupBox
$identityGroupBox.Location = New-Object System.Drawing.Point(20, 20)
$identityGroupBox.Size = New-Object System.Drawing.Size(840, 100)
$identityGroupBox.Text = "Identity Information"

# Create Principal Name label and textbox
$principalNameLabel = New-Object System.Windows.Forms.Label
$principalNameLabel.Location = New-Object System.Drawing.Point(20, 30)
$principalNameLabel.Size = New-Object System.Drawing.Size(100, 23)
$principalNameLabel.Text = "Principal Name:"

$principalNameTextBox = New-Object System.Windows.Forms.TextBox
$principalNameTextBox.Location = New-Object System.Drawing.Point(120, 30)
$principalNameTextBox.Size = New-Object System.Drawing.Size(300, 23)

# Create Email label and textbox
$emailLabel = New-Object System.Windows.Forms.Label
$emailLabel.Location = New-Object System.Drawing.Point(440, 30)
$emailLabel.Size = New-Object System.Drawing.Size(50, 23)
$emailLabel.Text = "Email:"

$emailTextBox = New-Object System.Windows.Forms.TextBox
$emailTextBox.Location = New-Object System.Drawing.Point(490, 30)
$emailTextBox.Size = New-Object System.Drawing.Size(300, 23)

# Add controls to identity group box
$identityGroupBox.Controls.AddRange(@($principalNameLabel, $principalNameTextBox, $emailLabel, $emailTextBox))

# Create store location group box
$storeGroupBox = New-Object System.Windows.Forms.GroupBox
$storeGroupBox.Location = New-Object System.Drawing.Point(20, 130)
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
$certificatesGroupBox.Location = New-Object System.Drawing.Point(20, 220)
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
$detailsGroupBox.Location = New-Object System.Drawing.Point(20, 430)
$detailsGroupBox.Size = New-Object System.Drawing.Size(840, 200)
$detailsGroupBox.Text = "Certificate Details"

# Create certificate details text box
$detailsTextBox = New-Object System.Windows.Forms.RichTextBox
$detailsTextBox.Location = New-Object System.Drawing.Point(20, 30)
$detailsTextBox.Size = New-Object System.Drawing.Size(800, 150)
$detailsTextBox.ReadOnly = $true
$detailsTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$detailsTextBox.BackColor = [System.Drawing.Color]::White
$detailsGroupBox.Controls.Add($detailsTextBox)

# Create formatted info group box
$formattedInfoGroupBox = New-Object System.Windows.Forms.GroupBox
$formattedInfoGroupBox.Location = New-Object System.Drawing.Point(20, 640)
$formattedInfoGroupBox.Size = New-Object System.Drawing.Size(840, 200)
$formattedInfoGroupBox.Text = "CBA and altSecurityIdentities Formatted Certificate Information"

# Create formatted info text box
$formattedInfoTextBox = New-Object System.Windows.Forms.RichTextBox
$formattedInfoTextBox.Location = New-Object System.Drawing.Point(20, 30)
$formattedInfoTextBox.Size = New-Object System.Drawing.Size(800, 150)
$formattedInfoTextBox.ReadOnly = $true
$formattedInfoTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$formattedInfoTextBox.BackColor = [System.Drawing.Color]::White
$formattedInfoGroupBox.Controls.Add($formattedInfoTextBox)

# Add controls to form
$form.Controls.AddRange(@($identityGroupBox, $storeGroupBox, $certificatesGroupBox, $detailsGroupBox, $formattedInfoGroupBox))

# Principal Name TextBox change event handler
$principalNameTextBox_TextChanged = {
    if (-not $emailTextBox.Modified) {
        $emailTextBox.Text = $principalNameTextBox.Text
    }
}

# Store location change event handler
$storeComboBox_SelectedIndexChanged = {
    $certificatesListView.Items.Clear()
    $detailsTextBox.Clear()
    $formattedInfoTextBox.Clear()

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
    $formatted = New-Object System.Text.StringBuilder

    # Basic Information
    $details.AppendLine("=== Basic Information ===")
    $details.AppendLine("")
    $details.AppendLine("Subject: $($cert.Subject)")
    $details.AppendLine("")
    $details.AppendLine("Issuer: $($cert.Issuer)")
    $details.AppendLine("")
    $details.AppendLine("Serial Number: $($cert.SerialNumber)")
    $details.AppendLine("")
    $details.AppendLine("Valid From: $($cert.NotBefore.ToString('yyyy-MM-dd HH:mm:ss'))")
    $details.AppendLine("")
    $details.AppendLine("Valid To: $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss'))")
    $details.AppendLine("")
    $details.AppendLine("Thumbprint: $($cert.Thumbprint)")
    $details.AppendLine("")

    # SHA1 Public Key Hash
    $sha1PublicKey = [System.Security.Cryptography.SHA1]::Create().ComputeHash($cert.PublicKey.EncodedKeyValue.RawData)
    $sha1PublicKeyString = [BitConverter]::ToString($sha1PublicKey) -replace '-'
    $details.AppendLine("SHA1 Public Key Hash: $sha1PublicKeyString")
    $details.AppendLine("")

    # Update details text box with bold attributes
    $detailsTextBox.Text = $details.ToString()
    $detailsTextBox.SelectAll()
    $detailsTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10)

    # Make attribute names bold
    $attributeNames = @(
        "=== Basic Information ===",
        "Subject:",
        "Issuer:",
        "Serial Number:",
        "Valid From:",
        "Valid To:",
        "Thumbprint:",
        "SHA1 Public Key Hash:"
    )

    foreach ($attr in $attributeNames) {
        $pos = $detailsTextBox.Find($attr, [System.Windows.Forms.RichTextBoxFinds]::MatchCase)
        if ($pos -ge 0) {
            $detailsTextBox.SelectionStart = $pos
            $detailsTextBox.SelectionLength = $attr.Length
            $detailsTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
        }
    }

    # Formatted Information with spacing
    if ($principalNameTextBox.Text) {
        $formatted.AppendLine("PrincipalName:X509:<PN>$($principalNameTextBox.Text)")
        $formatted.AppendLine("")
    }
    if ($emailTextBox.Text) {
        $formatted.AppendLine("RFC822Name:X509:<RFC822>$($emailTextBox.Text)")
        $formatted.AppendLine("")
    }

    # Format subject and issuer DN
    $issuer = Convert-DNToForward -dn $cert.Issuer
    $subject = Convert-DNToForward -dn $cert.Subject
    $formatted.AppendLine("IssuerAndSubject:X509:<I>$($issuer)<S>$($subject)")
    $formatted.AppendLine("")
    $formatted.AppendLine("Subject:X509:<S>$($subject)")
    $formatted.AppendLine("")

    # Get SKI if available
    $skiExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Key Identifier' }
    if ($skiExt) {
        $ski = ($skiExt.Format($false) -replace '\s+', '')
        $formatted.AppendLine("SKI:X509:<SKI>$ski")
        $formatted.AppendLine("")
    }

    # Add SHA1 Public Key
    $formatted.AppendLine("SHA1PublicKey:X509:<SHA1-PUKEY>$sha1PublicKeyString")
    $formatted.AppendLine("")

    # Add Issuer and Serial Number
    $serial = Convert-SerialNumberToForward -serialNumber $cert.SerialNumber
    $formatted.AppendLine("IssuerAndSerialNumber:X509:<I>$($issuer)<SR>$($serial)")

    # Update formatted info text box with bold attributes
    $formattedInfoTextBox.Text = $formatted.ToString()
    $formattedInfoTextBox.SelectAll()
    $formattedInfoTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10)

    # Make formatted attribute names bold
    $formattedAttrNames = @(
        "PrincipalName:",
        "RFC822Name:",
        "IssuerAndSubject:",
        "Subject:",
        "SKI:",
        "SHA1PublicKey:",
        "IssuerAndSerialNumber:"
    )

    foreach ($attr in $formattedAttrNames) {
        $pos = $formattedInfoTextBox.Find($attr, [System.Windows.Forms.RichTextBoxFinds]::MatchCase)
        if ($pos -ge 0) {
            $formattedInfoTextBox.SelectionStart = $pos
            $formattedInfoTextBox.SelectionLength = $attr.Length
            $formattedInfoTextBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
        }
    }
}

# Add event handlers
$principalNameTextBox.Add_TextChanged($principalNameTextBox_TextChanged)
$storeComboBox.Add_SelectedIndexChanged($storeComboBox_SelectedIndexChanged)
$certificatesListView.Add_SelectedIndexChanged($certificatesListView_SelectedIndexChanged)

# Set initial store selection
$storeComboBox.SelectedIndex = 0

# Show the form
$form.ShowDialog()