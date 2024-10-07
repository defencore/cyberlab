```
WIREGUARD_SERVER="vpn.defencore.com"
SSH_USER="your_user"
SSH_KEY="/path/to/ssh/private_key/id_rsa"
```

```
ssh $SSH_USER@$WIREGUARD_SERVER -i $SSH_KEY
```

HowTo: https://github.com/ngoduykhanh/wireguard-ui

### RUN ON WIREGUARD_SERVER
```
# Local server execution
sudo su
apt-get update
apt-get upgrade -y
apt-get install wireguard wireguard-tools -y
apt-get install net-tools
```

Download wireguard-ui-v0.6.2 & unpack
```
cd /tmp && wget https://github.com/ngoduykhanh/wireguard-ui/releases/download/v0.6.2/wireguard-ui-v0.6.2-linux-amd64.tar.gz
cd /tmp && tar -xvf wireguard-ui-v0.6.2-linux-amd64.tar.gz
mkdir -m 077 /opt/wgui
mv /tmp/wireguard-ui /opt/wgui/wireguard-ui
ln -s /opt/wgui/wireguard-ui /usr/local/bin/wireguard-ui
```

Enable IP forwarding
```
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
```

Create Wireguard config
```
touch /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0.service
```

Create `/etc/systemd/system/wgui.service`
```
cd /etc/systemd/system/
cat << EOF > wgui.service
[Unit]
Description=Restart WireGuard
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart wg-quick@wg0.service

[Install]
RequiredBy=wgui.path
EOF
```

Create `/etc/systemd/system/wgui.path`
```
cd /etc/systemd/system/
cat << EOF > wgui.path
[Unit]
Description=Watch /etc/wireguard/wg0.conf for changes

[Path]
PathModified=/etc/wireguard/wg0.conf

[Install]
WantedBy=multi-user.target
EOF
```

Apply it
```
systemctl enable wgui.{path,service}
systemctl start wgui.{path,service}
```


Add firewall rules
```
# Install additional tools for iptables persistence and network tools
sudo apt-get install iptables-persistent -y

# Block external access on port 5000
sudo iptables -A INPUT -i eth0 -p tcp --dport 5000 -j DROP

sudo iptables-save
```

### Connect to Wireguad-GUI

#### Forward port
```
ssh $SSH_USER@$WIREGUARD_SERVER -i $SSH_KEY -L 5000:0.0.0.0:5000
# run wireguard-ui
wireguard-ui -disable-login
```
#### Open in browser

[http://127.0.0.1:5000](http://127.0.0.1:5000)

![image](https://github.com/user-attachments/assets/04c67fd1-b0cf-41f5-8c62-90b5e7462d11)

---

![image](https://github.com/user-attachments/assets/0a405b23-6027-4681-bb92-cbf2584e6f58)

Listen Port
```
51820
```

Post Up Script
```
iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

Pre Down Script
```
iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

Post Down Script
```
iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eths0 -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

---
Add Wireguard Clients
![image](https://github.com/user-attachments/assets/784f344c-02b5-4d30-90cc-b85bd9e5c17f)

