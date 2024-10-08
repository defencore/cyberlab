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
   sudo ip netns exec ns_micronet ip link set tap-9-2-lan up
   ```
   - This brings up the `tap-9-2-lan` interface inside the `ns_mikronet` namespace.

## Step 4.
**Running Network Tools in the Namespace**:
   ```
   sudo ip netns exec ns_micronet netdiscover
   ```
   - This runs `netdiscover` inside the `ns_mikronet` namespace, which scans the local network for active hosts.

## Step 5.
**Assigning an IP Address and Route**:
   ```
   sudo ip netns exec ns_micronet ip addr add 192.168.88.2/24 dev tap-9-2-lan
   sudo ip netns exec ns_micronet ip route add default via 192.168.88.1 dev tap-9-2-lan
   ```
   - These commands assign the IP address `192.168.88.2/24` to the `tap-9-2-lan` interface in the `ns_mikronet` namespace and set the default gateway to `192.168.88.1` on the same interface.

## Step 6.
**Testing the Network**:
   ```
   sudo ip netns exec ns_micronet traceroute 8.8.8.8
   ```
   - This command uses `traceroute` inside the `ns_mikronet` namespace to check connectivity to Google's DNS server `8.8.8.8`.

## Step 7.
**Reverting the Configuration**:
   ```
   sudo ip netns exec ns_micronet ip link set tap-9-2-lan netns 1
   # OR
   sudo ip netns exec ns_micronet ip link del tap-9-2-lan
   ```
   - The first command moves the `tap-9-2-lan` interface back to the root namespace. The second alternative command deletes the `tap-9-2-lan` interface entirely.

