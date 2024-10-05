# Logical scheme of instances
![image](https://github.com/user-attachments/assets/31ce71ba-8675-457e-8b7f-4745c3d1367f)

# Deployment
## Install dependencies:
```
└─$ sudo apt-get update
└─$ sudo apt-get install screen qemu-system-x86 bridge-utils screen
```

## Download & Install VM Images
```
./qemu_openwrt_mikrotik_lab.sh
```
```
Menu:
0) Deploy System
1) Start VM by ID
2) Stop VM by ID
3) Start All VMs
4) Stop All VMs
5) Enable Internet
6) Disable Internet
q) Quit
Enter your choice:
```


## Lab Config
![image](https://github.com/user-attachments/assets/e1c7221d-9bad-440b-aea2-8710523fe018)

### MikroTik Config
```
[admin@MikroTik] > 
# Static IP Config on ether1
/ip address add address=192.168.88.1/24 interface=ether1

# Static IP Config on ether2
/ip address add address=192.168.1.2/24 interface=ether2
/ip route add gateway=192.168.1.1
/ip dns set servers=8.8.8.8,8.8.4.4
/ip dns set allow-remote-requests=yes

# Firewall NAT
/ip firewall nat add chain=srcnat out-interface=ether2 action=masquerade
# 
```
```
[admin@MikroTik] > 
/ip firewall filter add chain=input in-interface=ether1 action=drop comment="Block all incoming traffic on ether1"
/ip firewall filter add chain=forward in-interface=ether1 action=accept connection-state=established,related comment="Allow related/established connections on ether1"
/ip firewall filter add chain=input in-interface=ether2 protocol=tcp dst-port=80 action=accept comment="Allow HTTP traffic on ether2"
/ip firewall filter add chain=input in-interface=ether2 protocol=tcp dst-port=8291 action=accept comment="Allow Winbox traffic on ether2"
/ip firewall nat add chain=dstnat in-interface=ether2 protocol=tcp dst-port=8080 action=dst-nat to-addresses=192.168.88.2 to-ports=80 comment="Port forwarding from ether2:8080 to ether1:80"
/ip firewall nat add chain=dstnat in-interface=ether2 protocol=tcp dst-port=2022 action=dst-nat to-addresses=192.168.88.2 to-ports=22 comment="Port forwarding from ether2:2022 to ether1:22"
```

### OpenWrt Config
```
# Port Forwarding from WAN:2022 to LAN:192.168.1.2:2022
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='2022'
uci set firewall.@redirect[-1].dest_port='2022'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Port Forwarding from WAN:8080 to LAN:192.168.1.2:8080
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='8080'
uci set firewall.@redirect[-1].dest_port='8080'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Port Forwarding from WAN:8081 to LAN:192.168.1.2:80
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='8081'
uci set firewall.@redirect[-1].dest_port='80'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Port Forwarding from WAN:8291 to LAN:192.168.1.2:8291
uci add firewall redirect
uci set firewall.@redirect[-1].target='DNAT'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.2'
uci set firewall.@redirect[-1].src_dport='8291'
uci set firewall.@redirect[-1].dest_port='8291'
uci set firewall.@redirect[-1].proto='tcp'
uci commit firewall

# Allow SSH from WAN
uci add firewall rule
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].name='Allow-SSH-WAN'
uci commit firewall

# Block traffic to 172.16.1.0/24
uci add firewall rule
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].dest_ip='172.16.1.0/24'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].target='REJECT'
uci set firewall.@rule[-1].name='Block-LAN-to-WAN-172.16.1.0/24'
uci commit firewall

# Apply changes
/etc/init.d/firewall restart

# Only SSH-Keys
echo "ssh-rsa AAAAB3Nza... PUBLIC_KEY" >> /etc/dropbear/authorized_keys
uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'
uci commit dropbear
/etc/init.d/dropbear restart
```


### Namespaces
```
sudo ip link set tap-9-2-lan down
sudo ip link set tap-9-2-lan netns ns9
sudo ip netns exec ns9 ip link set tap-9-2-lan up
sudo ip netns exec ns9 netdiscover
sudo ip netns exec ns9 ip addr add 192.168.88.2/24 dev tap-9-2-lan
sudo ip netns exec ns9 ip route add default via 192.168.88.1 dev tap-9-2-lan
sudo ip netns exec ns9 traceroute 8.8.8.8

sudo ip netns exec ns9 ip link set tap-9-2-lan netns 1
# OR
sudo ip netns exec ns9 ip link del tap-9-2-lan

```
# Script Developent
## qemu_openwrt_mikrotik_lab.sh
![image](https://github.com/user-attachments/assets/d8f2fcbd-2238-4c24-be98-79b5438d2dc1)

