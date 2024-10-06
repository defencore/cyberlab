#!/bin/sh

# Variables
VPN_INTERFACE="wg0"
VPN_PORT="51820"
PEER_ALLOWED_IPS="10.0.0.0/24"  # Allow all clients in the subnet to see each other
ACCOUNTS_FILE=""
RECREATE=false
DELETE=false

# Function to display help
show_help() {
    echo "Usage: $0 [-a accounts_file] [-r] [-d]"
    echo ""
    echo "Options:"
    echo "  -a  Specify the accounts file (required for adding/creating clients)"
    echo "  -r  Recreate WireGuard settings"
    echo "  -d  Delete existing WireGuard settings"
    exit 1
}

# Function to run UCI commands
run_command() {
    echo "Running command: $@"
    "$@"
    if [ $? -ne 0 ]; then
        echo "Error encountered while running: $@"
    fi
}

# Parse options
while getopts "a:rd" opt; do
    case $opt in
        a)
            ACCOUNTS_FILE="$OPTARG"
            ;;
        r)
            RECREATE=true
            ;;
        d)
            DELETE=true
            ;;
        *)
            show_help
            ;;
    esac
done

# Delete WireGuard settings if the -d option is used
if [ "$DELETE" = true ]; then
    echo "Deleting existing WireGuard settings..."

    # Find all WireGuard client sections associated with wg0 and delete them
    for section in $(uci show network | grep "@wireguard_${VPN_INTERFACE}" | cut -d'=' -f1); do
        echo "Deleting section $section"
        run_command uci delete "$section"
    done

    # Delete the main WireGuard interface configuration
    if uci show network.${VPN_INTERFACE} >/dev/null 2>&1; then
        echo "Deleting WireGuard interface $VPN_INTERFACE"
        run_command uci delete network.${VPN_INTERFACE}
    fi

    # Remove firewall rule for WireGuard if it exists
    for rule in $(uci show firewall | grep "Allow-WireGuard" | cut -d'=' -f1); do
        echo "Deleting firewall rule $rule"
        run_command uci delete "$rule"
    done

    run_command uci commit network
    run_command uci commit firewall
    run_command /etc/init.d/network reload
    run_command /etc/init.d/firewall reload

    echo "WireGuard settings and clients deleted."
    exit 0
fi

# Check if the accounts file is provided when creating or adding clients
if [ -z "$ACCOUNTS_FILE" ] && [ "$RECREATE" = false ]; then
    echo "Error: accounts file is required for adding or creating new clients."
    show_help
fi

# Get WAN interface and IP
WAN_INTERFACE=$(uci get network.wan.device 2>/dev/null)
WAN_IP=$(ip -4 addr show $WAN_INTERFACE | grep inet | awk '{print $2}' | cut -d'/' -f1)

if [ -z "$WAN_INTERFACE" ] || [ -z "$WAN_IP" ]; then
    echo "Error: Could not retrieve WAN interface or IP. Exiting."
    exit 1
fi

DNS_SERVER="10.0.0.1"

# Recreate WireGuard configuration if the -r option is used
if [ "$RECREATE" = true ]; then
    echo "Recreating WireGuard configuration..."
    run_command uci delete network.${VPN_INTERFACE}
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)

    # Set up WireGuard server
    run_command uci set network.${VPN_INTERFACE}=interface
    run_command uci set network.${VPN_INTERFACE}.proto='wireguard'
    run_command uci set network.${VPN_INTERFACE}.private_key="$SERVER_PRIVATE_KEY"
    run_command uci set network.${VPN_INTERFACE}.listen_port="$VPN_PORT"
    run_command uci set network.${VPN_INTERFACE}.addresses="10.0.0.1/24"
    run_command uci commit network

    echo "WireGuard server recreated with new keys."
fi

# Enable IP forwarding
run_command sysctl -w net.ipv4.ip_forward=1
run_command sysctl -w net.ipv6.conf.all.forwarding=1

# Add clients from the accounts file if provided
if [ -n "$ACCOUNTS_FILE" ]; then
    INDEX=1
    while read -r EMAIL; do
        if [ -z "$EMAIL" ]; then
            continue
        fi

        echo "Processing client $INDEX with email $EMAIL"

        # Generate private and public keys for the client
        CLIENT_PRIVATE_KEY=$(wg genkey)
        CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
        CLIENT_IP="10.0.0.$((INDEX + 1))/32"

        # Check if the client already exists by checking both public key and description (email)
        if uci show network | grep -q "$CLIENT_PUBLIC_KEY" || uci show network | grep -q "$EMAIL"; then
            echo "Client $EMAIL with public key $CLIENT_PUBLIC_KEY already exists. Skipping."
        else
            # Create client configuration file
            cat << EOF > ./client_configs/client_${INDEX}.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = $DNS_SERVER

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = $PEER_ALLOWED_IPS
Endpoint = $WAN_IP:$VPN_PORT
PersistentKeepalive = 25
EOF

            echo "Adding client $INDEX with public key $CLIENT_PUBLIC_KEY to WireGuard server"
            PEER_ID=$(uci add network wireguard_${VPN_INTERFACE})
            run_command uci set network.${PEER_ID}.public_key="$CLIENT_PUBLIC_KEY"
            run_command uci set network.${PEER_ID}.allowed_ips="$CLIENT_IP"
            run_command uci set network.${PEER_ID}.description="$EMAIL"
            run_command uci commit network
        fi

        INDEX=$((INDEX + 1))
    done < "$ACCOUNTS_FILE"
fi

# Restart network configuration
echo "Restarting network configuration..."
run_command /etc/init.d/network reload

# Configure firewall rules if needed
run_command uci show firewall | grep -q "Allow-WireGuard"
if [ $? -ne 0 ]; then
    echo "Adding firewall rule for WireGuard"
    run_command uci add firewall rule
    run_command uci set firewall.@rule[-1].name="Allow-WireGuard"
    run_command uci set firewall.@rule[-1].src="wan"
    run_command uci set firewall.@rule[-1].target="ACCEPT"
    run_command uci set firewall.@rule[-1].proto="udp"
    run_command uci set firewall.@rule[-1].dest_port="$VPN_PORT"
    run_command uci commit firewall
else
    echo "Firewall rule for WireGuard already exists. Skipping."
fi

# Restart firewall
echo "Restarting firewall..."
run_command /etc/init.d/firewall reload

echo "WireGuard clients added successfully!"
