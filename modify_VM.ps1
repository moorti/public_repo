#Connect to vCenter
Connect-VIServer -Server VCENTER -User USERNAME

# Filepath with VM list to modify
$FilePath = "c:\temp\vms.txt"
$FileContents = Get-Content -Path $FilePAth

$i =1
ForEach ($vm in $FileContents) {
  get-vm $vm | Select-Object Name,powerstate
  Shutdown-VMGuest -vm $vm -Confirm:$false
  Start-sleep -Seconds 90
  
  $spec = Net-Object VMware.Vim.VirtualMachineConfigSpec
  
  # Enable memeory hot-add
  $spec.memoryHotAddEnabled = $true
  
  # Enable CPU hot-add
  $spec.cpuHotAddEnabled = $true
  $vm.ExtensionData.ReconfigVM_Task($spec)
  $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
  
  # Enable EFI and Secure Boot
  $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
  $spec.NestedHVEnabled = $true
  
  $boot = New-Object VMware.Vim.VirtualMachineBootOptions
  $boot.EfiSecureBootEnabled = $true
  $spec.BootOptions = $boot
  
  $flags = New-Object VMware.Vim.VirtualMachineFlagInfo
  $flags.VbsEnabled = $true
  $flags.VvtdEnabled = $true
  $spec.flags = $flags
  $vm.ExtensionsData.ReconfigVM($spec)
  
  # Enable vTPM
  New-Vtpm -vm $vm
  
  Start-VM $vm
  Start-Sleep -seconds 10
  get-vm $vm | Select-Object Name,powerstate
  $i++
  }

#Disconnect from vCenter
Disconnect-ViServer -Confirm:$false
  
