Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ======================
# FORM SETUP
# ======================
$form = New-Object System.Windows.Forms.Form
$form.Text = "GUI xcopy File Copier"
$form.Size = New-Object System.Drawing.Size(550, 700)
$form.StartPosition = "CenterScreen"

# ======================
# LABELS
# ======================
$label = New-Object System.Windows.Forms.Label
$label.Text = "Select source folder and destinations:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($label)

# ======================
# SOURCE FOLDER PICKER
# ======================
$sourceLabel = New-Object System.Windows.Forms.Label
$sourceLabel.Text = "Source folder:"
$sourceLabel.Location = New-Object System.Drawing.Point(20, 50)
$sourceLabel.AutoSize = $true
$form.Controls.Add($sourceLabel)

$sourceTextBox = New-Object System.Windows.Forms.TextBox
$sourceTextBox.Location = New-Object System.Drawing.Point(120, 45)
$sourceTextBox.Size = New-Object System.Drawing.Size(300, 20)
$sourceTextBox.Text = "SOURCE_DIR"
$form.Controls.Add($sourceTextBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = New-Object System.Drawing.Point(430, 43)
$browseButton.Size = New-Object System.Drawing.Size(80, 25)
$form.Controls.Add($browseButton)

$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $sourceTextBox.Text = $folderBrowser.SelectedPath
    }
})

# ======================
# CREDENTIALS OPTION
# ======================
$credCheckBox = New-Object System.Windows.Forms.CheckBox
$credCheckBox.Text = "Use different credentials"
$credCheckBox.Location = New-Object System.Drawing.Point(20, 75)
$credCheckBox.AutoSize = $true
$form.Controls.Add($credCheckBox)

# Username
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = "Username:"
$userLabel.Location = New-Object System.Drawing.Point(40, 100)
$userLabel.AutoSize = $true
$form.Controls.Add($userLabel)

$userTextBox = New-Object System.Windows.Forms.TextBox
$userTextBox.Location = New-Object System.Drawing.Point(120, 95)
$userTextBox.Size = New-Object System.Drawing.Size(200, 20)
$userTextBox.Enabled = $false
$form.Controls.Add($userTextBox)

# Password
$passLabel = New-Object System.Windows.Forms.Label
$passLabel.Text = "Password:"
$passLabel.Location = New-Object System.Drawing.Point(40, 125)
$passLabel.AutoSize = $true
$form.Controls.Add($passLabel)

$passTextBox = New-Object System.Windows.Forms.TextBox
$passTextBox.Location = New-Object System.Drawing.Point(120, 120)
$passTextBox.Size = New-Object System.Drawing.Size(200, 20)
$passTextBox.UseSystemPasswordChar = $true
$passTextBox.Enabled = $false
$form.Controls.Add($passTextBox)

$credCheckBox.Add_CheckedChanged({
    $userTextBox.Enabled = $credCheckBox.Checked
    $passTextBox.Enabled = $credCheckBox.Checked
})

# ======================
# DESTINATION CHECKBOXES (Scrollable)
# ======================
$checkboxGroup = New-Object System.Windows.Forms.GroupBox
$checkboxGroup.Text = "Destinations"
$checkboxGroup.Location = New-Object System.Drawing.Point(20, 160)
$checkboxGroup.Size = New-Object System.Drawing.Size(490, 220)
$form.Controls.Add($checkboxGroup)

# Scroll panel for checkboxes
$scrollPanel = New-Object System.Windows.Forms.Panel
$scrollPanel.Location = New-Object System.Drawing.Point(10, 20)
$scrollPanel.Size = New-Object System.Drawing.Size(470, 150)
$scrollPanel.AutoScroll = $true
$checkboxGroup.Controls.Add($scrollPanel)

# Select/Unselect all buttons
$selectAllButton = New-Object System.Windows.Forms.Button
$selectAllButton.Text = "Select All"
$selectAllButton.Location = New-Object System.Drawing.Point(10, 175)
$selectAllButton.Size = New-Object System.Drawing.Size(100, 25)
$checkboxGroup.Controls.Add($selectAllButton)

$unselectAllButton = New-Object System.Windows.Forms.Button
$unselectAllButton.Text = "Unselect All"
$unselectAllButton.Location = New-Object System.Drawing.Point(120, 175)
$unselectAllButton.Size = New-Object System.Drawing.Size(100, 25)
$checkboxGroup.Controls.Add($unselectAllButton)

# Destinations list
$destinations = @{
    "Destination 1" = "\\IP\share"
}

$checkboxes = @()
$y = 10
foreach ($key in $destinations.Keys) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $key
    $cb.Location = New-Object System.Drawing.Point(10, $y)
    $cb.AutoSize = $true
    $scrollPanel.Controls.Add($cb)
    $checkboxes += $cb
    $y += 25
}

# Button actions
$selectAllButton.Add_Click({ foreach ($cb in $checkboxes) { $cb.Checked = $true } })
$unselectAllButton.Add_Click({ foreach ($cb in $checkboxes) { $cb.Checked = $false } })

# ======================
# PROGRESS BAR + LABEL
# ======================
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 390)
$progressBar.Size = New-Object System.Drawing.Size(490, 30)
$form.Controls.Add($progressBar)

$progressLabel = New-Object System.Windows.Forms.Label
$progressLabel.Text = "Progress: 0%"
$progressLabel.Location = New-Object System.Drawing.Point(20, 430)
$progressLabel.AutoSize = $true
$form.Controls.Add($progressLabel)

# ======================
# LOG BOX
# ======================
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Size = New-Object System.Drawing.Size(490, 200)
$logBox.Location = New-Object System.Drawing.Point(20, 460)
$form.Controls.Add($logBox)

# ======================
# BUTTONS
# ======================
$copyButton = New-Object System.Windows.Forms.Button
$copyButton.Text = "Start Copy"
$copyButton.Location = New-Object System.Drawing.Point(20, 670)
$copyButton.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($copyButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Location = New-Object System.Drawing.Point(410, 670)
$closeButton.Size = New-Object System.Drawing.Size(100, 30)
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

# ======================
# COPY LOGIC
# ======================
$copyButton.Add_Click({

    $selectedDests = @()
    foreach ($cb in $checkboxes) {
        if ($cb.Checked) { $selectedDests += $destinations[$cb.Text] }
    }

    if ($selectedDests.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one destination.","No Destination Selected","OK","Warning")
        return
    }

    $sourceFolder = $sourceTextBox.Text
    if (-not (Test-Path $sourceFolder)) {
        [System.Windows.Forms.MessageBox]::Show("Source folder not found!","Error","OK","Error")
        return
    }

    # Create credential object if needed
    if ($credCheckBox.Checked) {
        $securePass = ConvertTo-SecureString $passTextBox.Text -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($userTextBox.Text, $securePass)
    } else {
        $cred = $null
    }

    $copyButton.Enabled = $false
    $progressBar.Value = 0
    $progressLabel.Text = "Progress: 0%"
    $logBox.Clear()

    $files = Get-ChildItem -Path $sourceFolder -File
    $fileCount = $files.Count
    if ($fileCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No files found in source folder.","Empty Folder","OK","Warning")
        $copyButton.Enabled = $true
        return
    }

    $totalSteps = $fileCount * $selectedDests.Count
    $step = 0

    foreach ($dest in $selectedDests) {
        $logBox.AppendText("Copying to $dest ...`r`n")
        foreach ($file in $files) {
            try {
                $sourcePath = $file.FullName
                $destPath = Join-Path $dest $file.Name

                # Copy with progress per file
                $fileStream = [System.IO.File]::OpenRead($sourcePath)
                $destStream = [System.IO.File]::Create($destPath)
                $buffer = New-Object byte[] 8192
                $totalBytes = $fileStream.Length
                $bytesCopied = 0

                while (($read = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $destStream.Write($buffer, 0, $read)
                    $bytesCopied += $read
                    $percentFile = [math]::Round(($bytesCopied / $totalBytes) * 100)
                    $progressLabel.Text = "Copying $($file.Name): $percentFile%"
                    [System.Windows.Forms.Application]::DoEvents()
                }

                $fileStream.Close()
                $destStream.Close()

                if ($cred) {
                    # Use Copy-Item with credential in case file access needs it
                    Copy-Item -Path $sourcePath -Destination $destPath -Force -Credential $cred
                }

                $logBox.AppendText("✔ Copied $($file.Name) to $dest`r`n")
            }
            catch {
                $logBox.AppendText("❌ Failed to copy $($file.Name) to $dest - $_`r`n")
            }

            $step++
            $progressBar.Value = [int](($step / $totalSteps) * 100)
            $progressLabel.Text = "Progress: " + $progressBar.Value + "%"
            [System.Windows.Forms.Application]::DoEvents()
        }
        $logBox.AppendText("Completed $dest`r`n`r`n")
    }

    $logBox.AppendText("✅ All copies complete.`r`n")
    $progressLabel.Text = "Progress: 100%"
    $copyButton.Enabled = $true
})

# ======================
# RUN FORM
# ======================
[void]$form.ShowDialog()
