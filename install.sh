#!/bin/bash

VM_STORAGE=${1:-local-lvm} && \
pvesm list $VM_STORAGE >& /dev/null || { \
echo -e "\n\n\nERROR: '$VM_STORAGE' is not a valid storage ID.\n\n\n" && \
exit 1
} && \
STORAGE_TYPE=`pvesm status -storage local | awk 'NR>1 {print $2}'` && \
VMID=$(cat<<EOF | python3
import json
with open('/etc/pve/.vmlist') as vmlist:
        vmids = json.load(vmlist)
if 'ids' not in vmids:
        print(100)
else:
        last_vm = sorted(vmids['ids'].keys())[-1:][0]
        print(int(last_vm)+1)
EOF
) && \
echo -e "\n\n\n" \
        "********************************\n" \
        "*  Getting latest HassOS Info  *\n" \
        "********************************\n" && \
URL=$(cat<<EOF | python3
import requests
url = 'https://api.github.com/repos/home-assistant/hassos/releases/latest'
r = requests.get(url).json()
if 'message' in r:
        exit()
for asset in r['assets']:
        if asset['name'].endswith('vdi.gz'):
                print(asset['browser_download_url'])
EOF
) && \
if [ -z "$URL" ]; then
        echo "Github has returned an error. A rate limit may have been applied to your connection. Please wait a while, then try again."
        exit 1
fi && \
echo -e "\n\n\n" \
        "********************************\n" \
        "*      Downloading HassOS      *\n" \
        "********************************\n" && \
wget -q $URL && \
FILE=$(basename $URL) && \
echo -e "\n\n\n" \
        "********************************\n" \
        "*      Extracting HassOS       *\n" \
        "********************************\n" && \
gunzip -f $FILE && \
echo -e "\n\n\n" \
        "********************************\n" \
        "*       Creating new VM        *\n" \
        "********************************\n" && \
VMDISK=vm-${VMID}-disk-
qm create $VMID -bios ovmf -name $(sed -e "s/\_//g" -e "s/.vdi.gz//" <<< $FILE) \
        -net0 virtio,bridge=vmbr0 -onboot 1 -ostype l26 -scsihw virtio-scsi-pci && \
pvesm alloc $VM_STORAGE $VMID ${VMDISK}0$(if [ "$STORAGE_TYPE" = "dir"]; then echo "qcow2";fi) 128 1>&/dev/null && \
qm importdisk $VMID ${FILE%".gz"} $VM_STORAGE 1>&/dev/null && \
qm set $VMID -bootdisk sata0 -efidisk0 ${VM_STORAGE}:${VMDISK}0,size=128K \
        -sata0 ${VM_STORAGE}:${VMDISK}1,size=6G > /dev/null && \
echo -e "\n\n\n" \
        "********************************\n" \
        "*    Completed Successfully    *\n" \
        "*       New VM ID is $VMID       *\n" \
        "********************************\n"
