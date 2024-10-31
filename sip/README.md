```
sudo docker build -t test_sip_server .
sudo docker run --name sip_server -p 5060:5060/udp -p 10000-10100:10000-10100/udp test_sip_server

```


```
sudo docker ps -a
sudo docker rm ID
sudo docker image list
sudo docker rmi ID
```
