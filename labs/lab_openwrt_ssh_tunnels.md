# SSH Tunnels

# Port Forwarding
## 
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L localhost:8000:192.168.1.2:80 -N
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:192.168.1.2:80 -N
```
[http://127.0.0.1:8000](http://127.0.0.1:8000)</br>
![image](https://github.com/user-attachments/assets/b354e6d1-0c39-494c-9a57-d450ea657b4a)

## 
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 0.0.0.0:8000:192.168.1.2:80 -N
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 172.16.1.1:8000:192.168.1.2:80 -N
```
[http://172.16.1.1:8000](http://172.16.1.1:8000)</br>
![image](https://github.com/user-attachments/assets/59d5eada-eae9-4231-b785-717427f903e9)



## 
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:localhost:80 -N
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:192.168.1.1:80 -N
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -L 8000:0.0.0.0:80 -N
```
[http://127.0.0.1:8000](http://127.0.0.1:8000)</br>
![image](https://github.com/user-attachments/assets/315cf897-f2dd-42b3-b817-97a45941d5b5)


# Remote Port Forwarding
```
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -R 172.16.1.102:10000:145.24.145.107:80 -N
ssh root@172.16.1.102 -i ~/.ssh/id_rsa -R 0.0.0.0:10000:145.24.145.107:80 -N
```
[http://172.16.1.102:10000](http://172.16.1.102:10000)</br>
![image](https://github.com/user-attachments/assets/fe1e03fd-27ee-4ed0-a92a-6f571a22975a)

