#!/bin/bash

WRITABLE=0  # 0 = No changes written to disk, 1 = Write allowed
DEBUG_MODE=${DEBUG_MODE:-0}

OPENWRT_VERSION="23.05.0"
MIKROTIK_VERSION="6.40"
OPENWRT_QCOW2_IMAGE="openwrt-${OPENWRT_VERSION}.qcow2"
MIKROTIK_QCOW2_IMAGE="mikrotik-${MIKROTIK_VERSION}.qcow2"

WAN_BRIDGE="br-wan"
BR_WAN_IP="172.16.1.1/24"

VM_IDS=( {9..24} )
VM_DIR="vms"

# Exit script on any error
set -e

# Function to enable debug mode
debug() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo "[DEBUG]: $1"
    fi
}

print_system_info() {
    echo "WRITABLE: $WRITABLE"
    echo "OpenWrt Image: $OPENWRT_QCOW2_IMAGE"
    echo "MikroTik Image: $MIKROTIK_QCOW2_IMAGE"
    echo "WAN Bridge: $WAN_BRIDGE"
    echo "WAN Bridge IP: $BR_WAN_IP"
    echo "VM IDs: ${VM_IDS[*]}"
    echo "VM Directory: $VM_DIR"
    echo ""
}

init_script() {
    # Extract the base IP address without the subnet mask
    local BASE_IP=$(echo "$BR_WAN_IP" | cut -d'/' -f1)
    
    # Extract the first three octets of the IP address
    local OCTETS=$(echo "$BASE_IP" | awk -F. '{print $1"."$2"."$3}')
    
    # Extract the last octet of the IP address
    local LAST_OCTET=$(echo "$BASE_IP" | awk -F. '{print $4}')
    
    # Use the full base IP for dnsmasq listen address
    local DNSMASQ_IP="$BASE_IP"
    
    # Calculate the DHCP range by adding 100 and 110 to the last octet
    local DHCP_RANGE_START="${OCTETS}.$((LAST_OCTET + 100))"
    local DHCP_RANGE_END="${OCTETS}.$((LAST_OCTET + 110))"

    # Check if the writable flag is set
    if [ "$WRITABLE" -eq 0 ]; then
        SNAPSHOT="on"
    else
        SNAPSHOT="off"
    fi

    # Check if the bridge already exists
    if ip link show "$WAN_BRIDGE" > /dev/null 2>&1; then
        echo "Bridge $WAN_BRIDGE already exists."
    else
        # Create the bridge interface if it doesn't exist
        echo "Creating bridge $WAN_BRIDGE..."
        sudo brctl addbr "$WAN_BRIDGE"
        sudo ip link set dev "$WAN_BRIDGE" up
        sudo ip addr add "$BR_WAN_IP" dev "$WAN_BRIDGE"
    fi

    # Kill any running dnsmasq processes that are bound to the interface or IP
    debug "Stopping any existing dnsmasq processes on $WAN_BRIDGE or $DNSMASQ_IP..."
    sudo pkill -f "dnsmasq.*--interface=$WAN_BRIDGE" || echo "No existing dnsmasq processes found."

    # Start dnsmasq in a new screen session
    debug "Starting dnsmasq in a new screen session..."
    sudo screen -dmS "dnsmasq" \
        dnsmasq --interface="$WAN_BRIDGE" \
        --bind-interfaces \
        --listen-address="$DNSMASQ_IP" \
        --dhcp-range="$DHCP_RANGE_START,$DHCP_RANGE_END,12h" \
        --no-daemon
    
    debug "Initialization complete."
}

# Function to check if necessary tools are installed (like qemu, wget, etc.)
check_dependencies() {
    local dependencies=("qemu-system-x86_64" "screen" "ip" "bridge" "wget" "gunzip" "iptables" "dnsmasq")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed."
            exit 1
        fi
    done
}

# Function to download files if not present
download_if_not_exist() {
    local url="$1"
    local output_file="$2"
    if [ ! -f "$output_file" ]; then
        echo "Downloading $output_file..."
        wget "$url" -O "$output_file"
    else
        echo "$output_file already exists."
    fi
}

deploy_openwrt() {
    local OPENWRT_COMPRESSED_IMAGE="openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-combined.img.gz"
    local OPENWRT_IMAGE_PATH="openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-combined.img"
    local OPENWRT_IMAGE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/${OPENWRT_COMPRESSED_IMAGE}"
    
    # Check if the final qcow2 image already exists
    if [ -f "$OPENWRT_QCOW2_IMAGE" ]; then
        echo "File: $OPENWRT_QCOW2_IMAGE already exists."
        return 0
    fi

    # Download compressed image if it doesn't exist
    download_if_not_exist "$OPENWRT_IMAGE_URL" "$OPENWRT_COMPRESSED_IMAGE" || { echo "Failed to download $OPENWRT_COMPRESSED_IMAGE"; return 1; }

    # Decompress the image if the uncompressed image is not available
    if [ ! -f "$OPENWRT_IMAGE_PATH" ]; then
        echo "Decompressing $OPENWRT_COMPRESSED_IMAGE..."
        gunzip -k "$OPENWRT_COMPRESSED_IMAGE" || echo "File was already extracted."
        rm -f "$OPENWRT_COMPRESSED_IMAGE"
    fi

    # Convert the raw image to qcow2 format and resize it
    if [ ! -f "$OPENWRT_QCOW2_IMAGE" ]; then
        echo "Converting $OPENWRT_IMAGE_PATH to qcow2 format..."
        qemu-img convert -f raw -O qcow2 "$OPENWRT_IMAGE_PATH" "$OPENWRT_QCOW2_IMAGE" || { echo "Failed to convert image"; return 1; }
        echo "Resizing $OPENWRT_QCOW2_IMAGE to 200M..."
        qemu-img resize "$OPENWRT_QCOW2_IMAGE" 200M || { echo "Failed to resize $OPENWRT_QCOW2_IMAGE"; return 1; }
        rm -f "$OPENWRT_IMAGE_PATH"
    fi

    echo "OpenWrt deployment completed successfully."
}

deploy_mikrotik() {
    local MIKROTIK_ISO="mikrotik-${MIKROTIK_VERSION}.iso"
    local MIKROTIK_ISO_URL="https://download.mikrotik.com/routeros/${MIKROTIK_VERSION}/mikrotik-${MIKROTIK_VERSION}.iso"

    # Check if the MikroTik qcow2 image already exists
    if [ -f "$MIKROTIK_QCOW2_IMAGE" ]; then
        echo "File: $MIKROTIK_QCOW2_IMAGE already exists."
        return 0
    fi

    # Download the MikroTik ISO image if it doesn't exist
    download_if_not_exist "$MIKROTIK_ISO_URL" "$MIKROTIK_ISO" || { echo "Failed to download $MIKROTIK_ISO"; return 1; }

    # Create the MikroTik qcow2 image
    echo "Creating MikroTik qcow2 image..."
    qemu-img create -f qcow2 "$MIKROTIK_QCOW2_IMAGE" 200M || { echo "Failed to create qcow2 image"; return 1; }

    # User instructions for the manual installation process
    echo ">>> Starting MikroTik installation. Follow these steps manually:"
    echo ">>> 1. Select 'system', 'dhcp', 'security', 'user-manager' and press [i] to install."
    echo ">>> 2. When prompted, select: 'Do you want to keep old configuration? [y/n]: n'"
    echo ">>> 3. Confirm: 'Warning: all data on the disk will be erased! Continue? [y/n]: y'"
    echo ">>> 4. Press Enter to reboot when prompted."
    echo ">>> 5. Close the QEMU VM after reboot."

    # Launch QEMU for MikroTik installation
    qemu-system-x86_64 \
        -name "MikroTik" \
        -m 128M \
        -cdrom "$MIKROTIK_ISO" \
        -drive file="$MIKROTIK_QCOW2_IMAGE",if=ide \
        -boot d \
        -enable-kvm || { echo "Failed to launch QEMU for MikroTik installation"; return 1; }

    # Remove the ISO after installation
    echo "Cleaning up the ISO..."
    rm -f "$MIKROTIK_ISO" || echo "Failed to delete $MIKROTIK_ISO"

    echo "MikroTik deployment completed."
}

# Deploy both OpenWrt and MikroTik systems
deploy_systems() {
    echo "Deploying systems..."
    deploy_openwrt
    deploy_mikrotik
}

# Helper function to delete a specified interface if it exists
delete_if_exists() {
    local iface_name=$1
    if ip link show "$iface_name" &> /dev/null; then
        sudo ip link set "$iface_name" down
        sudo ip link delete "$iface_name"
        echo "Deleted interface: $iface_name"
    fi
}

# Function to delete interfaces for a specified VM ID
delete_interfaces() {
    local vm_id=$1

    echo "Deleting interfaces for VM $vm_id..."

    # Delete TAP interfaces
    delete_if_exists "tap-${vm_id}-1-wan"
    delete_if_exists "tap-${vm_id}-1-lan"
    delete_if_exists "tap-${vm_id}-2-wan"
    delete_if_exists "tap-${vm_id}-2-lan"

    # Delete network bridges
    delete_if_exists "br-net-${vm_id}"
    delete_if_exists "br-lan-${vm_id}"
}

# Function to delete all interfaces for all VMs
delete_all_interfaces() {
    for vm_id in "${VM_IDS[@]}"; do
        delete_interfaces "$vm_id"
    done
}

# Function to enable internet access
internet_enable() {
    echo "Enabling internet..."
    sudo iptables -t nat -A POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
    sudo sysctl -w net.ipv4.ip_forward=1

    # Allow forwarding between the WAN bridge and the active interface
    sudo iptables -A FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT
    sudo iptables -A FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    debug "Internet enabled with NAT on $ACTIVE_IF"
}

# Function to disable internet access
internet_disable() {
    echo "Disabling internet..."

    if sudo iptables -t nat -C POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE 2>/dev/null; then
        sudo iptables -t nat -D POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE
    fi

    if sudo iptables -C FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT 2>/dev/null; then
        sudo iptables -D FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT
    fi

    if sudo iptables -C FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
        sudo iptables -D FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    fi
}

# Function to start a specific VM by ID for OpenWrt
start_openwrt_vm() {
    local vm_id=$1
    local vm_image="${VM_DIR}/vm_${vm_id}-1_openwrt.qcow2"

    echo "Starting OpenWrt VM ${vm_id}..."

    # Copy template image if VM-specific image doesn't exist
    if [ ! -f "$vm_image" ]; then
        echo "Copying template image"
        cp "${OPENWRT_QCOW2_IMAGE}" "$vm_image"
    else
        echo "VM image for VM ${vm_id} OpenWrt already exists."
    fi

    # Start the VM in a detached screen session with QEMU
    sudo screen -dmS "vm_${vm_id}-1-openwrt" \
    qemu-system-x86_64 \
        -name "OpenWrt ${vm_id}" \
        -m 128M \
        -drive file="$vm_image",id=d0,if=none,bus=0,unit=0,snapshot="$SNAPSHOT" \
        -device ide-hd,drive=d0,bus=ide.0 \
        -netdev tap,id=net1_lan,ifname=tap-${vm_id}-1-lan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net1_lan,id=lan1,mac=$(printf "52:54:00:%02x:01:01" "$vm_id") \
        -netdev tap,id=net1_wan,ifname=tap-${vm_id}-1-wan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net1_wan,id=wan1,mac=$(printf "52:54:00:%02x:01:02" "$vm_id") \
        -enable-kvm \
        -nographic
}

# Function to start a specific VM by ID for MikroTik
start_mikrotik_vm() {
    local vm_id=$1
    local vm_image="${VM_DIR}/vm_${vm_id}-2_mikrotik.qcow2"
    
    echo "Starting MikroTik VM ${vm_id}..."
    
    if [ ! -f "$vm_image" ]; then
        cp "${MIKROTIK_QCOW2_IMAGE}" "$vm_image"
    else
        echo "VM image for VM ${vm_id} MikroTik already exists."
    fi

    sudo screen -dmS "vm_${vm_id}-2-mikrotik" \
    qemu-system-x86_64 \
        -name "MikroTik ${vm_id}" \
        -m 128M \
        -drive file="$vm_image",id=d0,if=none,bus=0,unit=0,snapshot="$SNAPSHOT" \
        -device ide-hd,drive=d0,bus=ide.0 \
        -netdev tap,id=net1_lan,ifname=tap-${vm_id}-2-lan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net1_lan,id=lan1,mac=$(printf "00:0C:42:%02x:02:01" "$vm_id") \
        -netdev tap,id=net1_wan,ifname=tap-${vm_id}-2-wan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net1_wan,id=wan1,mac=$(printf "00:0C:42:%02x:02:02" "$vm_id") \
        -enable-kvm \
        -nographic
}

# Helper function to start both OpenWrt and MikroTik VMs for a specific VM ID
start_vm() {
    local vm_id=$1
    start_openwrt_vm "$vm_id"
    start_mikrotik_vm "$vm_id"
}

# Function to start a specific VM by ID (both OpenWrt and MikroTik)
start_qemu_machine() {
    local valid_ids="${VM_IDS[*]}"  # Store the expanded VM IDs as a string
    read -p "Enter VM ID to start (${valid_ids}): " vm_id
    if is_valid_vm_id "$vm_id"; then
        start_vm "$vm_id"
    else
        echo "Invalid VM ID: $vm_id. It must be within the range of ${valid_ids}."
    fi
}

# Function to start all VMs (both OpenWrt and MikroTik)
start_all_qemu_machines() {
    for vm_id in "${VM_IDS[@]}"; do
        start_vm "$vm_id"
    done
}

# Helper function to stop both OpenWrt and MikroTik VMs for a specific VM ID
stop_vm() {
    local vm_id=$1

    if sudo screen -list | grep -q "vm_${vm_id}-1-openwrt"; then
        sudo screen -S "vm_${vm_id}-1-openwrt" -X quit
        echo "Stopped OpenWrt VM session for VM ID ${vm_id}."
    else
        echo "No active OpenWrt VM session for VM ID ${vm_id}."
    fi

    if sudo screen -list | grep -q "vm_${vm_id}-2-mikrotik"; then
        sudo screen -S "vm_${vm_id}-2-mikrotik" -X quit
        echo "Stopped MikroTik VM session for VM ID ${vm_id}."
    else
        echo "No active MikroTik VM session for VM ID ${vm_id}."
    fi

    delete_interfaces "$vm_id"
}

# Function to stop a specific VM by ID
stop_qemu_machine() {
    local valid_ids="${VM_IDS[*]}"  # Store the expanded VM IDs as a string
    read -p "Enter VM ID to stop (${valid_ids}): " vm_id
    if is_valid_vm_id "$vm_id"; then
        echo "Stopping VM with ID $vm_id..."
        stop_vm "$vm_id"
    else
        echo "Invalid VM ID: $vm_id. It must be within the range of ${valid_ids}."
    fi
}

# Function to stop all VMs
stop_all_qemu_machines() {
    echo "Stopping all VMs..."

    for vm_id in "${VM_IDS[@]}"; do
        stop_vm "$vm_id"
    done

    delete_all_interfaces
    internet_disable
}

check_service_status() {
    if sudo screen -list | grep -q "dnsmasq"; then
        echo "dnsmasq is running."
    else
        echo "dnsmasq is not running."
    fi

    for vm_id in "${VM_IDS[@]}"; do
        if sudo screen -list | grep -q "vm_${vm_id}"; then
            echo "VM ${vm_id} is running."
        else
            echo "VM ${vm_id} is not running."
        fi
    done
}

# Function to display help menu with description
display_help() {
    echo "Script to manage virtual machines (VMs) for OpenWrt and MikroTik environments."
    echo "You can deploy, start, stop VMs, and manage network interfaces."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -d      Enable Debug mode (prints additional debug information)"
    echo "  -w      Enable Writable mode (allows changes to disk)"
    echo "  -h      Display this help message"
    echo ""
    echo "Menu Options:"
    echo "  0) Deploy System        - Download and prepare OpenWrt and MikroTik systems"
    echo "  1) Start VM by ID       - Start a specific VM (OpenWrt and MikroTik)"
    echo "  2) Stop VM by ID        - Stop a specific VM (OpenWrt and MikroTik)"
    echo "  3) Start All VMs        - Start all VMs in the defined range"
    echo "  4) Stop All VMs         - Stop all VMs in the defined range"
    echo "  5) Enable Internet      - Enable NAT and forwarding for the network"
    echo "  6) Disable Internet     - Disable NAT and forwarding for the network"
    echo "  q) Quit                 - Exit the script"
    echo ""
    echo "Examples:"
    echo "  $0 -h           # Display help"
    echo "  $0 -d           # Enable debug mode"
    echo "  $0 -w           # Enable writable mode"
    echo "  $0              # Start the interactive menu"
}

quit() {
    if sudo screen -list | grep -q "dnsmasq"; then
        sudo screen -S "dnsmasq" -X quit
        echo "Stopped dnsmasq"
    else
        echo "No active dnsmasq session"
    fi
    delete_if_exists "${WAN_BRIDGE}"
}

while getopts "dwh" opt; do
    case $opt in
        d)
            DEBUG_MODE=1
            print_system_info
            ;;
        w)
            WRITABLE=1
            ;;
        h)
            display_help
            exit 0
            ;;
        *)
            display_help
            exit 1
            ;;
    esac
done

# Check dependencies before entering the menu loop
check_dependencies
init_script

mkdir -p "${VM_DIR}"

# Menu loop
while true; do
    echo "=========================="
    echo "Menu:"
    echo "=========================="
    echo "0) Deploy System"
    echo "1) Start VM by ID"
    echo "2) Stop VM by ID"
    echo "3) Start All VMs"
    echo "4) Stop All VMs"
    echo "5) Enable Internet"
    echo "6) Disable Internet"
    echo "7) Check Service Status"
    echo "q) Quit"
    echo "=========================="
    
    read -p "Enter your choice: " choice
    case $choice in
        0) deploy_systems ;;
        1) start_qemu_machine ;;
        2) stop_qemu_machine ;;
        3) start_all_qemu_machines ;;
        4) stop_all_qemu_machines ;;
        5) internet_enable ;;
        6) internet_disable ;;
        7) check_service_status ;;
        q) echo "Exiting..."; quit; break ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
