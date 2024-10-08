# SSH Tunnels

```
LOCAL_MACHINE=172.16.1.1
OPENWRT_WAN_IP=172.16.1.102
OPENWRT_LAN_IP=192.168.1.1
MIKROTIK_WAN_IP=192.168.1.2
MIKROTIK_LAN_IP=192.168.88.1
```

![image](https://github.com/user-attachments/assets/d3f04a61-47df-45e6-b6d3-21f0da5e9f82)


## Local Port Forwarding
### Local port forwarding: Forward traffic from localhost:8000 to Mikrotik's HTTP server (192.168.1.2:80) through OpenWrt (172.16.1.102)
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L localhost:8000:192.168.1.2:80 -N
```
### Alternative local port forwarding: Forward traffic from localhost (no restriction) to Mikrotik's HTTP server via OpenWrt
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:192.168.1.2:80 -N
```

Open http://127.0.0.1:8000 to access Mikrotik's HTTP server</br>
![image](https://github.com/user-attachments/assets/b354e6d1-0c39-494c-9a57-d450ea657b4a)

### Bind to all available interfaces on the local machine: Makes the service available from any network interface on 0.0.0.0:8000
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 0.0.0.0:8000:192.168.1.2:80 -N
```
### Bind to the specific IP address of the local machine: Forwarding from 172.16.1.1:8000 to Mikrotik via OpenWrt
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 172.16.1.1:8000:192.168.1.2:80 -N
```
Open http://172.16.1.1:8000 to access Mikrotik's HTTP server</br>
![image](https://github.com/user-attachments/assets/59d5eada-eae9-4231-b785-717427f903e9)

### Forward to localhost of the remote machine: Mikrotik is listening on localhost:80, forwarded to 8000 on the local machine
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:localhost:80 -N
```
### Forward from OpenWrt LAN IP to Mikrotik: Traffic from OpenWrt LAN IP forwarded to Mikrotik via OpenWrt
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:192.168.1.1:80 -N
```
### Forward from all interfaces on OpenWrt to Mikrotik: Makes the HTTP server available globally
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:0.0.0.0:80 -N
```
Open http://127.0.0.1:8000 to access Mikrotik's HTTP server</br>
![image](https://github.com/user-attachments/assets/315cf897-f2dd-42b3-b817-97a45941d5b5)

---
## Remote Port Forwarding
### Forward remote port 10000 on OpenWrt to an external server (145.24.145.107:80)
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -R 172.16.1.102:10000:145.24.145.107:80 -N
```
### Bind to all interfaces on OpenWrt: Forward traffic from OpenWrt to the external server
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -R 0.0.0.0:10000:145.24.145.107:80 -N
```
Open http://172.16.1.102:10000 to access the external server</br>
![image](https://github.com/user-attachments/assets/fe1e03fd-27ee-4ed0-a92a-6f571a22975a)
