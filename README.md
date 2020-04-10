# New Proxmox VM with Home Assistant

This script will create a new Proxmox VM with the latest version of Home Assistant. To create a new VM, run the following in a SSH session or the console from Proxmox interface

```
bash -c "$(wget -qLO - https://github.com/whiskerz007/proxmox_hassos_install/raw/master/install.sh)"
```

After script completes, click on the new VM (_the script will tell you the ID_), click on the `Hardware` tab for the VM and change the `Memory` and `Processors` settings to what you desire. The `Hard Disk` can be expanded by clicking on it, then click on the `Resize disk` button above (_Note: additional steps must be taken for storage to take effect in the VM after the first boot_). The network MAC address can be changed by selecting `Network Device` and clicking `Edit` above. Once all changes have been made, click `Start` above.

## Root Prompt

To get to the root prompt
- Open the console after the VM has been started
- When the messages slow down press the `Enter` key a couple of times until you see the following
```

Welcome to Home Assistant
homeassistant login:
```
- Login using `root`, no password is requested
- When you see the `hassio > ` prompt, type `login`
- You should now see a `# ` prompt.

## Add a serial port

By adding a serial port, you are able to use a different interface to interact with the VM. When you click on the down arrow next to `Console` you will be able to use `xterm.js` which enables you to `Right-Click` and get access to `Copy` and `Paste` functions. If the serial port was already added by the install script, no further actions are required to enable the functionality.
- Click on the VM in the list of containers at the left side panel
- Click `Hardware` tab located beside the list of containers
- Click `Add` located beside `Summary` tab, then click `Serial Port`
- `Serial Port` should be set to `0` in the input box, then click `Add`
- Start the VM, if it isn't already
- At the root prompt type `sed -i 's/$/ console=ttyS0/' /mnt/boot/cmdline.txt`
- A `Shutdown` and `Start` is required for the changes to take effect

## Show Current IP Address

To get the current IP address assigned to the VM from the Proxmox interface
- Click on the VM in the list of containers at the left side panel
- Click `Summary` tab located beside the list of containers
- Click `More` near `IPs` in the top left section
- You can find the assigned IP addresses on the line with the name similar to `enp0s18`

To get the current IP address assigned to the VM from the command line
- At the root prompt type `nmcli -g ip4.address d sh $(nmcli -g device c)`
- The response will be the IP address with subnet mask or nothing

**Note:** _If DHCP is configured and nothing is shown, check DHCP server and VM network settings_

## Configure Network for Static IP Address

To set a static IP address, use the following as an example
- At the root prompt type `nmcli c mod $(nmcli -g uuid c) ipv4.method manual ipv4.addresses "192.168.20.170/24" ipv4.gateway "192.168.20.1" ipv4.dns "8.8.8.8,8.8.4.4"`
- At the root prompt type `nmcli c up $(nmcli -g uuid c)`

## Configure Network for DHCP

To remove all static IP addresses and enable DHCP
- At the root prompt type `nmcli c mod $(nmcli -g uuid c) ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""`
- At the root prompt type `nmcli c up $(nmcli -g uuid c)`

## Default Interface Name

To get the default interface name
- At the root prompt type `nmcli -g device c`
- The response with be the interface name

## Change Hostname

To change the HassOS VM hostname
- At the root prompt type `hostnamectl set-hostname your-new-hostname`
- You can verify the change by logging out with `exit`, the last line printed will be `your-new-hostname login: `

## Resize Disk

To resize the disk after the first boot
- At the root prompt type `df -h /dev/sda8` and note the `Size`
- Shutdown the VM
- Resize the disk to the desired size
- At the root prompt type `sgdisk -e /dev/sda`
- At the root prompt type `reboot`
- Verify resize was successful by typing `df -h /dev/sda8` at the root prompt
