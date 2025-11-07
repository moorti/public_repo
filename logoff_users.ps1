# LogoffOtherUsersCore.txt
# Description: Logs off all other sessions except the current one.

#quser | Select-String "Disc" | ForEach{logoff ($_.tostring() -split ' +')[2]}

$MySessionID = (Get-Process -Id $PID).SessionId
$sessions = quser | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*(\S+)\s+(\S+)?\s+(\d+)\s+(\S+)') {
        [PSCustomObject]@{
            SessionName = if ($matches[1]) {$matches[1]} else {'<unknown>'}
            Username    = if ($matches[2]) {$matches[2]} else {'<none>'}
            SessionID   = [int]$matches[3]
            State       = if ($matches[4]) {$matches[4]} else {'<unknown>'}
        }
    }
}

foreach ($s in $sessions) {
    if ($s.SessionID -ne $MySessionID -and $s.Username -ne '<none>') {
        logoff $s.SessionID
    }
}
