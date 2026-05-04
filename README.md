ASL3 Scripts by S21TIP

`sudo nano /etc/systemd/system/asterisk-reload-after-warp.service`
```
[Unit]
Description=Reload Asterisk after WARP VPN is up
After=warp-svc.service asterisk.service network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for i in {1..60}; do warp-cli status >/dev/null 2>&1 && break; sleep 2; done; for i in {1..30}; do warp-cli status | grep -q "Connected" && break; sleep 5; done; /usr/sbin/asterisk -rx "core restart now"'

[Install]
WantedBy=multi-user.target
```
`sudo systemctl daemon-reload`

`systemctl enable asterisk-reload-after-warp.service`
