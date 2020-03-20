#!/usr/bin/env bash

# Setup script environment
set -o errexit  #Exit immediately if a pipeline returns a non-zero status
set -o errtrace #Trap ERR from shell functions, command substitutions, and commands from subshell
set -o nounset  #Treat unset variables as an error
set -o pipefail #Pipe will exit with last non-zero status if applicable
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT

function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function cleanup() {
    popd >/dev/null
    rm -rf $TMP
}
TMP=`mktemp -d`
pushd $TMP >/dev/null

# Select storage location
STORAGE=${1:-local-lvm}
pvesm list $STORAGE >& /dev/null ||
    die "'$STORAGE' is not a valid storage ID."
pvesm status -content images -storage $STORAGE >&/dev/null ||
    die "'$STORAGE' does not allow 'Disk image' to be stored."
STORAGE_TYPE=`pvesm status -storage $STORAGE | awk 'NR>1 {print $2}'`

# Get the next guest VM/LXC ID
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

# Get latest Home Assistant disk image archive URL
msg "
    ********************************
    *  Getting latest HassOS Info  *
    ********************************"
RELEASE_EXT=vmdk.gz
URL=$(cat<<EOF | python3
import requests
url = 'https://api.github.com/repos/home-assistant/hassos/releases/latest'
r = requests.get(url).json()
if 'message' in r:
    exit()
for asset in r['assets']:
    if asset['name'].endswith('$RELEASE_EXT'):
        print(asset['browser_download_url'])
EOF
)
if [ -z "$URL" ]; then
    die "Github has returned an error. A rate limit may have been applied to your connection."
fi

# Download Home Assistant disk image archive
msg "\n\n\n
    ********************************
    *      Downloading HassOS      *
    ********************************"
wget -q --show-progress $URL
FILE=$(basename $URL)

# Extract Home Assistant disk image
msg "\n\n\n
    ********************************
    *      Extracting HassOS       *
    ********************************"
gunzip -f $FILE

msg "\n\n\n
    ********************************
    *       Creating new VM        *
    ********************************"
# Create variables for container disk
if [ "$STORAGE_TYPE" = "dir" ]; then
    DISK_EXT=".qcow2"
    DISK_REF="$VMID/"
    IMPORT_OPT="-format qcow2"
fi
for i in {0,1}; do
    disk="DISK$i"
    eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
    eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

# Create VM
qm create $VMID -bios ovmf -name $(sed -e "s/\_//g" -e "s/.${RELEASE_EXT}//" <<< $FILE) \
    -net0 virtio,bridge=vmbr0 -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 128 1>&/dev/null
qm importdisk $VMID ${FILE%".gz"} $STORAGE ${IMPORT_OPT:-} 1>&/dev/null
qm set $VMID -bootdisk sata0 -efidisk0 ${DISK0_REF},size=128K \
    -sata0 ${DISK1_REF},size=6G > /dev/null

msg "\n\n\n
    ********************************
    *    Completed Successfully    *
    *       New VM ID is \e[1m$VMID\e[0m       *
    ********************************"
