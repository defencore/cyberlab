# Network Namespaces

## Step 1.
**Creating a Network Namespace**:
   ```
   sudo ip netns add ns_mikronet
   ```
   - This command creates a new network namespace called `ns_mikronet`. Network namespaces allow multiple network stacks to be isolated from each other.

## Step 2.
**Moving a Network Interface to the Namespace**:
   ```
   sudo ip link set tap-9-2-lan down
   sudo ip link set tap-9-2-lan netns ns_mikronet
   ```
   - These commands move the `tap-9-2-lan` network interface into the `ns_mikronet` namespace. The interface is brought down before the move, which is required, and can then be re-enabled in the namespace.

## Step 3.
**Bringing the Interface Up in the Namespace**:
   ```
   sudo ip netns exec ns_mikronet ip link set tap-9-2-lan up
   ```
   - This brings up the `tap-9-2-lan` interface inside the `ns_mikronet` namespace.

## Step 4.
**Running Network Tools in the Namespace**:
   ```
   sudo ip netns exec ns_mikronet netdiscover
   ```
   ```
 Currently scanning: 192.168.89.0/16   |   Screen View: Unique Hosts                                                
                                                                                                                    
 1 Captured ARP Req/Rep packets, from 1 hosts.   Total size: 42                                                     
 _____________________________________________________________________________
   IP            At MAC Address     Count     Len  MAC Vendor / Hostname      
 -----------------------------------------------------------------------------
 192.168.88.1    00:0c:42:XX:XX:XX      1      42  Routerboard.com  
   ```
   - This runs `netdiscover` inside the `ns_mikronet` namespace, which scans the local network for active hosts.

## Step 5.
**Assigning an IP Address and Route**:
   ```
   sudo ip netns exec ns_mikronet ip addr add 192.168.88.2/24 dev tap-9-2-lan
   sudo ip netns exec ns_mikronet ip route add default via 192.168.88.1 dev tap-9-2-lan
   ```
   - These commands assign the IP address `192.168.88.2/24` to the `tap-9-2-lan` interface in the `ns_mikronet` namespace and set the default gateway to `192.168.88.1` on the same interface.
   - Make sure that Masquerading is enabled on the MikroTik: `/ip firewall nat add chain=srcnat out-interface=ether2 action=masquerade`


## Step 6.
**Testing the Network**:
   ```
   sudo ip netns exec ns_mikronet traceroute 8.8.8.8
   ```
   - This command uses `traceroute` inside the `ns_mikronet` namespace to check connectivity to Google's DNS server `8.8.8.8`.
   - `sudo ip netns exec ns_mikronet traceroute 8.8.8.8`
      ```
      traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
       1  192.168.88.1 (192.168.88.1)  0.698 ms  0.676 ms  0.663 ms
       2  192.168.1.1 (192.168.1.1)  1.746 ms  1.738 ms  1.728 ms
       3  172.16.1.1 (172.16.1.1)  2.628 ms  2.626 ms  2.619 ms
      ...
      17  dns.google (8.8.8.8)  36.466 ms 142.251.228.27 (142.251.228.27)  33.709 ms 142.251.228.33 (142.251.228.33)  34.064 ms
      ```
   - `traceroute 8.8.8.8`
     ```
     traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
      1  192.168.0.1 (192.168.0.1)  3.520 ms  3.360 ms  3.299 ms
     ...
     14  dns.google (8.8.8.8)  39.008 ms 142.250.224.89 (142.250.224.89)  39.792 ms 209.85.250.175 (209.85.250.175)  30.685 ms
     ```
**Scanning the Network**:
   ```
   sudo ip netns exec ns_mikronet nmap 192.168.1.1 -d
   ```

   ```
   PORT    STATE SERVICE REASON
   22/tcp  open  ssh     syn-ack ttl 63
   53/tcp  open  domain  syn-ack ttl 63
   80/tcp  open  http    syn-ack ttl 63
   443/tcp open  https   syn-ack ttl 63
   ```

## Step 7.
**Reverting the Configuration**:
   ```
   sudo ip netns exec ns_mikronet ip link set tap-9-2-lan netns 1
   # OR
   sudo ip netns exec ns_mikronet ip link del tap-9-2-lan
   ```
   - The first command moves the `tap-9-2-lan` interface back to the root namespace. The second alternative command deletes the `tap-9-2-lan` interface entirely.

