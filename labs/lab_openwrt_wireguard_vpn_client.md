### Configuring WireGuard VPN on OpenWrt Router for a Secure Connection to a WireGuard Server

This guide explains how to set up a WireGuard VPN client on an OpenWrt router, ensuring a secure connection to a remote WireGuard server.

---

## 1. Connect to the OpenWrt Router & Copy the VPN Profile

The first step is to transfer the WireGuard VPN profile to the router and initiate an SSH session to the OpenWrt system.

1. **Copy VPN Profile:**

   Use the following `scp` command to copy the VPN profile (`vpn_profile.conf`) to the router's `/tmp/` directory.

   ```bash
   OPENWRT_IP="172.16.1.102"
   
   scp -O vpn_profile.conf root@$OPENWRT_IP:/tmp/
   ```

2. **Connect to the Router:**

   Once the profile is copied, connect to the OpenWrt router using SSH.

   ```bash
   ssh root@$OPENWRT_IP
   ```

---

## 2. Prepare the OpenWrt System

Before configuring WireGuard, you need to ensure that the necessary packages are installed on the OpenWrt router.

1. **Update Package Lists and Install WireGuard Packages:**

   Run the following commands to update the system and install WireGuard tools, the WireGuard kernel module, and the Luci interface for WireGuard configuration.

   ```bash
   opkg update
   opkg install wireguard-tools kmod-wireguard luci-proto-wireguard
   ```

2. **Download the Configuration Script:**

   Download a helper script that automates the configuration of WireGuard on OpenWrt. The script is hosted on a public repository.

   ```bash
   cd /tmp/
   wget https://raw.githubusercontent.com/defencore/cyberlab/refs/heads/main/labs/scripts/openwrt_wireguard_client_config.sh
   chmod a+x openwrt_wireguard_client_config.sh
   ```

---

## 3. Run the Configuration Script

Once the script is downloaded and made executable, run it to configure WireGuard using the VPN profile.

1. **Run the Script:**

   Execute the script, providing the path to the VPN profile.

   ```bash
   ./openwrt_wireguard_client_config.sh -c vpn_profile.conf
   ```

---

## 4. Finalize the Configuration

After the WireGuard interface (`wg0`) is configured, apply additional settings to ensure optimal performance.

1. **Set MTU for WireGuard Interface:**

   To improve connection stability and avoid packet fragmentation, set the MTU for the WireGuard interface to 1280.

   ```bash
   uci set network.wg0.mtu='1280'
   ```

2. **Commit the Network Configuration:**

   Save the configuration and reload the network service to apply the changes.

   ```bash
   uci commit network
   /etc/init.d/network reload
   ```
## 5. Check connection
Run `wg show`
```
root@OpenWrt:/tmp# wg show
interface: wg0
  public key: +3XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXY=
  private key: (hidden)
  listening port: 43573

peer: QXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXBM=
  preshared key: (hidden)
  endpoint: XX.XXX.XXX.XX:51820
  allowed ips: 10.252.1.0/24
  latest handshake: 2 minutes, 30 seconds ago
  transfer: 24.63 KiB received, 17.37 KiB sent
  persistent keepalive: every 15 seconds
```

---
![image](https://github.com/user-attachments/assets/28c84bed-aa16-45d9-8cc4-9cb7b0cc8c94)

Your WireGuard VPN should now be configured and running on your OpenWrt router, ensuring secure communication with the remote server (Wireguard VPN Server).
