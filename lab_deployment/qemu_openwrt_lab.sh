#!/bin/bash
# This script automates the creation and management of OpenWRT virtual machines (VMs) using QEMU. 
# It sets up VLANs for WAN and LAN traffic, configures network bridges, and handles NAT and DHCP for WAN connectivity.
# The script also allows starting, stopping, and managing individual or multiple VMs with VLAN isolation for network traffic.

# Exit script on any error
set -e

# Variables holding details about the OpenWRT image file
OPENWRT_VERSION="23.05.0"
COMPRESSED_IMAGE="openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-combined.img.gz"
IMAGE_PATH="openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-combined.img"
IMAGE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/x86/64/openwrt-${OPENWRT_VERSION}-x86-64-generic-ext4-combined.img.gz"

# VLAN-related variables:
# WAN_VLAN: VLAN ID for WAN traffic
WAN_VLAN=200
# LAN_VLAN_BASE: Base VLAN ID for LAN traffic (increments for each VM)
LAN_VLAN_BASE=201
# NUM_MACHINES: Number of virtual machines to be created
NUM_MACHINES=16
# PHY_IF: The physical network interface (e.g., eth0)
PHY_IF="eth0"
# BRIDGE_IF: LAN bridge interface name
BRIDGE_IF="br-lan"
# WAN_BRIDGE: WAN bridge interface name
WAN_BRIDGE="br-wan"
# BR_WAN_IP: IP address for the WAN bridge
BR_WAN_IP="192.168.100.1/24"
# LAN_VLAN_COUNT: Number of VLANs for LAN based on the number of machines
LAN_VLAN_COUNT=$((LAN_VLAN_BASE + NUM_MACHINES - 1))

# Directories for storing VM images and snapshots
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
VM_STORAGE="$SCRIPT_DIR/vms"

# ACTIVE_IF: The active Internet interface passed as an argument (optional)
ACTIVE_IF="$1"

# Create directories for VM storage and snapshots
mkdir -p "$VM_STORAGE"

# Function to display help information
display_help() {
    echo "Usage: $0 {start|stop|internet|stop_internet|stop_id <id>} [active_interface]"
    echo
    echo "Commands:"
    echo "  start          - Start all virtual machines and set up networking."
    echo "  stop           - Stop all virtual machines and clean up networking."
    echo "  internet       - Set up NAT and networking for the WAN bridge."
    echo "  stop_internet  - Stop NAT and networking for the WAN bridge."
    echo "  stop_id <id>   - Stop a specific virtual machine by its ID."
    echo "  help           - Display this help message."
    echo ""
    list_running_vms
    exit 0
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

# Function to detect the active Internet interface if it's not provided as an argument
detect_active_interface() {
    ACTIVE_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -z "$ACTIVE_IF" ]; then
        echo "Error: Could not determine the active Internet interface."
        exit 1
    fi
    echo "Detected active interface: $ACTIVE_IF"
}

# Ensure all required dependencies are available
check_dependencies

# Function to download, uncompress, convert, and resize the OpenWRT image
prepare_image() {
    # Download the compressed OpenWRT image if it doesn't already exist locally
    if [ ! -f "$COMPRESSED_IMAGE" ] || [ ! -f "$$QCOW2_IMAGE" ]; then
        wget "$IMAGE_URL" -O "$COMPRESSED_IMAGE"
    fi

    # Uncompress the image if the uncompressed image is not available
    sleep 2
    if [ ! -f "$IMAGE_PATH" ]; then
        gunzip -k "$COMPRESSED_IMAGE" || echo "File was extracted."
    fi

    # Convert the raw image to qcow2 format and resize it
    QCOW2_IMAGE="${IMAGE_PATH%.img}.qcow2"
    if [ ! -f "$QCOW2_IMAGE" ]; then
        echo "Converting and resizing the image..."
        sleep 1
        qemu-img convert -f raw -O qcow2 "$IMAGE_PATH" "$QCOW2_IMAGE"
        qemu-img resize "$QCOW2_IMAGE" 200M
        rm -rf $IMAGE_PATH $COMPRESSED_IMAGE
    fi
}

# Create WAN bridge and add the physical interface to it. Also, create the LAN bridge if it doesn't exist.
create_bridge_and_if() {
    # Create WAN bridge if it doesn't exist
    if ! ip link show "$WAN_BRIDGE" &> /dev/null; then
        sudo ip link add name "$WAN_BRIDGE" type bridge
        sudo ip link set dev "$WAN_BRIDGE" up
    fi

    # Add physical interface (e.g., eth0) to WAN bridge if it's not already part of it
    if ! sudo bridge link | grep -q "$PHY_IF"; then
        sudo ip link set dev "$PHY_IF" master "$WAN_BRIDGE"
        sudo ip link set dev "$PHY_IF" up
    fi

    # Create LAN bridge if it doesn't exist
    if ! ip link show "$BRIDGE_IF" &> /dev/null; then
        sudo ip link add name "$BRIDGE_IF" type bridge
        sudo ip link set dev "$BRIDGE_IF" up
    fi
}

# Function to create LAN bridges for each virtual machine
create_lan_bridge() {
    local lan_bridge=$1
    # Create LAN bridge if it doesn't exist
    if ! ip link show "$lan_bridge" &> /dev/null; then
        sudo ip link add name "$lan_bridge" type bridge
        sudo ip link set dev "$lan_bridge" up
    fi
}

# Function to add VLANs to the physical interface (eth0) for each VM's LAN
add_vlans_to_eth0() {
    for ((i=1; i<=NUM_MACHINES; i++)); do
        local vlan_id=$((LAN_VLAN_BASE + i - 1))
        local lan_bridge="br-lan-$i"
        local vlan_if="${PHY_IF}.${vlan_id}"

        # Create the LAN bridge for the VM
        create_lan_bridge "$lan_bridge"

        # Create VLAN interface if it doesn't exist
        if ! ip link show "$vlan_if" &> /dev/null; then
            sudo ip link add link "$PHY_IF" name "$vlan_if" type vlan id "$vlan_id"
            sudo ip link set dev "$vlan_if" up
        fi

        # Add the VLAN interface to the corresponding LAN bridge
        sudo ip link set dev "$vlan_if" master "$lan_bridge"
    done
}

# Function to create TAP interface for a VM and attach it to the specified bridge
create_tap() {
    local tap_name=$1
    local bridge_name=$2

    # Delete TAP interface if it already exists
    if ip link show "$tap_name" &> /dev/null; then
        sudo ip link delete "$tap_name"
    fi

    # Create new TAP interface and attach it to the bridge
    sudo ip tuntap add dev "$tap_name" mode tap
    sudo ip link set "$tap_name" up
    sudo ip link set "$tap_name" master "$bridge_name"
}

# Function to remove TAP interfaces for VMs
remove_tap() {
    local tap_name=$1

    # Remove TAP interface if it exists
    if ip link show "$tap_name" &> /dev/null; then
        sudo ip link delete "$tap_name"
    fi
}

# Function to start a virtual machine, assign LAN and WAN TAP interfaces, and attach them to the appropriate bridge
start_vm() {
    local id=$1
    local lan_bridge="br-lan-$id"

    # Create TAP interfaces for WAN and LAN and assign them to respective bridges
    create_tap "tap${id}_wan" "$WAN_BRIDGE"
    create_lan_bridge "$lan_bridge"
    create_tap "tap${id}_lan" "$lan_bridge"

    # Create the VM disk image if it doesn't exist
    VM_IMAGE="$VM_STORAGE/vm${id}.qcow2"
    if [ ! -f "$VM_IMAGE" ]; then
        # Copy the converted QCOW2 image to the VM storage
        cp "$QCOW2_IMAGE" "$VM_IMAGE"
    fi

    # Start the VM in a detached screen session with QEMU
    sudo screen -dmS "openwrt_vm_${id}" \
    qemu-system-x86_64 \
        -name "openwrt_vm_${id}" \
        -m 128M \
        -drive file="$VM_IMAGE",id=d0,if=none,bus=0,unit=0 \
        -device ide-hd,drive=d0,bus=ide.0 \
        -netdev tap,id=net${id}_lan,ifname=tap${id}_lan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net${id}_lan,id=lan${id},mac=$(printf "52:54:00:%02x:00:01" "$id") \
        -netdev tap,id=net${id}_wan,ifname=tap${id}_wan,script=no,downscript=no \
        -device virtio-net-pci,netdev=net${id}_wan,id=wan${id},mac=$(printf "52:54:00:%02x:00:02" "$id") \
        -enable-kvm \
        -nographic
}

# Function to stop a virtual machine and remove its TAP interfaces
stop_vm() {
    local id=$1

    # Stop the VM by quitting the screen session
    sudo screen -S "openwrt_vm_${id}" -X quit

    # Remove TAP interfaces for WAN and LAN
    remove_tap "tap${id}_wan"
    remove_tap "tap${id}_lan"

    # Delete the LAN bridge
    local lan_bridge="br-lan-$id"
    if ip link show "$lan_bridge" &> /dev/null; then
        sudo ip link delete "$lan_bridge"
    fi
}

# Function to list all running virtual machines
list_running_vms() {
    # List all screen sessions associated with virtual machines
    local sessions=$(sudo screen -list  | awk '{print $1}' | grep -o 'openwrt.*')
    
    if [ -z "$sessions" ]; then
        echo "No running virtual machines found."
    else
        echo "Running virtual machines:"
        echo "$sessions"
        echo ""
        echo "sudo screen -r openwrt_vm_XX"
    fi
}

# Function to stop all running virtual machines
stop_all_vms() {
    # Get the list of all active VM screen sessions
    local sessions=$(sudo screen -list | grep "openwrt_vm_" | awk -F '.' '{print $1}' | awk '{print $1}')

    # Iterate over each session and stop it
    for session_id in $sessions; do
        if [ ! -z "$session_id" ]; then
            echo "Stopping screen session with ID: $session_id"
            sudo screen -S "$session_id" -X quit
        fi
    done

    # Clean up any network interfaces and VLANs associated with the VMs
    for ((i=1; i<=NUM_MACHINES; i++)); do
        # Remove TAP interfaces for WAN and LAN
        remove_tap "tap${i}_wan"
        remove_tap "tap${i}_lan"

        # Delete the LAN bridge
        local lan_bridge="br-lan-$i"
        if ip link show "$lan_bridge" &> /dev/null; then
            sudo ip link delete "$lan_bridge"
        fi

        # Delete the corresponding VLAN interface for each VM
        local vlan_id=$((LAN_VLAN_BASE + i - 1))
        local vlan_if="${PHY_IF}.${vlan_id}"
        if ip link show "$vlan_if" &> /dev/null; then
            sudo ip link delete "$vlan_if"
        fi
    done
}

# Function to set up NAT and IP forwarding for WAN bridge, and start dnsmasq for DHCP
setup_networking() {
    # Detect the active interface if it wasn't provided
    if [ -z "$ACTIVE_IF" ]; then
        detect_active_interface
    fi

    # Extract base IP and subnet mask from BR_WAN_IP (e.g., 192.168.100.1/24 -> 192.168.100.1 and 24)
    IFS='/' read -r base_ip subnet <<< "$BR_WAN_IP"
    
    # Extract the network prefix for the IP address (e.g., 192.168.100 from 192.168.100.1)
    ip_prefix=$(echo "$base_ip" | cut -d '.' -f 1-3)

    # Define the start and end of the DHCP range
    dhcp_start="${ip_prefix}.10"
    dhcp_end="${ip_prefix}.50"

    # Set up NAT for traffic going out through the active interface
    sudo iptables -t nat -A POSTROUTING -o "$ACTIVE_IF" -j MASQUERADE
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
    sudo sysctl -w net.ipv4.ip_forward=1

    # Allow forwarding between the WAN bridge and the active interface
    sudo iptables -A FORWARD -i "$WAN_BRIDGE" -o "$ACTIVE_IF" -j ACCEPT
    sudo iptables -A FORWARD -i "$ACTIVE_IF" -o "$WAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT

    # Assign IP address to the WAN bridge
    sudo ip addr add "$BR_WAN_IP" dev "$WAN_BRIDGE"

    # Start dnsmasq with dynamically generated DHCP range
    sudo dnsmasq --interface="$WAN_BRIDGE" \
        --bind-interfaces \
        --listen-address="$base_ip" \
        --dhcp-range="$dhcp_start,$dhcp_end,12h" \
        --no-daemon &
}


# Stop networking and remove bridge interfaces
stop_networking() {
    sudo killall dnsmasq || echo "dnsmasq is not running."

    # Remove IP address from the WAN bridge if it exists
    if ip addr show "$WAN_BRIDGE" &> /dev/null; then
        sudo ip addr del "$BR_WAN_IP" dev "$WAN_BRIDGE" || echo "IP address $BR_WAN_IP is not assigned."
    else
        echo "WAN bridge $WAN_BRIDGE does not exist."
    fi

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

    # Ensure WAN bridge is brought down before deletion if it exists
    if ip link show "$WAN_BRIDGE" &> /dev/null; then
        sudo ip link set "$WAN_BRIDGE" down
        sudo ip link delete "$WAN_BRIDGE"
    else
        echo "WAN bridge $WAN_BRIDGE does not exist."
    fi

    # Ensure the main LAN bridge is brought down before deletion if it exists
    if ip link show "$BRIDGE_IF" &> /dev/null; then
        sudo ip link set "$BRIDGE_IF" down
        sudo ip link delete "$BRIDGE_IF"
    else
        echo "LAN bridge $BRIDGE_IF does not exist."
    fi
}


# Handle script execution based on the provided arguments
case $1 in
    start)
        prepare_image
        create_bridge_and_if
        add_vlans_to_eth0
        setup_networking
        for ((i=1; i<=NUM_MACHINES; i++)); do
            start_vm "$i"
        done
        ;;
    stop)
        stop_all_vms
        stop_networking
        sudo ip link set "$PHY_IF" nomaster
        ;;
    internet)
        setup_networking
        ;;
    stop_internet)
        stop_networking
        ;;
    stop_id)
        if [ -z "$2" ]; then
            echo "Usage: $0 stop_id <id>"
            exit 1
        fi
        stop_vm "$2"
        ;;
    help)
        display_help
        ;;
    *)
        display_help
        ;;
esac
