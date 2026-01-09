![ZIVPN](zivpn.png)

UDP server installation for ZIVPN Tunnel (SSH/DNS/UDP) VPN app.
<br>

>Server binary for Linux amd64 and arm.

### install menu
```
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl && wget https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/setup.sh && chmod +x setup.sh && ./setup.sh
```


#### Installation AMD
```
wget -O zi.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/zi.sh; sudo chmod +x zi.sh; sudo ./zi.sh
```

#### Installation ARM
```
bash <(curl -fsSL https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/zi2.sh)
```


### Uninstall

```
sudo wget -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh; sudo chmod +x ziun.sh; sudo ./ziun.sh
```

### Uninstall menu

```
sudo wget -O ziun.sh https://raw.githubusercontent.com/Pujianto1219/ZiVPN/main/uninstall.sh; sudo chmod +x ziun.sh; sudo ./ziun.sh
```

Client App available:

<a href="https://play.google.com/store/apps/details?id=com.zi.zivpn" target="_blank" rel="noreferrer">Download APP on Playstore</a>
> ZIVPN
                
----
Bash script by PowerMX
