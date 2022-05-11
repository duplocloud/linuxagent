### amazon linx2 user data
* ami used from amazon = ami-00f7e5c52c0f43726
```
#!/bin/bash

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentUbuntu22/Setup.sh
chmod +x ./Setup.sh
sudo bash ./Setup.sh
#

```
##  amazon linx2 user data  base64
``` 
IyEvYmluL2Jhc2gKCmN1cmwgLUggIkFjY2VwdDogYXBwbGljYXRpb24vdm5kLmdpdGh1Yi52My5yYXciIC1PIC1MIGh0dHBzOi8vYXBpLmdpdGh1Yi5jb20vcmVwb3MvZHVwbG9jbG91ZC9saW51eGFnZW50L2NvbnRlbnRzL0FnZW50VWJ1bnR1MjIvU2V0dXAuc2gKY2htb2QgK3ggLi9TZXR1cC5zaApzdWRvIGJhc2ggLi9TZXR1cC5zaAojCg==
```


### amazon linx2 manual
```

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentUbuntu22/Setup.sh
chmod +x ./Setup.sh
sudo bash ./Setup.sh
#


sudo systemctl daemon-reload
sudo service NetworkAgent status
sudo service NetworkAgent stop
sudo service NetworkAgent start
sudo service NetworkAgent status

tail -f /var/log/NetworkAgent.log
 
#vi /lib/systemd/system/NetworkAgent.service  
#vi /usr/local/src/AgentV2/NetworkAgentV2.py
```
### centos  not tested py3 -- need some work in py file