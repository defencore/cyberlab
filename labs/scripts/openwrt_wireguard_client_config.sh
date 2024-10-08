#!/bin/sh

# This script configures WireGuard VPN on an OpenWrt router using UCI.
# It reads the VPN configuration from a provided file (-c option), sets up the WireGuard interface (wg0),
# adds it to the WAN zone, applies firewall rules, and configures default routes for allowed IPs.
# Additionally, it can remove WireGuard settings using the -r option.

CONFIG_FILE=""
REMOVE_CONFIG=0

# Function to remove existing WireGuard settings
remove_wireguard() {
  echo "Removing WireGuard configuration..."
  uci delete network.wg0
  uci commit network
  uci delete firewall.@zone[1].network='wg0'
  uci commit firewall
  /etc/init.d/network restart
  echo "WireGuard configuration removed."
}

# Function to create or overwrite WireGuard settings based on the config file
configure_wireguard() {
  echo "Configuring WireGuard..."

  # Read values from the configuration file
  local address=$(grep "Address" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local private_key=$(grep "PrivateKey" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local mtu=$(grep "MTU" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local peer_public_key=$(grep "PublicKey" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local preshared_key=$(grep "PresharedKey" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local allowed_ips=$(grep "AllowedIPs" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local endpoint=$(grep "Endpoint" "$CONFIG_FILE" | cut -d ' ' -f 3)
  local keepalive=$(grep "PersistentKeepalive" "$CONFIG_FILE" | cut -d ' ' -f 3)

  # Configure WireGuard interface (wg0)
  uci set network.wg0=interface
  uci set network.wg0.proto='wireguard'
  uci set network.wg0.private_key="$private_key"
  uci set network.wg0.addresses="$address"
  uci set network.wg0.mtu="$mtu"

  # Add peer settings
  uci set network.wg0_peer=wireguard_wg0
  uci set network.wg0_peer.public_key="$peer_public_key"
  uci set network.wg0_peer.preshared_key="$preshared_key"
  uci set network.wg0_peer.allowed_ips="$allowed_ips"
  uci set network.wg0_peer.endpoint_host=$(echo $endpoint | cut -d ':' -f 1)
  uci set network.wg0_peer.endpoint_port=$(echo $endpoint | cut -d ':' -f 2)
  uci set network.wg0_peer.persistent_keepalive="$keepalive"

  # Add wg0 to the WAN zone in firewall
  uci add_list firewall.@zone[1].network='wg0'

  # Configure routes for allowed IPs
  local network_target=$(echo "$allowed_ips" | cut -d '/' -f 1)
  local netmask=$(ipcalc.sh "$allowed_ips" | grep NETMASK | cut -d '=' -f 2)

  uci set network.wg0route=route
  uci set network.wg0route.interface='wg0'
  uci set network.wg0route.target="$network_target"
  uci set network.wg0route.netmask="$netmask"

  # Commit changes and restart network
  uci commit network
  uci commit firewall
  /etc/init.d/network restart

  echo "WireGuard configuration and routing applied."
}

# Parse arguments
while getopts "c:r" opt; do
  case $opt in
    c) CONFIG_FILE="$OPTARG" ;;
    r) REMOVE_CONFIG=1 ;;
    *) echo "Invalid option"; exit 1 ;;
  esac
done

# If remove flag is set, remove WireGuard configuration
if [ "$REMOVE_CONFIG" -eq 1 ]; then
  remove_wireguard
  exit 0
fi

# If config file is provided, apply the WireGuard settings
if [ -n "$CONFIG_FILE" ]; then
  configure_wireguard
else
  echo "Usage: $0 -c <config_file> | -r"
  exit 1
fi
