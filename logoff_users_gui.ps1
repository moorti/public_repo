# Check if the script is running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If not running as administrator, restart with elevated privileges
if (-not $isAdmin) {
    # Create a new process with elevated privileges
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $($MyInvocation.MyCommand.Path)" -Verb RunAs

    # Exit the current non-elevated process
    Exit
}


# ==============================
# Session Manager GUI (EXE-ready, no extra windows)
# ==============================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- GUI Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Session Manager"
$form.Size = New-Object System.Drawing.Size(700,450)
$form.StartPosition = "CenterScreen"
$form.Topmost = $true

# ---------- ListView ----------
$listView = New-Object System.Windows.Forms.ListView
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.CheckBoxes = $true
$listView.Width = 660
$listView.Height = 300
$listView.Location = New-Object System.Drawing.Point(10,10)
$listView.Columns.Add("Session ID",80)
$listView.Columns.Add("Username",120)
$listView.Columns.Add("State",120)
$listView.Columns.Add("Idle Time",100)
$listView.Columns.Add("Logon Time",200)
$form.Controls.Add($listView)

# ---------- Buttons ----------
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh Sessions"
$btnRefresh.Width = 150
$btnRefresh.Location = New-Object System.Drawing.Point(10, 330)
$form.Controls.Add($btnRefresh)

$btnLogoffDisc = New-Object System.Windows.Forms.Button
$btnLogoffDisc.Text = "Logoff Disconnected"
$btnLogoffDisc.Width = 150
$btnLogoffDisc.Location = New-Object System.Drawing.Point(180, 330)
$form.Controls.Add($btnLogoffDisc)

$btnLogoffSelected = New-Object System.Windows.Forms.Button
$btnLogoffSelected.Text = "Logoff Selected"
$btnLogoffSelected.Width = 150
$btnLogoffSelected.Location = New-Object System.Drawing.Point(350, 330)
$form.Controls.Add($btnLogoffSelected)

# ---------- Hidden Process Function ----------
function Run-CommandHidden {
    param($exe, $args="")
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $args
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $output = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    return $output
}

$quserExe = Join-Path $env:windir "System32\quser.exe"
$logoffExe = Join-Path $env:windir "System32\logoff.exe"

# ---------- Refresh Sessions ----------
function Refresh-Sessions {
    $listView.Items.Clear()
    $sessions = Run-CommandHidden $quserExe
    if (-not $sessions) { return }

    foreach ($line in $sessions -split "`n") {
        if ($line -match "USERNAME") { continue }
        $parts = ($line -split '\s{2,}') | Where-Object {$_ -ne ""}
        if ($parts.Length -ge 3) {
            $sessionId = $parts[1]
            $username = $parts[0]
            $state = $parts[2]
            $idle = if ($parts.Length -ge 4) { $parts[3] } else { "" }
            $logon = if ($parts.Length -ge 5) { $parts[4] } else { "" }

            $item = New-Object System.Windows.Forms.ListViewItem($sessionId)
            $item.SubItems.Add($username)
            $item.SubItems.Add($state)
            $item.SubItems.Add($idle)
            $item.SubItems.Add($logon)

            if ($state -match "Disc") {
                $item.BackColor = [System.Drawing.Color]::Red
                $item.ForeColor = [System.Drawing.Color]::White
            } elseif ($state -match "Active") {
                $item.BackColor = [System.Drawing.Color]::LightGreen
            } else {
                $item.BackColor = [System.Drawing.Color]::LightGray
            }

            $listView.Items.Add($item)
        }
    }
}

# ---------- Logoff Disconnected ----------
function Logoff-Disconnected {
    $sessions = Run-CommandHidden $quserExe
    $disconnected = $sessions -split "`n" | Where-Object {$_ -match "Disc"}
    foreach ($line in $disconnected) {
        $sid = ($line -split '\s+')[2]
        try { Run-CommandHidden $logoffExe $sid } catch {}
    }
    Refresh-Sessions
}

# ---------- Logoff Selected ----------
function Logoff-Selected {
    $checked = $listView.CheckedItems
    foreach ($item in $checked) {
        $sid = $item.Text
        try { Run-CommandHidden $logoffExe $sid } catch {}
    }
    Refresh-Sessions
}

# ---------- Button Events ----------
$btnRefresh.Add_Click({ Refresh-Sessions })
$btnLogoffDisc.Add_Click({ Logoff-Disconnected })
$btnLogoffSelected.Add_Click({ Logoff-Selected })

# ---------- Initial Load ----------
Refresh-Sessions

# ---------- Show GUI ----------
[void]$form.ShowDialog()
