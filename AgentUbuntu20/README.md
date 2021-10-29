

### ubuntu 20   
```

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentUbuntu20/Setup.sh
chmod +x ./Setup.sh
sudo bash ./Setup.sh

systemctl daemon-reload
service NetworkAgent status
service NetworkAgent stop
service NetworkAgent start
service NetworkAgent status

tail -f /var/log/NetworkAgent.log
 
#vi /lib/systemd/system/NetworkAgent.service  
#vi /usr/local/src/AgentV2/NetworkAgentV2.py
```

### centos 7 not tested py3   