![image](https://github.com/user-attachments/assets/caaf13c0-8703-4a09-9a94-d2ae26c6f6fd)

# Mikrotik CSS326-24G-2S Honeypot

[Mikrotik CSS326-24G-2S - Honeypot](honeypot_CSS326-24G-2S%2B.py)

## Create multiple network interfaces 

```
sudo nano /usr/local/bin/setup-macvlans.sh
```

```
#!/bin/bash

LOGFILE="/var/log/setup-macvlans.log"

echo "Starting setup of macvlan interfaces..." > $LOGFILE

echo "Setting up macvlan0 in ns0..." >> $LOGFILE
sudo ip netns add ns0
sudo ip link add link eth0 macvlan0 type macvlan mode bridge
sudo ip link set dev macvlan0 address 02:42:ac:11:00:03
sudo ip link set macvlan0 netns ns0
sudo ip netns exec ns0 ip addr add 192.168.100.3/24 dev macvlan0
sudo ip netns exec ns0 ip link set macvlan0 up
sudo ip netns exec ns0 ip addr show >> $LOGFILE


echo "Setting up macvlan1 in ns1..." >> $LOGFILE
sudo ip netns add ns1
sudo ip link add link eth0 macvlan1 type macvlan mode bridge
sudo ip link set dev macvlan1 address 02:42:ac:11:00:04
sudo ip link set macvlan1 netns ns1
sudo ip netns exec ns1 ip addr add 192.168.100.4/24 dev macvlan1
sudo ip netns exec ns1 ip link set macvlan1 up
sudo ip netns exec ns1 ip addr show >> $LOGFILE

echo "Setting up macvlan2 in ns2..." >> $LOGFILE
sudo ip netns add ns2
sudo ip link add link eth0 macvlan2 type macvlan mode bridge
sudo ip link set dev macvlan2 address 02:42:ac:11:00:05
sudo ip link set macvlan2 netns ns2
sudo ip netns exec ns2 ip addr add 192.168.100.5/24 dev macvlan2
sudo ip netns exec ns2 ip link set macvlan2 up
sudo ip netns exec ns2 ip addr show >> $LOGFILE

echo "Setting up macvlan3 in ns3..." >> $LOGFILE
sudo ip netns add ns3
sudo ip link add link eth0 macvlan3 type macvlan mode bridge
sudo ip link set dev macvlan3 address 02:42:ac:11:00:06
sudo ip link set macvlan3 netns ns3
sudo ip netns exec ns3 ip addr add 192.168.100.6/24 dev macvlan3
sudo ip netns exec ns3 ip link set macvlan3 up
sudo ip netns exec ns3 ip addr show >> $LOGFILE

echo "Setup complete." >> $LOGFILE

```

```
sudo chmod +x /usr/local/bin/setup-macvlans.sh
```

```
sudo nano /etc/systemd/system/setup-macvlans.service
```

```
[Unit]
Description=Setup MACVLAN Interfaces on Boot
After=network.target

[Service]
ExecStart=/usr/local/bin/setup-macvlans.sh
Type=oneshot
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```
sudo systemctl enable setup-macvlans.service
sudo systemctl start setup-macvlans.service
sudo systemctl status setup-macvlans.service
cat /var/log/setup-macvlans.log
```

### Launching CSS326-24G-2S+ honeypot in namespace ns0

```
ip netns exec ns0 python3 honeypot_CSS326-24G-2S+.py
```

```
curl "http://192.168.100.3/index.html"
```
