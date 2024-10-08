# 1. Configuration of Virtual Routers and VPN Connectivity

![image](https://github.com/user-attachments/assets/9f06ce02-0d8a-4176-ac83-c89dff46301c)
scheme

---
## 1.1. Deployment of a virtual environment

### 1.1.1. Step
Prepare system
```
sudo apt-get update
sudo apt-get install qemu-system-x86 qemu-utils screen iproute2 bridge-utils wget gunzip iptables dnsmasq
```

### 1.1.2. Step
Download script
```
mkdir ~/lab
cd ~/lab
wget https://raw.githubusercontent.com/defencore/cyberlab/refs/heads/main/labs/scripts/openwrt_mikrotik_vm.sh
chmod a+x openwrt_mikrotik_vm.sh
```

---
## 1.2. Deploy System

### 1.2.1. Step
Run Script `openwrt_mikrotik_vm.sh`
```
./openwrt_mikrotik_vm.sh
```
### 1.2.2. Step
Select: `0) Deploy System`

- the script will automatically download and create an openwrt virtual machine image
- then the script will download the ISO image of the MikroTik routerOS and start its installation on the virtual disk

### 1.2.3. Step
Use the arrow keys (`left`, `right`, `up`, `down`)  and `space` to select the following packages:
- `system`
- `dhcp`
- `security`
- `user-manager`

![image](https://github.com/user-attachments/assets/847ca8e5-c964-4858-9244-eb19ac01c592)

### 1.2.4. Step
- press [i] to install

![image](https://github.com/user-attachments/assets/1cb4f6f4-f680-4122-ac56-485d1bd6a448)

### 1.2.5. Step
- When prompted, select `n` for `NO` to the question: `Do you want to keep the old configuration? [y/n]:`

### 1.2.6. Step
- Confirm the warning: `Warning: all data on the disk will be erased! Continue? [y/n]:` by pressing `y` for `YES`.


![image](https://github.com/user-attachments/assets/8c89887b-815f-4c2a-bd7d-38ebf14ac99a)

### 1.2.7. Step
- Press `Enter` to reboot the virtual machine when prompted.

### 1.2.8. Step
- Close the QEMU VM after reboot.
- If the virtual machine has captured your mouse and keyboard, press: `CTRL+ALT+G` to release them, then close the VM window.

At this point, you have created virtual router images that you can now run and configure

---
## 1.3. Start VMs

### 1.3.1. Step
Run script with -w flag for enabling Write Mode
```
./openwrt_mikrotik_vm.sh -w
```
### 1.3.2. Step
Start the VM by selecting option `1`
- `1) Start VM by ID`
  - Select ID: `9`

### 1.3.3. Step
Enable Internet for the VM by selecting option `5`.
- `5) Enable Internet`

## 1.4. Setting up OpenWrt Router
### 1.4.1. Step
Connect to OpenWrt Screen Session
- `8) List and Connect to Screen Sessions`
  - select `vm-9-1-openwrt` session

- To disconnect from the session, press sequentially: `CTRA + A` > `D`

![image](https://github.com/user-attachments/assets/46377963-c55f-4b5a-8fc1-850a42959fa6)

### 1.4.2. Step
Check Internet connection on OpenWrt
```
root@OpenWrt:/# ping 8.8.8.8 -c 2
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: seq=0 ttl=112 time=47.479 ms
64 bytes from 8.8.8.8: seq=1 ttl=112 time=167.644 m
```

### 1.4.3. Step
Change password to router
<br/>use strong passwords!
```
passwd
```

### 1.4.4. Step
Install packages
```
opkg update
opkg install nano curl
```

### 1.4.5. Step
Configure SSH
```
nano /etc/dropbear/authorized_keys
```
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDChSshTAZYqYaZUj031jssMaiUWN/ffo3RI7ubkiY73pzP7D2BypY7JceQDOH1m+0WnaLqRH7njKeYj+zX1Zc3FU0vi93Lz2VUUxnMjj7Na809SA5MSnwRr5+8hX2gn91Nc5IV3M0nuY1rOrk/chyI/JX2CKngVhZzhDK+r83XKlovOY0Juj2MjbZfYEFXXgS22TrOKRGYzTSQxju1YgHu4+BSqxhGiawujf7BVkOV05ndG2X6BDBftcTT8bgxOswsjQtVjEqDDsWlHr3EM3Lu0u3tffpnd0MDRCgU40Eyjd5Gvi4h4gky70/ZhVOilqgBzWXXXMW0Qvs5memWWw9KUYHlXfPjGAL9vETfIEs8XKQCfvRAVCg+R1qvVZLH9O7Gdd8wn6x2MfojKL1ZOCxIkYTxXqk7qJ2D3YFfrTdPU/jM2UPEU/Yes1EfkJNBOVd1Q3FQqhEOdEceBeit1xl4hGEg6SbqmEBIn6+hKEM6mZAfQtCjTq6fSPIIAEmkyPUiWpMub7fBLlXv7LU6U2CID97mYED4Fng0x9SCgWleNKaSTzBir8BIa1gK0FwLP8auFvkGdKkkbIalMRFcWNKOKVRpEfhwm1SuUdIONyDyIx38xcug03Ts1jnS5cgsMmsHCG7OZLYsT97lm0gHXECANhD0AnLFjGWTmClX5yVtSw== remote@defencore.com
ssh-rsa AAAAB3NzxxxxxYOURPUBLICKEYxxxxxxxxxX5yVtSw== yourlogin@mail
```
- Save changes: `CTRL+O`
- Exit: `CTRL+X`


### 1.4.6. Step
Enable GatewayPorts
```
uci set dropbear.@dropbear[0].GatewayPorts='1'
uci commit dropbear
/etc/init.d/dropbear restart
```


### 1.4.7. Step
Configure Port Forwarding
```
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

/etc/init.d/firewall restart
```

### 1.4.6. Step
Configure Firewall
```
# Add a firewall rule to allow SSH (port 22) from the WAN zone
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SSH-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# Allow HTTP access (port 80) from WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# Allow HTTPS access (port 443) from WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTPS-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# Save the firewall changes and restart the firewall
uci commit firewall
/etc/init.d/firewall restart
```
### 1.4.7. Step
Find your OpenWrt router's IP address.
```
ip addr show eth1
```

### 1.4.8. Step
Open your OpenWrt router IP in WEB-browser and use your password from **1.4.3. Step**
<br/>Example: [172.16.1.102](http://172.16.1.102:80)
![image](https://github.com/user-attachments/assets/0d110353-4b18-4521-8821-5a4ddf59d508)


## 1.5. Setting up MikroTik Router
### 1.5.1. Step
Connect to MikroTik Screen Session
- Disconnect from OpenWrt session by pressing sequentially: `CTRA + A` > `D`
- `8) List and Connect to Screen Sessions`
  - select `vm-9-2-mikrotik` session

### 1.5.2. Step
Login to Mikrotik
- Login: `admin`
- Password: `empty` (leave empty)

![image](https://github.com/user-attachments/assets/df6ed927-88fd-47b4-be19-87598af228c7)

After pressing `Enter`, you will see the following line:
```
[admin@MikroTik] > 
```

### 1.5.3. Step
Configure Static IP, Route and DNS
```
/ip address add address=192.168.88.1/24 interface=ether1
/ip address add address=192.168.1.2/24 interface=ether2
/ip route add gateway=192.168.1.1
/ip dns set servers=8.8.8.8,8.8.4.4
/ip dns set allow-remote-requests=yes
```

### 1.5.4. Step
Check connection between OpenWrt & MikroTik routers
```
ping 192.168.1.1 count=2
```
![image](https://github.com/user-attachments/assets/e4ec3c4c-fe10-4034-93ff-12f46470984f)

Check Internet connection
```
ping 8.8.8.8 count=2
```
  
### 1.5.5. Step
Disable the default admin user for security, and create a new admin user.
```
/user add name=new_admin password=strong_password group=full
/user disable admin
```

### 1.5.6. Step
Open your OpenWrt router IP in WEB-browser with 8081 port and use your creds from **1.5.5. Step**
<br/>Example: [http://172.16.1.102:8081](http://172.16.1.102:8081)
![image](https://github.com/user-attachments/assets/9f7d2507-890e-4f7e-9408-cfffa5322ccc)

---
## At this stage, the basic configuration of the routers is complete

**Now you can go to:**
- VPN Configuring
- SSH tunneling
