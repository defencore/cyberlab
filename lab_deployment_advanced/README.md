# Logical Scheme of Instances
![Logical Scheme](https://github.com/user-attachments/assets/31ce71ba-8675-457e-8b7f-4745c3d1367f)

# Deployment Instructions

## 1. Install Dependencies
First, ensure you have the necessary packages installed on your system:
```bash
sudo apt-get update
sudo apt-get install screen qemu-system-x86 bridge-utils screen
```

## 2. Download and Install VM Images
Run the following script to download and install the required OpenWrt and MikroTik VM images:
[qemu_openwrt_mikrotik_lab.sh](/lab_deployment_advanced/qemu_openwrt_mikrotik_lab.sh)

### 3. Deploy the System
To deploy the system, execute the script:
```bash
./qemu_openwrt_mikrotik_lab.sh
```

This script allows you to manage virtual machines (VMs) for OpenWrt and MikroTik environments. You can deploy, start, stop VMs, and configure network interfaces.

### Usage:
```bash
./qemu_openwrt_mikrotik_lab.sh [options]
```

#### Available Options:
- **-d**: Enable Debug mode (displays additional debug information)
- **-h**: Show help message

#### Menu Options:
- **0) Deploy System**: Download and prepare OpenWrt and MikroTik systems
- **1) Start VM by ID**: Start a specific VM (OpenWrt and MikroTik)
- **2) Stop VM by ID**: Stop a specific VM (OpenWrt and MikroTik)
- **3) Start All VMs**: Start all VMs in the defined range
- **4) Stop All VMs**: Stop all VMs in the defined range
- **5) Enable Internet**: Enable NAT and forwarding for network access
- **6) Disable Internet**: Disable NAT and forwarding
- **q) Quit**: Exit the script

### Examples:
- Show help:
  ```bash
  ./qemu_openwrt_mikrotik_lab.sh -h
  ```
- Enable Debug mode:
  ```bash
  ./qemu_openwrt_mikrotik_lab.sh -d
  ```
- Start the interactive menu:
  ```bash
  ./qemu_openwrt_mikrotik_lab.sh
  ```

## 4. Start VM Instances
From the script menu, choose option **3) Start All VMs** to start all virtual machines.

## 5. Enable Internet Access
From the script menu, select option **5) Enable Internet** to enable internet access for the VMs.

# Lab Configuration

## Network Configuration
![Lab Config](https://github.com/user-attachments/assets/e1c7221d-9bad-440b-aea2-8710523fe018)

### MikroTik Configuration

#### Static IP Configuration
```bash
/ip address add address=192.168.88.1/24 interface=ether1
/ip address add address=192.168.1.2/24 interface=ether2
/ip route add gateway=192.168.1.1
/ip dns set servers=8.8.8.8,8.8.4.4
/ip dns set allow-remote-requests=yes
```

#### Firewall and NAT Configuration
```bash
/ip firewall nat add chain=srcnat out-interface=ether2 action=masquerade
/ip firewall filter add chain=input in-interface=ether1 action=drop comment="Block all incoming traffic on ether1"
/ip firewall filter add chain=forward in-interface=ether1 action=accept connection-state=established,related comment="Allow related/established connections on ether1"
/ip firewall filter add chain=input in-interface=ether2 protocol=tcp dst-port=80 action=accept comment="Allow HTTP traffic on ether2"
/ip firewall filter add chain=input in-interface=ether2 protocol=tcp dst-port=8291 action=accept comment="Allow Winbox traffic on ether2"
/ip firewall nat add chain=dstnat in-interface=ether2 protocol=tcp dst-port=8080 action=dst-nat to-addresses=192.168.88.2 to-ports=80 comment="Port forwarding from ether2:8080 to ether1:80"
/ip firewall nat add chain=dstnat in-interface=ether2 protocol=tcp dst-port=2022 action=dst-nat to-addresses=192.168.88.2 to-ports=22 comment="Port forwarding from ether2:2022 to ether1:22"
```

### OpenWrt Configuration

#### Port Forwarding
```bash
# Forwarding from WAN:2022 to LAN:192.168.1.2:2022
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='2022'
uci set firewall.@redirect[-1].dest_port='2022'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Forwarding from WAN:8080 to LAN:192.168.1.2:8080
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='8080'
uci set firewall.@redirect[-1].dest_port='8080'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Forwarding from WAN:8081 to LAN:192.168.1.2:80
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='8081'
uci set firewall.@redirect[-1].dest_port='80'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Forwarding from WAN:8291 to LAN:192.168.1.2:8291
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='8291'
uci set firewall.@redirect[-1].dest_port='8291'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall
```

#### Secure SSH Access
```bash
# Only SSH-Keys authentication
echo "ssh-rsa AAAAB3Nza... PUBLIC_KEY" >> /etc/dropbear/authorized_keys
uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci commit dropbear
/etc/init.d/dropbear restart
```

#### Firewall Rule to Block Traffic to 172.16.1.0/24
```bash
uci add firewall rule
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].dest_ip='172.16.1.0/24'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].target='REJECT'
uci set firewall.@rule[-1].name='Block-LAN-to-WAN-172.16.1.0/24'
uci commit firewall
/etc/init.d/firewall restart
```

### Network Namespaces
```bash
sudo ip link set tap-9-2-lan down
sudo ip link set tap-9-2-lan netns ns9
sudo ip netns exec ns9 ip link set tap-9-2-lan up
sudo ip netns exec ns9 netdiscover
sudo ip netns exec ns9 ip addr add 192.168.88.2/24 dev tap-9-2-lan
sudo ip netns exec ns9 ip route add default via 192.168.88.1 dev tap-9-2-lan
sudo ip netns exec ns9 traceroute 8.8.8.8
```

To revert the configuration:
```bash
sudo ip netns exec ns9 ip link set tap-9-2-lan netns 1
# OR
sudo ip netns exec ns9 ip link del tap-9-2-lan
```

# Script Development

The main deployment and management script for the virtual lab environment is `qemu_openwrt_mikrotik_lab.sh`. This script provides an interactive menu to handle VM management and network setup.

![Script Development](https://github.com/user-attachments/assets/d8f2fcbd-2238-4c24-be98-79b5438d2dc1)
