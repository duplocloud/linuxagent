## Steps to create DUPLO AMI for ubuntu 22.04  or 20.04 OS.

### Choose base AMI-ID (and base OS).
* Create AMI-ID with preferred OS.
* E.g. You may get an AMI-ID from AWS console.  Or Use an image baked in-house.
![Select AMI form Amazon Console](images/select_ami_in_aws_console_1.png)



###  Create VM with Duplo Agent installed. 
* Use below 'base64 user data'. This will install Duplo native agent.

![reate host with userdata base64](images/create_host_with_base64_2.png)

* Base64 user data.
``` 
IyEvYmluL2Jhc2gKCmN1cmwgLUggIkFjY2VwdDogYXBwbGljYXRpb24vdm5kLmdpdGh1Yi52My5yYXciIC1PIC0tb3V0cHV0LWRpciAvaG9tZS91YnVudHUvIC1MICBodHRwczovL2FwaS5naXRodWIuY29tL3JlcG9zL2R1cGxvY2xvdWQvbGludXhhZ2VudC9jb250ZW50cy9BZ2VudFVidW50dTIyL1NldHVwLnNoCmNobW9kICt4IC9ob21lL3VidW50dS8vU2V0dXAuc2gKc3VkbyBiYXNoIC9ob21lL3VidW50dS8vU2V0dXAuc2gKIw==
```

* Or if you already have a script, you may include following script into your 'base64 user data'. 
* Or alternately run the following script manually on the VM.

```
#!/bin/bash

curl -H "Accept: application/vnd.github.v3.raw" -O --output-dir /tmp/ -L  https://api.github.com/repos/duplocloud/linuxagent/contents/AgentUbuntu22/Setup.sh
chmod +x /tmp/Setup.sh
sudo bash /tmp/Setup.sh
#
```


###  Create an AMI for the new VM.
* Create an AMI using either AWS console or duplo-ui.
![create AMI](images/create_ami_3.png)

###  Add AMI/image entry into Plan images.
* Create new plan/image entry. The AMI will be available to select during hosts creation.
![Add image entry into Plan](images/create_plan_image_4.png)

###  Choose AMI during host creation
* The image congigured in plan will be available to all the related tenants.
![Choose AMI during host creation ](images/host_creation_to_Choose_AMI.png)
