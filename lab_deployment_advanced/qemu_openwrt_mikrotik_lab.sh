#!/bin/bash

WRITABLE=0  # 0 = No changes written to disk, 1 = Write allowed

OPENWRT_VERSION="23.05.0"
MIKROTIK_VERSION="6.40"
OPENWRT_QCOW2_IMAGE="openwrt-${OPENWRT_VERSION}.qcow2"
MIKROTIK_QCOW2_IMAGE="mikrotik-${MIKROTIK_VERSION}.qcow2"

PHY_IF="eth0"
WAN_BRIDGE="br-wan"
BR_WAN_IP="172.16.1.1/24"
LAN_VLAN_BASE=200

VM_IDS=( {9..24} )
VM_DIR="vms"

# Exit script on any error
set -e

debug(){
    echo "Not implemented"
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
        sudo ifconfig "$WAN_BRIDGE" "$BR_WAN_IP"
    fi

    # Kill any running dnsmasq processes that are bound to the interface or IP
    # echo "Stopping any existing dnsmasq processes on $WAN_BRIDGE or $DNSMASQ_IP..."
    sudo pkill -f "dnsmasq.*--interface=$WAN_BRIDGE" || echo "No existing dnsmasq processes found."

    # Start dnsmasq in a new screen session
    # echo "Starting dnsmasq in a new screen session..."
    sudo screen -dmS "dnsmasq" \
        dnsmasq --interface="$WAN_BRIDGE" \
        --bind-interfaces \
        --listen-address="$DNSMASQ_IP" \
        --dhcp-range="$DHCP_RANGE_START,$DHCP_RANGE_END,12h" \
        --no-daemon
    
    # echo "Initialization complete."
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

# Function to create bridges if they don't already exist
create_bridge() {
    local bridge_name=$1
    if ! ip link show "$bridge_name" &> /dev/null; then
        echo "Creating bridge $bridge_name..."
        sudo brctl addbr "$bridge_name"
        sudo ip link set dev "$bridge_name" up
    else
        echo "Bridge $bridge_name already exists."
    fi
}

# Function to create TAP interfaces
create_tap_interface() {
    local tap_if=$1
    if ! ip link show "$tap_if" &> /dev/null; then
        echo "Creating TAP interface $tap_if..."
        sudo ip tuntap add dev "$tap_if" mode tap
        sudo ip link set "$tap_if" up
    else
        echo "TAP interface $tap_if already exists."
    fi
}

# Function to check if vm_id is valid and within VM_IDS
is_valid_vm_id() {
    local vm_id=$1
    for id in "${VM_IDS[@]}"; do
        if [[ "$id" -eq "$vm_id" ]]; then
            return 0  # vm_id is valid
        fi
    done
    return 1  # vm_id is not valid
}

create_interfaces() {
    local vm_id=$1
    if is_valid_vm_id "$vm_id"; then
        local vlan_id=$((LAN_VLAN_BASE + $vm_id))
        local vlan_if="${PHY_IF}.${vlan_id}"

        echo "Creating interfaces for VM $vm_id..."

        # Create network bridges if they don't already exist
        create_bridge "br-net-${vm_id}"
        create_bridge "br-lan-${vm_id}"

        # Create TAP interfaces
        create_tap_interface "tap-${vm_id}-1-wan"
        create_tap_interface "tap-${vm_id}-1-lan"
        create_tap_interface "tap-${vm_id}-2-wan"
        create_tap_interface "tap-${vm_id}-2-lan"

        # Add TAP interfaces to bridges only if not already added
        if ! brctl show "$WAN_BRIDGE" | grep -q "tap-${vm_id}-1-wan"; then
            sudo brctl addif $WAN_BRIDGE "tap-${vm_id}-1-wan"
        else
            echo "TAP interface tap-${vm_id}-1-wan is already a member of $WAN_BRIDGE."
        fi
        
        if ! brctl show "br-net-${vm_id}" | grep -q "tap-${vm_id}-1-lan"; then
            sudo brctl addif "br-net-${vm_id}" "tap-${vm_id}-1-lan"
        else
            echo "TAP interface tap-${vm_id}-1-lan is already a member of br-net-${vm_id}."
        fi

        if ! brctl show "br-net-${vm_id}" | grep -q "tap-${vm_id}-2-wan"; then
            sudo brctl addif "br-net-${vm_id}" "tap-${vm_id}-2-wan"
        else
            echo "TAP interface tap-${vm_id}-2-wan is already a member of br-net-${vm_id}."
        fi

        if ! brctl show "br-lan-${vm_id}" | grep -q "tap-${vm_id}-2-lan"; then
            sudo brctl addif "br-lan-${vm_id}" "tap-${vm_id}-2-lan"
        else
            echo "TAP interface tap-${vm_id}-2-lan is already a member of br-lan-${vm_id}."
        fi

        # Create and configure VLAN if it doesn't already exist
        echo "Creating VLAN: $vlan_if"
        if ! ip link show "$vlan_if" &> /dev/null; then
            sudo ip link add link "$PHY_IF" name "$vlan_if" type vlan id "$vlan_id"
            sudo ip link set dev "$vlan_if" up
            sudo brctl addif "br-lan-${vm_id}" "$vlan_if"
        else
            echo "VLAN interface $vlan_if already exists."
        fi
    else
        echo "Invalid VM ID: $vm_id. It must be within the range of ${VM_IDS[@]}."
    fi
}

# Function to delete interfaces for the specified range of VM IDs
delete_interfaces() {
        local vlan_id=$((LAN_VLAN_BASE + $vm_id))
        local vlan_if="${PHY_IF}.${vlan_id}"

        echo "Deleting interfaces for VM $vm_id..."

        # Check and remove TAP interfaces only if they exist
        if ip link show "tap-${vm_id}-1-wan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-1-wan" down
            sudo ip link delete "tap-${vm_id}-1-wan"
        fi
        if ip link show "tap-${vm_id}-1-lan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-1-lan" down
            sudo ip link delete "tap-${vm_id}-1-lan"
        fi
        if ip link show "tap-${vm_id}-2-wan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-2-wan" down
            sudo ip link delete "tap-${vm_id}-2-wan"
        fi
        if ip link show "tap-${vm_id}-2-lan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-2-lan" down
            sudo ip link delete "tap-${vm_id}-2-lan"
        fi

        # Remove network bridges
        if ip link show "br-net-${vm_id}" &> /dev/null; then
            sudo ip link set "br-net-${vm_id}" down
            sudo brctl delbr "br-net-${vm_id}"
        fi
        if ip link show "br-lan-${vm_id}" &> /dev/null; then
            sudo ip link set "br-lan-${vm_id}" down
            sudo brctl delbr "br-lan-${vm_id}"
        fi

        # Remove VLAN
        if ip link show "$vlan_if" &> /dev/null; then
            sudo ip link set dev "$vlan_if" down
            sudo ip link delete "$vlan_if"
            echo "Deleted VLAN: $vlan_if"
        fi
}

# Function to delete all interfaces for all VMs
delete_all_interfaces() {
    for vm_id in "${VM_IDS[@]}"; do
        local vlan_id=$((LAN_VLAN_BASE + $vm_id))
        local vlan_if="${PHY_IF}.${vlan_id}"

        echo "Deleting interfaces for VM $vm_id..."

        # Check and remove TAP interfaces only if they exist
        if ip link show "tap-${vm_id}-1-wan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-1-wan" down
            sudo ip link delete "tap-${vm_id}-1-wan"
        fi
        if ip link show "tap-${vm_id}-1-lan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-1-lan" down
            sudo ip link delete "tap-${vm_id}-1-lan"
        fi
        if ip link show "tap-${vm_id}-2-wan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-2-wan" down
            sudo ip link delete "tap-${vm_id}-2-wan"
        fi
        if ip link show "tap-${vm_id}-2-lan" &> /dev/null; then
            sudo ip link set "tap-${vm_id}-2-lan" down
            sudo ip link delete "tap-${vm_id}-2-lan"
        fi

        # Remove network bridges
        if ip link show "br-net-${vm_id}" &> /dev/null; then
            sudo ip link set "br-net-${vm_id}" down
            sudo brctl delbr "br-net-${vm_id}"
        fi
        if ip link show "br-lan-${vm_id}" &> /dev/null; then
            sudo ip link set "br-lan-${vm_id}" down
            sudo brctl delbr "br-lan-${vm_id}"
        fi

        # Remove VLAN
        if ip link show "$vlan_if" &> /dev/null; then
            sudo ip link set dev "$vlan_if" down
            sudo ip link delete "$vlan_if"
            echo "Deleted VLAN: $vlan_if"
        fi
    done
}

# Function to detect the active Internet interface if it's not provided as an argument
detect_active_interface() {
    ACTIVE_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -z "$ACTIVE_IF" ]; then
        echo "Error: Could not determine the active Internet interface."
        exit 1
    fi
    echo "Detected active interface: $ACTIVE_IF"
}

# Function to enable internet access
internet_enable() {
    echo "Enabling internet..."
    # Add actual internet enable commands here
     # Detect the active interface if it wasn't provided
    if [ -z "$ACTIVE_IF" ]; then
        detect_active_interface
    fi
    # Set up NAT for traffic going out through the active interface
    sudo iptables -t nat -A POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
    sudo sysctl -w net.ipv4.ip_forward=1

    # Allow forwarding between the WAN bridge and the active interface
    sudo iptables -A FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT
    sudo iptables -A FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT

}

# Function to disable internet access
internet_disable() {
    echo "Disabling internet..."

    # Check and remove iptables POSTROUTING rule if it exists
    if sudo iptables -t nat -C POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE 2>/dev/null; then
        sudo iptables -t nat -D POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE
    else
        echo "No matching POSTROUTING rule found in the NAT table."
    fi

    # Check and remove FORWARD rule (WAN_BRIDGE -> ACTIVE_IF) if it exists
    if sudo iptables -C FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT 2>/dev/null; then
        sudo iptables -D FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT
    else
        echo "No matching FORWARD rule (WAN_BRIDGE -> ACTIVE_IF) found."
    fi

    # Check and remove FORWARD rule (ACTIVE_IF -> WAN_BRIDGE) if it exists
    if sudo iptables -C FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
        sudo iptables -D FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    else
        echo "No matching FORWARD rule (ACTIVE_IF -> WAN_BRIDGE) found."
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
    
    # Copy template image if VM-specific image doesn't exist
    if [ ! -f "$vm_image" ]; then
        cp "${MIKROTIK_QCOW2_IMAGE}" "$vm_image"
    else
        echo "VM image for VM ${vm_id} MikroTik already exists."
    fi

    # Start the VM in a detached screen session with QEMU
    sudo screen -dmS "vm_${vm_id}-2-mikrotik" \
    qemu-system-x86_64 \
        -name "MikroTik ${vm_id}" \
        -m 128M \
        -drive file="$vm_image",id=d0,if=none,bus=0,unit=0,snapshot="$SNAPSHOT" \
        -device ide-hd,drive=d0,bus=ide.0 \
        -netdev tap,id=net1_lan,ifname=tap-${vm_id}-2-lan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net1_lan,id=lan1,mac=$(printf "52:54:00:%02x:02:01" "$vm_id") \
        -netdev tap,id=net1_wan,ifname=tap-${vm_id}-2-wan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net1_wan,id=wan1,mac=$(printf "52:54:00:%02x:02:02" "$vm_id") \
        -enable-kvm \
        -nographic
}

# Function to start a specific VM by ID (both OpenWrt and MikroTik)
start_qemu_machine() {
    local valid_ids="${VM_IDS[*]}"  # Store the expanded VM IDs as a string
    read -p "Enter VM ID to start (${valid_ids}): " vm_id
    if is_valid_vm_id "$vm_id"; then
        create_interfaces "$vm_id"
        # Start OpenWrt VM
        start_openwrt_vm "$vm_id"
        # Start MikroTik VM
        start_mikrotik_vm "$vm_id"
    else
        echo "Invalid VM ID: $vm_id. It must be within the range of ${valid_ids}."
    fi
}

# Function to stop a specific VM by ID
stop_qemu_machine() {
    local valid_ids="${VM_IDS[*]}"  # Store the expanded VM IDs as a string
    read -p "Enter VM ID to stop (${valid_ids}): " vm_id
    if is_valid_vm_id "$vm_id"; then
        echo "Stopping VM with ID $vm_id..."
                # Check if the OpenWrt VM screen session exists before trying to stop it
        if sudo screen -list | grep -q "vm_${vm_id}-1-openwrt"; then
            sudo screen -S "vm_${vm_id}-1-openwrt" -X quit
        else
            echo "No active OpenWrt VM session for VM ID ${vm_id}."
        fi
        
        # Check if the MikroTik VM screen session exists before trying to stop it
        if sudo screen -list | grep -q "vm_${vm_id}-2-mikrotik"; then
            sudo screen -S "vm_${vm_id}-2-mikrotik" -X quit
        else
            echo "No active MikroTik VM session for VM ID ${vm_id}."
        fi
        delete_interfaces "$vm_id"
    else
        echo "Invalid VM ID: $vm_id. It must be within the range of ${valid_ids}."
    fi
}

# Function to start all VMs (both OpenWrt and MikroTik)
start_all_qemu_machines() {
    for vm_id in "${VM_IDS[@]}"; do
        create_interfaces "$vm_id"
        start_openwrt_vm "$vm_id"
        start_mikrotik_vm "$vm_id"
    done
}

# Function to stop all VMs
stop_all_qemu_machines() {
    echo "Stopping all VMs..."

    for vm_id in "${VM_IDS[@]}"; do
        # Check and stop OpenWrt VM if the screen session exists
        if sudo screen -list | grep -q "vm_${vm_id}-1-openwrt"; then
            sudo screen -S "vm_${vm_id}-1-openwrt" -X quit
            echo "Stopped OpenWrt VM session for VM ID ${vm_id}."
        else
            echo "No active OpenWrt VM session for VM ID ${vm_id}."
        fi
        
        # Check and stop MikroTik VM if the screen session exists
        if sudo screen -list | grep -q "vm_${vm_id}-2-mikrotik"; then
            sudo screen -S "vm_${vm_id}-2-mikrotik" -X quit
            echo "Stopped MikroTik VM session for VM ID ${vm_id}."
        else
            echo "No active MikroTik VM session for VM ID ${vm_id}."
        fi
    done

    # Delete all network interfaces
    delete_all_interfaces
    internet_disable
}

# Function to display help menu
display_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -d      Enable Debug (not implemented)"
    echo "  -h      Display this help message"
    echo ""
    echo "Menu:"
    echo "  0) Deploy System"
    echo "  1) Start VM by ID"
    echo "  2) Stop VM by ID"
    echo "  3) Start VMs"
    echo "  4) Stop VMs"
    echo "  5) Enable Internet"
    echo "  6) Disable Internet"
    echo "  q) Quit"
}

while getopts "d:h" opt; do
    case $opt in
        d)
            debug
            exit 0
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
    echo "Menu:"
    echo "0) Deploy System"
    echo "1) Start VM by ID"
    echo "2) Stop VM by ID"
    echo "3) Start All VMs"
    echo "4) Stop All VMs"
    echo "5) Enable Internet"
    echo "6) Disable Internet"
    echo "q) Quit"
    
    read -p "Enter your choice: " choice
    case $choice in
        0) deploy_systems ;;
        1) start_qemu_machine ;;
        2) stop_qemu_machine ;;
        3) start_all_qemu_machines ;;
        4) stop_all_qemu_machines ;;
        5) internet_enable ;;
        6) internet_disable ;;
        q) echo "Exiting..."; break ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
