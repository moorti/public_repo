
# ------------------------------
# Admin Elevation
# ------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

# ------------------------------
# Load Windows Forms
# ------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Logoff Other Users"
$form.Size = New-Object System.Drawing.Size(650,550)
$form.StartPosition = "CenterScreen"

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(10,10)
$refreshButton.Size = New-Object System.Drawing.Size(300,40)
$refreshButton.Text = "Refresh Sessions"

$logoffButton = New-Object System.Windows.Forms.Button
$logoffButton.Location = New-Object System.Drawing.Point(320,10)
$logoffButton.Size = New-Object System.Drawing.Size(250,40)
$logoffButton.Text = "Logoff Other Users"

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10,60)
$textBox.Size = New-Object System.Drawing.Size(600,450)
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.ReadOnly = $true
$textBox.Font = New-Object System.Drawing.Font("Consolas",10)

# ------------------------------
# Detect current session ID reliably
# ------------------------------
function Get-MySessionID {
    $username = $env:USERNAME
    $mySessionID = $null
    $sessions = qwinsta 2>&1 | ForEach-Object { $_.Trim() }
    foreach ($line in $sessions) {
        if ($line -match "^\s*(\S+)\s+(\S+)\s+(\d+)\s+(\S+)") {
            $sessUser = $matches[2]
            $sessID   = [int]$matches[3]
            if ($sessUser -eq $username -and $sessID -ne 0) {
                $mySessionID = $sessID
                break
            }
        }
    }
    return $mySessionID
}

# ------------------------------
# Get all other user sessions
# ------------------------------
function Get-Sessions {
    $mySessionID = Get-MySessionID
    $sessions = @()

    $lines = qwinsta 2>&1 | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notmatch "USERNAME|Services|SYSTEM") }

    foreach ($line in $lines) {
        if ($line -match "^\s*(\S+)\s+(\S+)\s+(\d+)\s+(\S+)") {
            $sessName  = $matches[1]
            $sessUser  = $matches[2]
            $sessID    = [int]$matches[3]
            $sessState = $matches[4]

            # Skip console (0), SYSTEM/Services, and your session
            if ($sessID -ne 0 -and $sessID -ne $mySessionID -and $sessUser -ne "SYSTEM" -and $sessUser -ne "Services") {
                $sessions += [PSCustomObject]@{
                    SessionName = $sessName
                    Username    = $sessUser
                    SessionID   = $sessID
                    State       = $sessState
                }
            }
        }
    }
    return $sessions
}

# ------------------------------
# Display sessions safely
# ------------------------------
function Show-Sessions {
    $textBox.Clear()
    $textBox.AppendText("Your session ID: $(Get-MySessionID)`r`n`r`n")

    $sessions = Get-Sessions
    if ($sessions.Count -eq 0) {
        $textBox.AppendText("No other sessions found.`r`n")
        return
    }

    $textBox.AppendText("Current sessions:`r`n")
    foreach ($s in $sessions) {
        $username  = if ($s.Username) { $s.Username } else { "<none>" }
        $sessionID = if ($s.SessionID) { $s.SessionID } else { 0 }
        $state     = if ($s.State) { $s.State } else { "<unknown>" }

        $textBox.AppendText("$username".PadRight(20) + "$sessionID".PadRight(6) + "$state".PadRight(10) + "`r`n")
    }
    $textBox.AppendText("`r`n")
}

# ------------------------------
# Button click events
# ------------------------------
$refreshButton.Add_Click({ Show-Sessions })

$logoffButton.Add_Click({
    $sessions = Get-Sessions
    if ($sessions.Count -eq 0) {
        $textBox.AppendText("No sessions to log off.`r`n")
        return
    }

    $textBox.AppendText("Logging off other users...`r`n")
    foreach ($s in $sessions) {
        $username  = if ($s.Username) { $s.Username } else { "<none>" }
        $sessionID = if ($s.SessionID) { $s.SessionID } else { 0 }
        $state     = if ($s.State) { $s.State } else { "<unknown>" }

        try {
            logoff $sessionID /V 2>&1 | Out-Null
            $textBox.AppendText("$username (Session $sessionID, State $state) logged off.`r`n")
        } catch {
            $textBox.AppendText("Failed to log off $username (Session $sessionID)`r`n")
        }
    }
    $textBox.AppendText("Done.`r`n`r`n")
    Show-Sessions
})

# ------------------------------
# Add controls and show form
# ------------------------------
$form.Controls.Add($refreshButton)
$form.Controls.Add($logoffButton)
$form.Controls.Add($textBox)
[void]$form.ShowDialog()
