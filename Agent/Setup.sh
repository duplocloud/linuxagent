#!/bin/bash

#
# Agent variables 
#
AGENT='NetworkAgentV2'
INSTALL_DIR='/usr/local/src'
UDPTUNNEL='udptunnelv1'
AGENT_DIR='AgentV2'
DOWNLOAD_URL="https://api.github.com/repos/duplocloud/linuxagent/contents/Agent"

if [ -z "${DOWNLOAD_REF:-}" ]
then DOWNLOAD_REF=''
else DOWNLOAD_REF="?ref=${DOWNLOAD_REF}"
fi


#
# Step 1: Install Docker and setup docker bridge 
#
curl -sSL https://get.docker.com/ | sudo sh 

options=`cat /etc/default/docker | grep bridge`
echo $options 

if [ -z "$options" ]; then
   sudo sed -i 's#-H fd://#-H fd:// -H tcp://0.0.0.0:4243#' /lib/systemd/system/docker.service
fi

#if [ -z "$options" ]; then
#    sudo bash -c 'echo DOCKER_OPTS=\"-H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock -b=bridge0\" >> /etc/default/docker'
#fi

echo "==========================="
echo "     Docker installed      " 
echo "==========================="
echo `sudo docker info` 

echo "=================================="
echo "     Installing Network Agent     "
echo "=================================="
#
# Step 2: Check if Agent directory exists if not create the directory
#
if [ -z "$INSTALLDIR" ]; then
   DAEMON_DIR="$INSTALL_DIR/$AGENT_DIR"
   echo "Installing $AGENT in default location $DAEMON_DIR"
else
   DAEMON_DIR=$INSTALLDIR/$AGENT_DIR
   echo "Installing $AGENT in $DAEMON_DIR"
fi 

if [ -d $DAEMON_DIR ]; then 
   echo "$DAEMON_DIR directory exists"
else 
   echo "Creating $DAEMON_DIR"
   mkdir $DAEMON_DIR
fi 

DAEMON_NAME="NetworkAgentV2"
DAEMON="$DAEMON_DIR/NetworkAgentV2.py"
PYTHON_PATH="$DAEMON_DIR/flask/bin"
DAEMON_DEFAULT_FILE="/etc/default/$AGENT"

#
# Step 3: Check if Agent is running. Shutdown Agent before 
# installing 
# 
echo "Check if $AGENT is running"

if ps ax | grep -v grep | grep $AGENT > /dev/null
then
    pid=`pgrep -f "python $DAEMON"`
    echo "$AGENT is running $pid Shutting down $AGENT before installation..."
    sudo kill -9 $pid
else
    echo "$AGENT is not running"
fi

#
# Step 3: Check if UDP Tunnel Daemon is running. Shutdown Dameon before 
# installing 
# 
echo "Check if $UDPTUNNEL is running"

if ps ax | grep -v grep | grep $UDPTUNNEL > /dev/null
then
    pid=`pgrep $UDPTUNNEL`
    echo "$UDPTUNNEL is running $pid. Shutting down $UDPTUNNEL before installation..."
    kill -9 $pid
else
    echo "$UDPTUNNEL is not running"
fi


cd $DAEMON_DIR
rm -rf NetworkAgentV2.py
rm -rf NetworkSetupV2.py
rm -rf udptunnelv1.py
rm -rf flask


#
# Step 5: Fetch Agent code from the repository
#
curl -H "Accept: application/vnd.github.v3.raw" -o NetworkAgentV2.py -L "$DOWNLOAD_URL/AgentV2/NetworkAgentV2.py$DOWNLOAD_REF"

curl -H "Accept: application/vnd.github.v3.raw" -o NetworkSetupV2.py -L "$DOWNLOAD_URL/AgentV2/NetworkSetupV2.py$DOWNLOAD_REF"

curl -H "Accept: application/vnd.github.v3.raw" -o udptunnelv1.py -L "$DOWNLOAD_URL/AgentV2/udptunnelv1.py$DOWNLOAD_REF"

chmod a+x NetworkAgentV2.py
chmod a+x udptunnelv1.py

echo "Installing Container Management Service"
sudo apt-get  update
sudo apt-get -q -y install bridge-utils
sudo apt-get -q -y install python-dev 
sudo apt-get -q -y install python-pip
sudo apt-get -q -y install python-virtualenv

virtualenv flask
yes | flask/bin/pip install flask
yes | flask/bin/pip install requests
yes | flask/bin/pip install python-pytun 
yes | flask/bin/pip install --upgrade python-iptables
yes | flask/bin/pip install docker

echo "==========================="
echo "     Agent installed      " 
echo "==========================="
echo `ls -l $DAEMON_DIR`


if [ -f $DAEMON_DEFAULT_FILE ]; then 
   echo "Found $DAEMON_DEFAULT_FILE, removing and re-installing..." 
   sudo rm $DAEMON_DEFAULT_FILE 
   sudo touch $DAEMON_DEFAULT_FILE
fi 

echo "DAEMON=$DAEMON" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null 
echo "DAEMON_DIR=$DAEMON_DIR" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null
echo "PYTHON_PATH=$PYTHON_PATH" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null

getOSType () {
    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian  # XXX or Ubuntu??
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        # TODO add code for Red Hat and CentOS here
        ...
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

ubuntuInstall () {
   echo "Performing Ubuntu Install "
   cd /etc/init/
   echo $PWD
   sudo curl -H "Accept: application/vnd.github.v3.raw" -o udptunnel.conf -L "$DOWNLOAD_URL/udptunnel.conf$DOWNLOAD_REF"
   sudo curl -H "Accept: application/vnd.github.v3.raw" -o NetworkAgent.conf -L "$DOWNLOAD_URL/NetworkAgent.conf$DOWNLOAD_REF"
   sudo start NetworkAgent
}

ubuntu16PlusInstall () {
   echo "Performing Ubuntu 16.04 or later releaseInstall "
   cd /etc/systemd/system
   echo $PWD
   #sudo curl -H "Accept: application/vnd.github.v3.raw" -o udptunnel.service -L "$DOWNLOAD_URL/udptunnel.service$DOWNLOAD_REF"
   sudo curl -H "Accept: application/vnd.github.v3.raw" -o NetworkAgent.service -L "$DOWNLOAD_URL/NetworkAgent.service$DOWNLOAD_REF"
   sudo systemctl daemon-reload
   sudo systemctl enable NetworkAgent.service
   sudo systemctl start NetworkAgent.service
}

#
# Get the Linux OS Type 
#   Ubunutu: Use upstart script to start the daemon
#   Debian: Use init.d service to start the daemon
#   Fedora/Redhat: Use systemd
#
getOSType

#
# Step 6 Setup the Network Agent Daemon and launch
#

case $OS in
   "Ubuntu")
      case $VER in 
         14*)
             ubuntuInstall
             ;;
         16*)
             ubuntu16PlusInstall
             ;;
         17*)
             ubuntu16PlusInstall
             ;;
      esac 
      ;;
   *)
      echo "Unsupport OS: $OS, Version: $VER"
      ;;
esac


