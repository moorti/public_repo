# Connect to vCenter
Connect-VIServer -Server "VCENTER" -User "USERNAME"

# Filepath with VM list to modify
$FilePath = "C:\Temp\vms.txt"
$FileContents = Get-Content -Path $FilePath

$i = 1
foreach ($vmName in $FileContents) {
    $vm = Get-VM -Name $vmName

    Write-Host "`nProcessing VM: $($vm.Name)"
    Get-VM $vm | Select-Object Name, PowerState

    # Gracefully shut down the VM
    Shutdown-VMGuest -VM $vm -Confirm:$false
    Start-Sleep -Seconds 90

    # --- Enable Memory and CPU Hot-Add ---
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.memoryHotAddEnabled = $true
    $spec.cpuHotAddEnabled = $true
    $vm.ExtensionData.ReconfigVM_Task($spec)

    # --- Enable EFI, Secure Boot, Nested HV, and vTPM ---
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
    $spec.NestedHVEnabled = $true

    $boot = New-Object VMware.Vim.VirtualMachineBootOptions
    $boot.EfiSecureBootEnabled = $true
    $spec.BootOptions = $boot

    $flags = New-Object VMware.Vim.VirtualMachineFlagInfo
    $flags.VbsEnabled = $true
    $flags.VvtdEnabled = $true
    $spec.Flags = $flags

    $vm.ExtensionData.ReconfigVM_Task($spec)

    # --- Enable vTPM ---
    New-VTpm -VM $vm

    # Start the VM again
    Start-VM -VM $vm
    Start-Sleep -Seconds 10
    Get-VM $vm | Select-Object Name, PowerState

    $i++
}

# Disconnect from vCenter
Disconnect-VIServer -Confirm:$false
