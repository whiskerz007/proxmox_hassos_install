# Proxmox HassOS Install

To create a new HassOS VM in Proxmox with the latest version, run the following in a SSH session or the console from Proxmox interface

```
TMP=`mktemp -d`;pushd $TMP;wget -qO - https://raw.githubusercontent.com/whiskerz007/proxmox_hassos_install/master/install.sh | bash;popd;rm -rf $TMP;unset TMP 
```
