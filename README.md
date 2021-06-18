**Application**

[code-server](https://github.com/cdr/code-server)

**Description**

Code-server is a Visual Studio Code instance running on a remote server accessible through any web browser. It allows you to code anywhere and on any device such as a tablet or laptop with a consistent integrated development environment (IDE). Set up a secure a Linux development machine and get coding on any device with a web browser.

Take advantage of a cloud server by offloading the system demanding tasks such as tests, compilations, downloads to another machine. Preserve battery life when you’re on the go or spend your downtime doing something else while the computationally intensive processes are running on your cloud server.

**Build notes**

Latest GitHub master branch of code-server from Arch Linux AUR.

**Usage**
```
docker run -d \
    -p 8500:8500 \
    --name=<container name> \
    -v <path for data files>:/data \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e CERT_PATH=<filepath to cert> \
    -e CERT_KEY_PATH=<filepath to cert key> \
    -e SELF_SIGNED_CERT=yes|no \
    -e BIND_CLOUD_NAME=<name> \
    -e PASSWORD=<password for web ui> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-code-server
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access application**

`https://<host ip>:8500`

If no password specified via env var ```PASSWORD``` then a random password will be generated and shown in the log ```/config/supervisord.log```

**Example**
```
docker run -d \
    -p 8500:8500 \
    --name=code-server \
    -v ~/github/source:/data \
    -v ~/docker/code-server:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e CERT_PATH='/config/code-server/certs/mycert.crt' \
    -e CERT_KEY_PATH='/config/code-server/certs/mycert.key' \
    -e SELF_SIGNED_CERT=no \
    -e BIND_CLOUD_NAME='' \
    -e PASSWORD=code-server \
    -e UMASK=000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-code-server
```

**Notes**<br><br>
If both ```CERT_PATH``` and ```CERT_PATH_KEY``` specified then it takes precedence over values set for ```SELF_SIGNED_CERT``` and ```BIND_CLOUD_NAME```, else ```SELF_SIGNED_CERT``` takes precedence over ```BIND_CLOUD_NAME```

If you set ```BIND_CLOUD_NAME``` then check the log ```/config/supervisord.log``` for URL to authorise CBR with GitHub.

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](http://lime-technology.com/forum/index.php?topic=45837.0)