### Amazon Linux 2023 base image

Use the plain AL2023 base image, published by `amazon` and named `al2023-ami-2023.*-kernel-6.1-x86_64` (or `-arm64`). The ECS-optimized and minimal variants also match the looser `al2023-ami-*` pattern and are not supported here.

The agent script and the systemd unit are downloaded from `AgentAmazonLinux2/`. Only the install steps differ on AL2023, so there is no copy of `NetworkAgentV2.py` or `NetworkAgent.service` in this directory.

### Amazon Linux 2023 user data

```
#!/bin/bash

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentAmazonLinux2023/Setup.sh
chmod +x ./Setup.sh
sudo bash ./Setup.sh
#

```

### Amazon Linux 2023 user data, base64

```
IyEvYmluL2Jhc2gKCmN1cmwgLUggIkFjY2VwdDogYXBwbGljYXRpb24vdm5kLmdpdGh1Yi52My5yYXciIC1PIC1MIGh0dHBzOi8vYXBpLmdpdGh1Yi5jb20vcmVwb3MvZHVwbG9jbG91ZC9saW51eGFnZW50L2NvbnRlbnRzL0FnZW50QW1hem9uTGludXgyMDIzL1NldHVwLnNoCmNobW9kICt4IC4vU2V0dXAuc2gKc3VkbyBiYXNoIC4vU2V0dXAuc2gKIwo=
```

### Amazon Linux 2023 manual

```
curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentAmazonLinux2023/Setup.sh
chmod +x ./Setup.sh
sudo bash ./Setup.sh

# now, reboot the system
sudo reboot

# after reboot
sudo systemctl daemon-reload
sudo systemctl status NetworkAgent
sudo systemctl stop NetworkAgent
sudo systemctl start NetworkAgent
sudo systemctl status NetworkAgent

tail -f /var/log/NetworkAgent.log

#vi /lib/systemd/system/NetworkAgent.service
#vi /usr/local/src/AgentV2/NetworkAgentV2.py
```
