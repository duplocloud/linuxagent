#!/bin/bash



getOSType () {
    if [ -f /etc/centos-release ]; then
          . /etc/os-release
          OS=$ID
          VER=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
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

getOSType
echo "OS=$OS VER=$VER"


#
# Agent variables
#
AGENT='NetworkAgentV2'
INSTALL_DIR='/usr/local/src'
UDPTUNNEL='udptunnelv1'
AGENT_DIR='AgentV2'


#
# Step 1: Install Docker and setup docker bridge
#
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------0"
echo "Step 1: Install Docker and setup docker bridge";
echo "--------------------------OS=$OS VER=$VER-------------------------------------1"
echo; echo;

if [ "$OS" = "centos" ]; then
  echo "Centos Installing docker"
  sudo yum  update
  sudo yum install -y git wget curl net-tools vim
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install docker-ce docker-ce-cli containerd.io

  sudo systemctl enable docker
  sudo systemctl start docker
  sudo systemctl status docker

  echo "Centos Installing Container Management Service"
  sudo yum   update
  sudo yum  -q -y install bridge-utils
  sudo yum  -q -y install python-dev
  sudo yum  -q -y install python-pip
  sudo yum  -q -y install python-virtualenv
  sudo yum  -q -y install gcc

elif  [ "$OS" = "Ubuntu" ]; then
  echo "Ubuntu Installing docker"
  curl -sSL https://get.docker.com/ | sudo sh
  echo "Ubuntu Installing Container Management Service"
  sudo apt-get  update
  sudo apt-get -q -y install bridge-utils
  sudo apt-get -q -y install python-dev
  sudo apt-get -q -y install python-pip
  sudo apt-get -q -y install python-virtualenv

else
    echo "Uknown OS=$OS VER=$VER "
fi

# Ensure directory exists
sudo mkdir -p "$DOCKER_OVERRIDE_DIR"
# Create or overwrite the override file
sudo tee "$DOCKER_OVERRIDE_FILE" > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:4243 --containerd=/run/containerd/containerd.sock
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker
sudo systemctl status docker
sudo docker ps
sudo docker info

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
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------1"
echo "Step 2: Check if Agent directory exists if not create the directory";
echo "--------------------------OS=$OS VER=$VER-------------------------------------2"
echo; echo;

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
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------2"
echo "Step 3: Check if Agent is running. Shutdown Agent before installing";
echo "--------------------------OS=$OS VER=$VER-------------------------------------3"
echo; echo;

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
# Step 4: Check if UDP Tunnel Daemon is running. Shutdown Dameon before
# installing
#
echo; echo;
echo "---------------------------------------------------------------3"
echo "Step 4: Check if UDP Tunnel Daemon is running. Shutdown Dameon before installing";
echo "---------------------------------------------------------------4"
echo; echo;

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
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------4"
echo "Step 5: Fetch Agent code from the repository"
echo "--------------------------OS=$OS VER=$VER-------------------------------------5";
echo; echo;

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/AgentV2/NetworkAgentV2.py

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/AgentV2/NetworkSetupV2.py

curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/AgentV2/udptunnelv1.py

chmod a+x NetworkAgentV2.py
chmod a+x udptunnelv1.py

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


centosInstall () {
   echo "Performing Centos Install "
   cd /lib/systemd/system
   echo $PWD
   curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/NetworkAgent.service
   sudo systemctl daemon-reload
   sudo systemctl enable NetworkAgent.service
   sudo systemctl start NetworkAgent.service
   sudo systemctl status NetworkAgent.service
}

ubuntuInstall () {
   echo "Performing Ubuntu Install "
   cd /etc/init/
   echo $PWD
   curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/udptunnel.conf
   curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/NetworkAgent.conf
   sudo start NetworkAgent
}

ubuntu16PlusInstall () {
   echo "Performing Ubuntu 16.04 or later releaseInstall "
   cd /etc/systemd/system
   echo $PWD
   #curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/udptunnel.service
   #curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/NetworkAgent.service
   curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/Agent/NetworkAgent.service
   #cp /home/merchantsameer2014/NetworkAgent.service /etc/systemd/system
   sudo systemctl daemon-reload
   sudo systemctl enable NetworkAgent.service
   sudo systemctl start NetworkAgent.service
   sudo systemctl status NetworkAgent.service
}

#
# Get the Linux OS Type
#   Ubunutu: Use upstart script to start the daemon
#   Debian: Use init.d service to start the daemon
#   Fedora/Redhat: Use systemd
#
#getOSType

#
# Step 6 Setup the Network Agent Daemon and launch
#
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------5"
echo "Step 6 Setup the Network Agent Daemon and launchy"
echo "--------------------------OS=$OS VER=$VER-------------------------------------6"
echo; echo;

echo "OS=$OS VER=$VER"

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
  "centos")
     case $VER in
         7*)
             centosInstall
             ;;
         8*)
             centosInstall
             ;;
      esac
         ;;
   *)
      echo "Unsupport OS: $OS, Version: $VER"
      ;;
esac

echo "--------------------------OS=$OS VER=$VER-------------------------------------6"
