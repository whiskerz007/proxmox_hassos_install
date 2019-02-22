# New Proxmox VM with HassOS

This script will create a new Proxmox VM with the latest version of HassOS. To create a new VM in the `local-lvm` storage, run the following in a SSH session or the console from Proxmox interface

```
TMP=`mktemp -d`;pushd $TMP > /dev/null;wget -qO - https://raw.githubusercontent.com/whiskerz007/proxmox_hassos_install/master/install.sh | bash -s local-lvm;popd > /dev/null;rm -rf $TMP;unset TMP 
```

After script completes, click on the new VM (_the script will tell you the ID_), click on the `Hardware` tab for the VM and change the `Memory` and `Processors` settings to what you desire. The `Hard Disk` can be expanded by clicking on it, then click on the `Resize disk` button above (_Note: additional steps must be taken for storage to take effect in the VM after the first boot_). The network MAC address can be changed by selecting `Network Device` and clicking `Edit` above. Once all changes have been made, click `Start` above.

## Specify Storage ID

To specify the storage ID the new VM will be placed, replace `local-lvm` in the oneline command with desired storage ID.

## Root Prompt

To get to the root prompt
- Open the console after the VM has been started
- When the messages slow down press the `Enter` key a couple of times until you see the following
```

Welcome to HassOS
hassio login:
```
- Login using `root`, no password is requested
- When you see the `hassio > ` prompt, type `login`
- You should now see a `# ` prompt.

## Show DHCP Address

To get the DHCP address assigned to the VM
- At the root prompt type `ls -l /sys/class/net` and look for a name that looks like `enp0s18`
- Use that name in the following command `ip addr show dev enp0s18`
- Your IP address will be listed right after `inet`

## Resize Disk

To resize the disk after the first boot
- At the root prompt type `df -h /dev/sda8` and note the `Size`
- Shutdown the VM
- Resize the disk to the desired size
- At the root prompt type `sgdisk -e /dev/sda`
- Reboot the VM
- Verify resize was successful by typing `df -h /dev/sda8` at the root prompt
