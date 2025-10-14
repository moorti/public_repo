# ================================
# USER LOGON TIMELINE REPORT GUI
# Compatible with PowerShell 3.0+ / Windows Server 2008 R2, 2012, 2016+
# ================================

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

# --- LogonType mapping ---
$logonTypeMapping = @{
    2  = "Interactive (Physical console / RDP session)"
    3  = "Network (Accessing shared folder / network resource)"
    4  = "Batch (Scheduled task)"
    5  = "Service (Windows or SQL service startup)"
    7  = "Unlock (User unlocks workstation)"
    8  = "NetworkCleartext (Authentication over network)"
    10 = "RemoteInteractive (RDP session)"
    11 = "CachedInteractive (Cached offline logon)"
}

# --- GUI XAML ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="User Logon Timeline Tool" Height="500" Width="560"
        ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
        Background="#F3F3F3">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- 0 Title -->
            <RowDefinition Height="Auto"/> <!-- 1 Username Filter -->
            <RowDefinition Height="Auto"/> <!-- 2 Include System Accounts -->
            <RowDefinition Height="Auto"/> <!-- 3 Real User Only -->
            <RowDefinition Height="Auto"/> <!-- 4 Start Date -->
            <RowDefinition Height="Auto"/> <!-- 5 End Date -->
            <RowDefinition Height="Auto"/> <!-- 6 Generate Button -->
            <RowDefinition Height="*"/>    <!-- 7 Output Box -->
        </Grid.RowDefinitions>

        <TextBlock Text="User Logon Timeline Generator" FontWeight="Bold"
                   FontSize="18" HorizontalAlignment="Center" Margin="0,0,0,10" Grid.Row="0"/>

        <!-- Username Filter (ComboBox + Editable) -->
        <StackPanel Orientation="Horizontal" Grid.Row="1" Margin="0,5,0,0">
            <TextBlock Text="Username Filter:" Width="150" VerticalAlignment="Center"/>
            <ComboBox x:Name="UserFilterBox" Width="200" IsEditable="True" ToolTip="Select or type username">
                <ComboBoxItem Content="usera"/>
                <ComboBoxItem Content="userb"/>
                <ComboBoxItem Content="userc"/>
            </ComboBox>
        </StackPanel>

        <!-- Include system accounts -->
        <StackPanel Orientation="Horizontal" Grid.Row="2" Margin="0,5,0,0">
            <CheckBox x:Name="IncludeSystemCheck" Content="Include system/service accounts" IsChecked="False"/>
        </StackPanel>

        <!-- Real user logon only -->
        <StackPanel Orientation="Horizontal" Grid.Row="3" Margin="0,5,0,0">
            <CheckBox x:Name="RealUserOnlyCheck" Content="Show only real user logons (interactive/RDP)" IsChecked="True"/>
        </StackPanel>

        <StackPanel Orientation="Horizontal" Grid.Row="4" Margin="0,10,0,0">
            <TextBlock Text="Start Date:" Width="150" VerticalAlignment="Center"/>
            <DatePicker x:Name="StartDatePicker" Width="150"/>
            <TextBox x:Name="StartTimeBox" Width="60" Margin="10,0,0,0" Text="00:00"/>
        </StackPanel>

        <StackPanel Orientation="Horizontal" Grid.Row="5" Margin="0,10,0,0">
            <TextBlock Text="End Date:" Width="150" VerticalAlignment="Center"/>
            <DatePicker x:Name="EndDatePicker" Width="150"/>
            <TextBox x:Name="EndTimeBox" Width="60" Margin="10,0,0,0" Text="23:59"/>
        </StackPanel>

        <Button x:Name="RunButton" Content="Generate Report"
                Grid.Row="6" Height="35" Width="180" Margin="0,20,0,0"
                HorizontalAlignment="Center" Background="#0078D7"
                Foreground="White" FontWeight="Bold" BorderThickness="0"
                Cursor="Hand"/>

        <TextBox x:Name="OutputBox" Grid.Row="7" Margin="0,15,0,0"
                 VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
                 AcceptsReturn="True" IsReadOnly="True"
                 FontFamily="Consolas" Height="150"/>
    </Grid>
</Window>
"@

# --- Load GUI ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Controls ---
$UserFilterBox     = $window.FindName("UserFilterBox")
$IncludeSystemCheck= $window.FindName("IncludeSystemCheck")
$RealUserOnlyCheck = $window.FindName("RealUserOnlyCheck")
$StartDatePicker   = $window.FindName("StartDatePicker")
$StartTimeBox      = $window.FindName("StartTimeBox")
$EndDatePicker     = $window.FindName("EndDatePicker")
$EndTimeBox        = $window.FindName("EndTimeBox")
$RunButton         = $window.FindName("RunButton")
$OutputBox         = $window.FindName("OutputBox")

# --- Defaults ---
$StartDatePicker.SelectedDate = (Get-Date).AddDays(-1)
$EndDatePicker.SelectedDate   = Get-Date

# --- Button click event ---
$RunButton.Add_Click({
    $OutputBox.Clear()
    $OutputBox.AppendText("Generating detailed logon timeline...`r`n")

    try {
        $startDate = $StartDatePicker.SelectedDate
        $endDate   = $EndDatePicker.SelectedDate

        if (-not $startDate -or -not $endDate) {
            [System.Windows.MessageBox]::Show("Please select both start and end dates.")
            return
        }

        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $startTime = [datetime]::ParseExact($StartTimeBox.Text, "HH:mm", $culture)
        $endTime   = [datetime]::ParseExact($EndTimeBox.Text, "HH:mm", $culture)

        $StartTime = Get-Date -Date ($startDate.Date + $startTime.TimeOfDay)
        $EndTime   = Get-Date -Date ($endDate.Date + $endTime.TimeOfDay)

        if ($EndTime -lt $StartTime) {
            [System.Windows.MessageBox]::Show("End time cannot be before start time.")
            return
        }

        # --- Get user filter value (typed or selected) ---
        $filterText = $UserFilterBox.Text
        $includeSystem = $IncludeSystemCheck.IsChecked
        $realUserOnly  = $RealUserOnlyCheck.IsChecked

        $OutputBox.AppendText("Collecting events from $StartTime to $EndTime...`r`n")

        $excludedUsersPattern = '(?i)^(DWM-|UMFD-|SQL|SQLEXPRESS|SYSTEM|ANONYMOUS LOGON|NT AUTHORITY|.+\$)'

        # --- Append current date to filename ---
        $today = Get-Date -Format "yyyy-MM-dd"
        $CsvPath = "$env:USERPROFILE\Desktop\UserLogonReport-$today.csv"
        $ExcelPath = "$env:USERPROFILE\Desktop\UserLogonReport-$today.xlsx"

        # --- Get events ---
        $filter = @{
            LogName = 'Security'
            ID = @(4624,4634)
            StartTime = $StartTime
            EndTime = $EndTime
        }

        $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
        $OutputBox.AppendText("Processing $($events.Count) events...`r`n")

        $parsed = @()
        foreach ($e in $events) {
            try {
                $xml = [xml]$e.ToXml()
                $user = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" }).'#text'
                $logonType = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq "LogonType" }).'#text'
                $workstation = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq "WorkstationName" }).'#text'

                if (-not $user) { continue }

                if (-not $includeSystem -and $user -match $excludedUsersPattern) { continue }
                if ($filterText -and ($user -notmatch [Regex]::Escape($filterText))) { continue }

                if ($realUserOnly) {
                    $realLogonTypes = @(2,7,10,11)
                    if ($e.Id -eq 4624 -and $logonType -notin $realLogonTypes) { continue }
                }

                $eventType = if ($e.Id -eq 4624) { "Logon" } else { "Logoff" }

                $parsed += [PSCustomObject]@{
                    UserName         = $user
                    EventType        = $eventType
                    TimeCreated      = $e.TimeCreated
                    LogonType        = $logonType
                    LogonTypeMeaning = if ($logonType -and $logonTypeMapping.ContainsKey([int]$logonType)) {
                                           $logonTypeMapping[[int]$logonType]
                                       } else {
                                           "Unknown / N/A"
                                       }
                    Workstation      = $workstation
                }
            } catch {}
        }

        $parsed = $parsed | Sort-Object TimeCreated
        $OutputBox.AppendText("Found $($parsed.Count) matching events.`r`n")

        # --- Export ---
        $parsed | Export-Csv -NoTypeInformation -Path $CsvPath
        $OutputBox.AppendText("CSV exported to: $CsvPath`r`n")

        if (Get-Module -ListAvailable -Name ImportExcel) {
            $parsed | Export-Excel -Path $ExcelPath -AutoSize
            $OutputBox.AppendText("Excel exported to: $ExcelPath`r`n")
        } else {
            $OutputBox.AppendText("Install 'ImportExcel' to export XLSX.`r`n")
        }

        $OutputBox.AppendText("Report complete.`r`n")
    }
    catch {
        $OutputBox.AppendText("Error: $($_.Exception.Message)`r`n")
    }
})

# --- Run the GUI ---
$null = $window.ShowDialog()
