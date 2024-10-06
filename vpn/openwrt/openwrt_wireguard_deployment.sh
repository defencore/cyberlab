#!/bin/sh

# WireGuard parameters
VPN_INTERFACE="wg0"
VPN_ADDRESS="10.0.0.1/24"
VPN_PORT="51820"
PEER_ALLOWED_IPS="10.0.0.0/24"  # Allow all clients in the subnet to see each other

# Debug function to log UCI commands
run_command() {
    echo "Running command: $@"
    "$@"
    if [ $? -ne 0 ]; then
        echo "Error encountered while running: $@"
    fi
}

# Get the WAN interface from UCI
WAN_INTERFACE=$(uci get network.wan.device 2>/dev/null)
echo "WAN interface: $WAN_INTERFACE"

# Retrieve the WAN IP address dynamically from the system (since it's assigned via DHCP)
WAN_IP=$(ip -4 addr show $WAN_INTERFACE | grep inet | awk '{print $2}' | cut -d'/' -f1)
echo "WAN IP: $WAN_IP"

# Check if WAN interface and IP were retrieved successfully
if [ -z "$WAN_INTERFACE" ] || [ -z "$WAN_IP" ]; then
    echo "Error: Could not retrieve WAN interface or IP. Exiting."
    exit 1
fi

DNS_SERVER="10.0.0.1"  # Optionally set a DNS server

# File with the list of client accounts
ACCOUNTS_FILE="accounts.txt"

# Create a directory for client configurations
mkdir -p client_configs

# Generate keys for the WireGuard server (if not already generated)
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
echo "Server private key: $SERVER_PRIVATE_KEY"
echo "Server public key: $SERVER_PUBLIC_KEY"

# Check if the WireGuard interface is already defined in UCI
run_command uci show network.${VPN_INTERFACE}
if [ $? -ne 0 ]; then
    echo "Creating WireGuard interface $VPN_INTERFACE"
    run_command uci set network.${VPN_INTERFACE}=interface
    run_command uci set network.${VPN_INTERFACE}.proto='wireguard'
    run_command uci set network.${VPN_INTERFACE}.private_key="$SERVER_PRIVATE_KEY"
    run_command uci set network.${VPN_INTERFACE}.listen_port="$VPN_PORT"
    run_command uci set network.${VPN_INTERFACE}.addresses="$VPN_ADDRESS"
    run_command uci commit network
else
    echo "WireGuard interface $VPN_INTERFACE already exists. Skipping creation."
fi

# Restart network services
echo "Restarting network services..."
run_command /etc/init.d/network reload

# Enable IP forwarding directly using sysctl
echo "Enabling IPv4 and IPv6 forwarding"
run_command sysctl -w net.ipv4.ip_forward=1
run_command sysctl -w net.ipv6.conf.all.forwarding=1

# Generate client configurations
INDEX=1
while read -r EMAIL; do
    echo "Processing client $INDEX with email $EMAIL"

    # Generate private and public keys for the client
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
    echo "Client private key: $CLIENT_PRIVATE_KEY"
    echo "Client public key: $CLIENT_PUBLIC_KEY"

    # Assign an IP for each client
    CLIENT_IP="10.0.0.$((INDEX + 1))/32"
    echo "Client IP: $CLIENT_IP"

    # Create the client configuration file
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

    # Check if the client has already been added to the WireGuard server
    run_command uci show network | grep -q "$CLIENT_PUBLIC_KEY"
    if [ $? -ne 0 ]; then
        echo "Adding client $INDEX with public key $CLIENT_PUBLIC_KEY to WireGuard server"
        PEER_ID=$(uci add network wireguard_${VPN_INTERFACE})
        run_command uci set network.${PEER_ID}.public_key="$CLIENT_PUBLIC_KEY"
        run_command uci set network.${PEER_ID}.allowed_ips="$CLIENT_IP"
        run_command uci commit network
    else
        echo "Client $EMAIL with public key $CLIENT_PUBLIC_KEY already exists. Skipping."
    fi

    INDEX=$((INDEX + 1))
done < "$ACCOUNTS_FILE"

# Restart network configuration
echo "Restarting network configuration..."
run_command /etc/init.d/network reload

# Configure firewall rules to allow VPN traffic (only if not already set)
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

# Restart the firewall
echo "Restarting firewall..."
run_command /etc/init.d/firewall reload

echo "WireGuard server configured!"
echo "Server public key: $SERVER_PUBLIC_KEY"
