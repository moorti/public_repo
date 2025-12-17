# =====================================================
# CONFIGURATION
# =====================================================

$DaysBeforeExpiry = 7
$MailDomain       = "mail.domain.com"

# SMTP
$SmtpServer = "smtp.yourprovider.com"
$SmtpPort   = 587
$From       = "it-support@mail.domain.com"
$Bcc        = "it-support@mail.domain.com"   # optional, set $null to disable

# Credential file
$CredPath = "C:\Secure\smtp-creds.xml"

# Logging
$LogFile = "C:\Logs\PasswordExpiryNotification.log"

# =====================================================
# FUNCTIONS
# =====================================================

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Timestamp  $Message"
}

function Remove-Diacritics {
    param ([string]$Text)

    $Normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $Builder = New-Object System.Text.StringBuilder

    foreach ($Char in $Normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($Char) -ne 'NonSpacingMark') {
            [void]$Builder.Append($Char)
        }
    }

    $Builder.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Build-EmailFromADName {
    param (
        [string]$GivenName,
        [string]$Surname,
        [string]$Domain
    )

    $LocalPart = "$GivenName.$Surname"
    $LocalPart = Remove-Diacritics $LocalPart
    $LocalPart = $LocalPart.ToLower()
    $LocalPart = $LocalPart -replace '\s',''

    return "$LocalPart@$Domain"
}

# =====================================================
# PREP
# =====================================================

if (!(Test-Path (Split-Path $LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null
}

Write-Log "===== Script started ====="

if (!(Test-Path $CredPath)) {
    Write-Log "ERROR: Credential file not found at $CredPath"
    exit 1
}

$Cred = Import-Clixml $CredPath

# =====================================================
# GET USERS
# =====================================================

try {
    $UsersToReset = Get-ADUser `
        -Filter { Enabled -eq $true -and PasswordNeverExpires -eq $false -and PasswordExpired -eq $false } `
        -Properties Name, GivenName, Surname, "msDS-UserPasswordExpiryTimeComputed" |
    Where-Object { $_."msDS-UserPasswordExpiryTimeComputed" -ne 0 } |
    Select-Object Name, GivenName, Surname, @{
        Name = "PasswordExpiry"
        Expression = {
            [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")
        }
    } |
    Where-Object {
        $_.PasswordExpiry -ge (Get-Date).Date -and
        $_.PasswordExpiry -le (Get-Date).Date.AddDays($DaysBeforeExpiry)
    }

    Write-Log "Found $($UsersToReset.Count) users with expiring passwords"
}
catch {
    Write-Log "ERROR retrieving AD users: $_"
    exit 1
}

# =====================================================
# SEND EMAILS
# =====================================================

foreach ($User in $UsersToReset) {

    if (-not $User.GivenName -or -not $User.Surname) {
        Write-Log "Skipped $($User.Name) (missing GivenName or Surname)"
        continue
    }

    $Email = Build-EmailFromADName `
        -GivenName $User.GivenName `
        -Surname   $User.Surname `
        -Domain    $MailDomain

    Write-Log "Using email [$Email] for user $($User.Name)"

    $DaysLeft = ($User.PasswordExpiry - (Get-Date)).Days

    $Subject = "Your password expires in $DaysLeft day(s)"

    $Body = @"
Hello $($User.Name),

Your Active Directory password will expire on:

$($User.PasswordExpiry.ToString("dddd, MMMM dd, yyyy"))

Please change your password before it expires to avoid login issues.

If you need assistance, contact IT Support.

Thank you,
IT Team
"@

    try {
        Send-MailMessage `
            -From $From `
            -To $Email `
            -Bcc $Bcc `
            -Subject $Subject `
            -Body $Body `
            -Encoding 'utf8' `
            -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -UseSsl `
            -Credential $Cred

        Write-Log "Email sent to $Email"
        Start-Sleep -Seconds 5
    }
    catch {
        Write-Log "ERROR sending email to $Email : $_"
    }
}

Write-Log "===== Script finished ====="
exit 0
