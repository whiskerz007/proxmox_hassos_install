# Proxmox HassOS Install

To create a new HassOS VM in Proxmox with the latest version, run the following in a SSH session or the console from Proxmox interface

```
TMP=`mktemp -d`;pushd $TMP > /dev/null;wget -qO - https://raw.githubusercontent.com/whiskerz007/proxmox_hassos_install/master/install.sh | bash;popd > /dev/null;rm -rf $TMP;unset TMP 
```

After script completes, click on the new VM (_the script will tell you the ID_), click on the `Hardware` tab for the VM and change the `Memory` and `Processors` settings to what you desire. The `Hard Disk` can be expanded by clicking on it, then click on the `Resize` button above. The network MAC address can be changed by selecting `Network Device` and clicking `Edit` above. Once all changes have been made, click `Start` above.
