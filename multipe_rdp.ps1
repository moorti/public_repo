Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------
# Predefined hosts
# ---------------------------
$HostList = @(
    'IP1',
    'IP2'
    )

# ---------------------------
# Helper functions
# ---------------------------
function Write-Status {
    param([string]$text)
    if ($global:lblStatus) { $global:lblStatus.Text = $text }
    if ($global:txtLog) { $global:txtLog.AppendText((Get-Date -Format 'HH:mm:ss') + " - " + $text + "`r`n") | Out-Null }
    return $null
}

function Build-RdpFile {
    param(
        [string]$TargetHost,
        [string]$Username,
        [int]$Width = 1700,
        [int]$Height = 950,
        [string]$OutFolder
    )

    $rdpFile = Join-Path $OutFolder ("$TargetHost.rdp")
    $lines = @()
    $lines += "screen mode id:i:1"
    $lines += "desktopwidth:i:$Width"
    $lines += "desktopheight:i:$Height"
    $lines += "full address:s:$TargetHost"
    if ($Username) { $lines += "username:s:$Username" }
    $lines += "smart sizing:i:1"
    $lines += "audiomode:i:0"
    $lines += "redirectclipboard:i:1"
    $lines += "redirectprinters:i:0"
    $lines += "authentication level:i:0"
    $lines += "prompt for credentials:i:0"
    $lines += "enablecredsspsupport:i:1"

    $lines | Out-File -FilePath $rdpFile -Encoding ASCII -Force
    return $rdpFile
}

function Add-CmdKeyCredential {
    param(
        [string]$TargetHost,
        [string]$TargetUser,
        [string]$Password
    )
    try {
        $target = "TERMSRV/$TargetHost"
        cmdkey.exe /delete:$target 2>$null | Out-Null
        cmdkey.exe /generic:$target /user:$TargetUser /pass:$Password | Out-Null
        return $true
    } catch {
        return $false
    }
}

# ---------------------------
# Build GUI
# ---------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Multi-RDP Launcher"
$form.Size = New-Object System.Drawing.Size(960,700)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimizeBox = $true

# safe integer x-offset for second textbox
[int]$rightX = 630
[int]$rightXOffset = $rightX + 100

# ---------------------------
# Left panel: Hosts
# ---------------------------
$lblHosts = New-Object System.Windows.Forms.Label
$lblHosts.Location = New-Object System.Drawing.Point(12,12)
$lblHosts.Size = New-Object System.Drawing.Size(300,20)
$lblHosts.Text = "Predefined Hosts (editable)"
$lblHosts.Anchor = 'Top,Left'
$form.Controls.Add($lblHosts)

$lstHosts = New-Object System.Windows.Forms.ListBox
$lstHosts.Location = New-Object System.Drawing.Point(12,36)
$lstHosts.Size = New-Object System.Drawing.Size(600,320)
$lstHosts.SelectionMode = 'One'
$lstHosts.Anchor = 'Top,Left,Bottom'
$form.Controls.Add($lstHosts)

# populate listbox (suppress return values)
foreach ($s in $HostList) { $null = $lstHosts.Items.Add($s) }

$txtHostEdit = New-Object System.Windows.Forms.TextBox
$txtHostEdit.Location = New-Object System.Drawing.Point(12,362)
$txtHostEdit.Size = New-Object System.Drawing.Size(420,24)
$txtHostEdit.Anchor = 'Bottom,Left'
$form.Controls.Add($txtHostEdit)

# Host buttons
$btnAddHost = New-Object System.Windows.Forms.Button
$btnAddHost.Location = New-Object System.Drawing.Point(444,360)
$btnAddHost.Size = New-Object System.Drawing.Size(60,28)
$btnAddHost.Text = "Add"
$btnAddHost.Anchor = 'Bottom,Left'
$form.Controls.Add($btnAddHost)

$btnEditHost = New-Object System.Windows.Forms.Button
$btnEditHost.Location = New-Object System.Drawing.Point(512,360)
$btnEditHost.Size = New-Object System.Drawing.Size(60,28)
$btnEditHost.Text = "Edit"
$btnEditHost.Anchor = 'Bottom,Left'
$form.Controls.Add($btnEditHost)

$btnDelHost = New-Object System.Windows.Forms.Button
$btnDelHost.Location = New-Object System.Drawing.Point(580,360)
$btnDelHost.Size = New-Object System.Drawing.Size(60,28)
$btnDelHost.Text = "Delete"
$btnDelHost.Anchor = 'Bottom,Left'
$form.Controls.Add($btnDelHost)

$btnClearList = New-Object System.Windows.Forms.Button
$btnClearList.Location = New-Object System.Drawing.Point(648,360)
$btnClearList.Size = New-Object System.Drawing.Size(60,28)
$btnClearList.Text = "Clear"
$btnClearList.Anchor = 'Bottom,Left'
$form.Controls.Add($btnClearList)

# ---------------------------
# Right panel: credentials & options
# ---------------------------
$lblCredHeader = New-Object System.Windows.Forms.Label
$lblCredHeader.Location = New-Object System.Drawing.Point($rightX,12)
$lblCredHeader.Size = New-Object System.Drawing.Size(300,20)
$lblCredHeader.Font = New-Object System.Drawing.Font($lblCredHeader.Font.FontFamily,10,[System.Drawing.FontStyle]::Bold)
$lblCredHeader.Text = "Credentials & Options"
$lblCredHeader.Anchor = 'Top,Right'
$form.Controls.Add($lblCredHeader)

# Username label & textbox (description fixed)
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Location = New-Object System.Drawing.Point($rightX,40)
$lblUser.Size = New-Object System.Drawing.Size(280,18)
$lblUser.Text = "Username (domain\user or user@domain):"
$lblUser.Anchor = 'Top,Right'
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = New-Object System.Drawing.Point($rightX,60)
$txtUser.Size = New-Object System.Drawing.Size(200,24)
$txtUser.Anchor = 'Top,Right'
$form.Controls.Add($txtUser)

# Password label & textbox
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Location = New-Object System.Drawing.Point($rightX,90)
$lblPass.Size = New-Object System.Drawing.Size(200,18)
$lblPass.Text = "Password:"
$lblPass.Anchor = 'Top,Right'
$form.Controls.Add($lblPass)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Location = New-Object System.Drawing.Point($rightX,110)
$txtPass.Size = New-Object System.Drawing.Size(200,24)
$txtPass.UseSystemPasswordChar = $true
$txtPass.Anchor = 'Top,Right'
$form.Controls.Add($txtPass)

# Checkboxes
$chkCmdKey = New-Object System.Windows.Forms.CheckBox
$chkCmdKey.Location = New-Object System.Drawing.Point($rightX,140)
$chkCmdKey.Size = New-Object System.Drawing.Size(280,24)
$chkCmdKey.Text = "Use cmdkey to cache credentials"
$chkCmdKey.Anchor = 'Top,Right'
$form.Controls.Add($chkCmdKey)

$chkFull = New-Object System.Windows.Forms.CheckBox
$chkFull.Location = New-Object System.Drawing.Point($rightX,170)
$chkFull.Size = New-Object System.Drawing.Size(200,24)
$chkFull.Text = "Full screen"
$chkFull.Anchor = 'Top,Right'
$form.Controls.Add($chkFull)

$chkCleanup = New-Object System.Windows.Forms.CheckBox
$chkCleanup.Location = New-Object System.Drawing.Point($rightX,200)
$chkCleanup.Size = New-Object System.Drawing.Size(260,24)
$chkCleanup.Text = "Delete temp .rdp files after launch"
$chkCleanup.Anchor = 'Top,Right'
$form.Controls.Add($chkCleanup)

# RDP Window size label & boxes
$lblRdpSize = New-Object System.Windows.Forms.Label
$lblRdpSize.Location = New-Object System.Drawing.Point($rightX,230)
$lblRdpSize.Size = New-Object System.Drawing.Size(200,18)
$lblRdpSize.Text = "RDP Window Size (WxH):"
$lblRdpSize.Anchor = 'Top,Right'
$form.Controls.Add($lblRdpSize)

$txtRdpWidth = New-Object System.Windows.Forms.TextBox
$txtRdpWidth.Location = New-Object System.Drawing.Point($rightX,250)
$txtRdpWidth.Size = New-Object System.Drawing.Size(80,24)
$txtRdpWidth.Text = "1700"
$txtRdpWidth.Anchor = 'Top,Right'
$form.Controls.Add($txtRdpWidth)

$txtRdpHeight = New-Object System.Windows.Forms.TextBox
$txtRdpHeight.Location = New-Object System.Drawing.Point($rightXOffset,250)
$txtRdpHeight.Size = New-Object System.Drawing.Size(80,24)
$txtRdpHeight.Text = "950"
$txtRdpHeight.Anchor = 'Top,Right'
$form.Controls.Add($txtRdpHeight)

# Launch button
$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Location = New-Object System.Drawing.Point($rightX,280)
$btnLaunch.Size = New-Object System.Drawing.Size(200,36)
$btnLaunch.Text = "Launch RDP to All"
$btnLaunch.Anchor = 'Top,Right'
$form.Controls.Add($btnLaunch)

# Status & Tip
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(12,470)
$lblStatus.Size = New-Object System.Drawing.Size(920,20)
$lblStatus.Text = "Ready"
$lblStatus.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($lblStatus)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(12,500)
$txtLog.Size = New-Object System.Drawing.Size(920,150)
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($txtLog)

$lblTip = New-Object System.Windows.Forms.Label
$lblTip.Location = New-Object System.Drawing.Point(12,660)
$lblTip.Size = New-Object System.Drawing.Size(920,16)
$lblTip.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",8,[System.Drawing.FontStyle]::Italic)
$lblTip.Text = "Tip: Add or edit hosts on the left. Resize the window as needed."
$lblTip.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($lblTip)

$global:lblStatus = $lblStatus
$global:txtLog = $txtLog

# ---------------------------
# Host buttons logic
# ---------------------------
$btnAddHost.Add_Click({
    $val = $txtHostEdit.Text.Trim()
    if (-not $val) { Write-Status "No host entered to add."; return }
    if ($lstHosts.Items.Contains($val)) { Write-Status ("Host already exists: " + $val); return }
    $null = $lstHosts.Items.Add($val)
    $HostList += $val
    $txtHostEdit.Clear()
    Write-Status ("Added host: " + $val)
})

$btnEditHost.Add_Click({
    if ($lstHosts.SelectedIndex -lt 0) { Write-Status "No host selected to edit."; return }
    $new = $txtHostEdit.Text.Trim()
    if (-not $new) { Write-Status "No new value entered."; return }
    $idx = $lstHosts.SelectedIndex
    $old = $lstHosts.Items[$idx]
    $lstHosts.Items[$idx] = $new
    $HostList[$idx] = $new
    $txtHostEdit.Clear()
    Write-Status ("Edited host " + $old + " -> " + $new)
})

$btnDelHost.Add_Click({
    if ($lstHosts.SelectedIndex -lt 0) { Write-Status "No host selected to delete."; return }
    $idx = $lstHosts.SelectedIndex
    $old = $lstHosts.Items[$idx]
    $null = $lstHosts.Items.RemoveAt($idx)
    $HostList = $HostList | Where-Object { $_ -ne $old }
    Write-Status ("Deleted host: " + $old)
})

$btnClearList.Add_Click({
    if ($lstHosts.Items.Count -eq 0) { Write-Status "Host list already empty."; return }
    $lstHosts.Items.Clear()
    $HostList = @()
    Write-Status "Cleared host list."
})

$lstHosts.Add_SelectedIndexChanged({
    if ($lstHosts.SelectedIndex -ge 0) { $txtHostEdit.Text = $lstHosts.SelectedItem.ToString() } else { $txtHostEdit.Clear() }
})

# ---------------------------
# Launch button logic
# ---------------------------
$btnLaunch.Add_Click({
    $btnLaunch.Enabled = $false
    Write-Status "Preparing to launch RDP sessions..."

    $user = $txtUser.Text.Trim()
    $password = $txtPass.Text
    $useCmdKey = $chkCmdKey.Checked
    $full = $chkFull.Checked
    $cleanup = $chkCleanup.Checked

    # validate width/height inputs (safe default on failure)
    try { $width = [int]$txtRdpWidth.Text } catch { $width = 1700 }
    try { $height = [int]$txtRdpHeight.Text } catch { $height = 950 }

    if ($useCmdKey -and -not $user) {
        Write-Status "Username is required when using cmdkey."
        $btnLaunch.Enabled = $true
        return
    }

    $tempDir = Join-Path $env:TEMP ("MultiRDP_" + [guid]::NewGuid())
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    Write-Status ("Temporary .rdp files directory: " + $tempDir)

    $failed = @()
    $currentHosts = @()
    for ($i = 0; $i -lt $lstHosts.Items.Count; $i++) { $currentHosts += $lstHosts.Items[$i].ToString() }

    foreach ($server in $currentHosts) {
        if ([string]::IsNullOrWhiteSpace($server)) { continue }
        Write-Status ("Processing " + $server + "...")

        if ($useCmdKey) {
            try {
                $ok = Add-CmdKeyCredential -TargetHost $server -TargetUser $user -Password $password
                if (-not $ok) { Write-Status ("Cmdkey failed for " + $server); $failed += $server } else { Write-Status ("Cached credentials for " + $server) }
            } catch { Write-Status ("CmdKey error for " + $server + ": " + $_.Exception.Message); $failed += $server }
        }

        try {
            $rdpFile = Build-RdpFile -TargetHost $server -Username $user -Width $width -Height $height -OutFolder $tempDir
            Write-Status ("Created RDP file: " + $rdpFile)
            Start-Process -FilePath "mstsc.exe" -ArgumentList ("`"" + $rdpFile + "`"") | Out-Null
            Start-Sleep -Milliseconds 250
            Write-Status ("Launched " + $server)
        } catch {
            Write-Status ("Failed to start mstsc for " + $server + ": " + $_.Exception.Message)
            $failed += $server
        }
    }

    if ($cleanup) {
        try { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue; Write-Status "Temporary .rdp files deleted" }
        catch { Write-Status ("Could not delete temp files: " + $_.Exception.Message) }
    } else {
        Write-Status ("Temporary .rdp files retained at: " + $tempDir)
    }

    if ($failed.Count -gt 0) { Write-Status ("Completed with errors. Failed hosts: " + ($failed -join ', ')) }
    else { Write-Status "All requested connections launched." }

    $btnLaunch.Enabled = $true
})

# ensure the dialog does not emit any return value
[void]$form.ShowDialog()
