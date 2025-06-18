#!/bin/bash

set -e

###############################################################################
# Script Name: VMs_installation_Script.sh
#
# Description:
#   This script automates the creation of 3 Rocky Linux minimal server VMs
#   using KVM/QEMU and virt-install on a host Ubuntu system.
#
#   It performs the following:
#     - Checks if a VM with the given name already exists.
#     - Checks if the corresponding qcow2 disk image already exists.
#     - Skips installation if either already exists.
#     - Installs the VM using a provided Rocky Linux ISO file in text mode.
#
# Requirements:
#   - Host OS: Ubuntu (with KVM, libvirt, virt-manager, qemu-system-x86 installed)
#   - User must be in the libvirt/kvm group or run with sudo
#   - Rocky Linux ISO file must be accessible locally
#
# Notes:
#   - You can modify the IMAGE_DIR, ISO path, RAM, vCPU, etc. as needed.
#   - Uses --cdrom for ISO-based install. Change to --location for network install.
#
# Author: Ahmad (modified by ChatGPT)
# Date: June 2025
###############################################################################

# === Configuration Variables ===
VM_NAMES=("ServOneVM" "ServTwoVM" "ServThreeVM")
IMAGE_DIR="/home/amw/Office/DevOps/Practice_VMs"
DISK_SIZE="30G"
RAM="3072"
VCPUS="1"
OS_VARIANT="rocky9"
ROCKY_ISO_PATH="/home/amw/Office/Linux/Distros/Rocky 9.5 AMD64/Rocky 9.5 AMD64 DVD.iso"
OS_ARCH="x86_64"
NETWORK_BRIDGE="default"  # change to your preferred bridge/network if needed

# === Function to check if VM exists ===
check_vm_exists() {
    local vm_name="$1"
    if virsh dominfo "$vm_name" &>/dev/null; then
        echo "❌ VM '$vm_name' already exists. Skipping."
        return 1
    fi
    return 0
}

# === Function to check if disk image exists ===
check_disk_exists() {
    local disk_path="$1"
    if [[ -f "$disk_path" ]]; then
        echo "❌ Disk image '$disk_path' already exists. Skipping."
        return 1
    fi
    return 0
}

# === Main Loop ===
for vm in "${VM_NAMES[@]}"; do
    disk_path="$IMAGE_DIR/${vm}.qcow2"

    echo "🔍 Checking $vm..."
    check_vm_exists "$vm" || continue
    check_disk_exists "$disk_path" || continue

    echo "✅ Creating disk for $vm..."
    qemu-img create -f qcow2 "$disk_path" "$DISK_SIZE"

    echo "🚀 Installing VM: $vm"
    virt-install \
        --name="$vm" \
        --ram="$RAM" \
        --vcpus="$VCPUS" \
        --os-variant="$OS_VARIANT" \
        --arch="$OS_ARCH" \
        --network network="$NETWORK_BRIDGE",model=virtio \
        --graphics=none \
        --console pty,target_type=serial \
        --location "$ROCKY_ISO_PATH" \
        --disk path="$disk_path",format=qcow2,bus=virtio,size="${DISK_SIZE/G/}" \
	--extra-args="console=ttyS0 inst.text"

    echo "✅ VM $vm installation complete."
done

echo "🎉 All tasks completed."
