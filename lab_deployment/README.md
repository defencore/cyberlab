
### qemu_openwrt_lab.sh
[qemu_openwrt_lab.sh](qemu_openwrt_lab.sh)

This script automates the creation and management of OpenWRT virtual machines (VMs) using QEMU. 
It sets up VLANs for WAN and LAN traffic, configures network bridges, and handles NAT and DHCP for WAN connectivity.
The script also allows starting, stopping, and managing individual or multiple VMs with VLAN isolation for network traffic.

### Example of infrastructure created using a script:
![image](https://github.com/user-attachments/assets/2cad09f4-ee14-495e-98ab-178e8009058d)

**Install dependencies**
```
sudo apt update
sudo apt install -y qemu-system-x86 screen ip bridge-utils wget gunzip iptables dnsmasq
```

**Run scripts**
```
./qemu_openwrt_lab.sh start
sudo screen -r openwrt_vm_1
sudo screen -r openwrt_vm_16
./qemu_openwrt_lab.sh stop
```
