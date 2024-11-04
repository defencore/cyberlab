## Demo SIP Server Deploy
```
sudo apt-get update
sudo apt-get install docker
```

```
sudo docker build -t test_sip_server .
sudo docker run --rm --name sip_server -p 5060:5060/udp -p 10000-10100:10000-10100/udp -v $(pwd)/config:/etc/asterisk test_sip_server
```


```
find ./config/ -type f -exec sh -c 'echo "{}"; cat "{}"' \;
sudo docker ps -a
sudo docker rm ID
sudo docker image list
sudo docker rmi ID
```
