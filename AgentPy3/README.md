

### ubuntu 20 py 3
```
curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentPy3/Setup.sh
chmod +x ./Setup.sh
sudo ./Setup.sh
 
```
### centos 7 == not tested  with py3
* Successfully created ami-00e03b2804b0c1cc7 from instance i-093f691e8d5d9b0ee.
* us-west2 =  ami-00e03b2804b0c1cc7 
```
curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentPy3/Setup.sh
chmod +x ./Setup.sh
sudo ./Setup.sh 

```