#!/bin/bash
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
function error_exit() {
    REASON=$1
    MSG="\e[91mERROR: \e[93m$EXIT@"
    if [ -z "$REASON" ]; then
        MSG="$MSG$LINE:"
        REASON="Unknown failure occured."
    else
        MSG="$MSG`echo $(( $LINE - 1 ))`:"
    fi
    echo -e "$MSG \e[97m$REASON\e[39m\e[49m"
    exit $EXIT
}
function cleanup() {
    popd >/dev/null
    rm -rf $TMP
}
trap cleanup EXIT
TMP=`mktemp -d`
pushd $TMP >/dev/null

STORAGE=${1:-local-lvm}
pvesm list $STORAGE >& /dev/null ||
    die "'$STORAGE' is not a valid storage ID."
pvesm status -content images -storage $STORAGE >&/dev/null ||
    die "'$STORAGE' does not allow 'Disk image' to be stored."
STORAGE_TYPE=`pvesm status -storage $STORAGE | awk 'NR>1 {print $2}'`
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
)
echo -e "\n\n\n" \
    "********************************\n" \
    "*  Getting latest HassOS Info  *\n" \
    "********************************\n"
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
)
if [ -z "$URL" ]; then
    die "Github has returned an error. A rate limit may have been applied to your connection."
fi
echo -e "\n\n\n" \
    "********************************\n" \
    "*      Downloading HassOS      *\n" \
    "********************************\n"
wget -q --show-progress $URL
FILE=$(basename $URL)
echo -e "\n\n\n" \
    "********************************\n" \
    "*      Extracting HassOS       *\n" \
    "********************************\n"
gunzip -f $FILE
echo -e "\n\n\n" \
    "********************************\n" \
    "*       Creating new VM        *\n" \
    "********************************\n"
if [ "$STORAGE_TYPE" = "dir" ]; then
    DISK_EXT=".qcow2"
    DISK_REF="$VMID/"
    IMPORT_OPT="-format qcow2"
fi
for i in {0,1}; do
    disk="DISK$i"
    eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT}
    eval DISK${i}_REF=${STORAGE}:$DISK_REF${!disk}
done
qm create $VMID -bios ovmf -name $(sed -e "s/\_//g" -e "s/.vdi.gz//" <<< $FILE) \
    -net0 virtio,bridge=vmbr0 -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 128 1>&/dev/null
qm importdisk $VMID ${FILE%".gz"} $STORAGE $IMPORT_OPT 1>&/dev/null
qm set $VMID -bootdisk sata0 -efidisk0 ${DISK0_REF},size=128K \
    -sata0 ${DISK1_REF},size=6G > /dev/null
echo -e "\n\n\n" \
    "********************************\n" \
    "*    Completed Successfully    *\n" \
    "*       New VM ID is \e[1m$VMID\e[0m       *\n" \
    "********************************\n"
