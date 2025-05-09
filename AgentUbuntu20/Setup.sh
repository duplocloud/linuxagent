#!/bin/bash

#
# Agent variables
#
AGENT='NetworkAgentV2'
DAEMON_DEFAULT_FILE="/etc/default/$AGENT"
DAEMON_NAME="NetworkAgentV2"
DAEMON_DIR='/usr/local/src/AgentV2'
PYTHON_PATH="$DAEMON_DIR/flask/bin"
DAEMON="$DAEMON_DIR/NetworkAgentV2.py"
DOWNLOAD_URL="https://api.github.com/repos/duplocloud/linuxagent/contents/AgentUbuntu20"

DOCKER_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_OVERRIDE_FILE="$DOCKER_OVERRIDE_DIR/api.conf"

if [ -z "${DOWNLOAD_REF:-}" ]
then DOWNLOAD_REF=''
else DOWNLOAD_REF="?ref=${DOWNLOAD_REF}"
fi

if [ -d $DAEMON_DIR ]; then
   echo "$DAEMON_DIR directory exists"
fi

py3Install () {

   echo "Performing  Install "

  if [ -f $DAEMON_DEFAULT_FILE ]; then
     echo "Found $DAEMON_DEFAULT_FILE, removing and re-installing..."
     sudo rm $DAEMON_DEFAULT_FILE
     sudo touch $DAEMON_DEFAULT_FILE
  fi

  echo "DAEMON=$DAEMON" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null
  echo "DAEMON_DIR=$DAEMON_DIR" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null
  echo "PYTHON_PATH=$PYTHON_PATH" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null

  cat $DAEMON_DEFAULT_FILE
  #######

  # install os level also ??? as virtualenv has issues ... but having them on outside can corrupt
  # pip install flask requests  python-pytun docker
  # pip install --upgrade python-iptables

  # install virtualenv flask
  virtualenv flask
  yes | flask/bin/pip install flask
  yes | flask/bin/pip install requests
  yes | flask/bin/pip install python-pytun
  yes | flask/bin/pip install --upgrade python-iptables
  yes | flask/bin/pip install docker
  yes | flask/bin/pip install boto3
  yes | flask/bin/pip install google-auth

   #########
   cd $DAEMON_DIR
   curl -H "Accept: application/vnd.github.v3.raw" -o NetworkAgentV2.py -L "$DOWNLOAD_URL/NetworkAgentV2.py$DOWNLOAD_REF"
   chmod a+x NetworkAgentV2.py
   cat NetworkAgentV2.py

   #########
   cd /lib/systemd/system
   echo $PWD
   sudo curl -H "Accept: application/vnd.github.v3.raw" -o NetworkAgent.service -L "$DOWNLOAD_URL/NetworkAgent.service$DOWNLOAD_REF"
   ######
   ls -alt NetworkAgent.service
   ls -alt $DAEMON_DIR
   ######
   sudo systemctl daemon-reload
   sudo systemctl enable NetworkAgent.service
   sudo systemctl start NetworkAgent.service
   sudo systemctl status NetworkAgent.service &

}

centosInstall () {
   echo "Performing Centos Install "
   py3Install
}

ubuntuInstall () {
   echo "Performing Ubuntu Install "
   py3Install
   service docker restart
}


installDependencies () {

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
    sudo docker ps

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
    sudo apt install -q -y  python3-dev python3-pip bridge-utils  python3-virtualenv gcc
    sudo apt install -q -y amazon-ecr-credential-helper
    mkdir -p ~/.docker && echo '{ "credsStore": "ecr-login" }' > ~/.docker/config.json
    ###
  else
      echo "Unknown OS=$OS VER=$VER "
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

}


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


#
# Step 0: get os type
#


getOSType

#
# Step 1: Install Docker and setup docker bridge
#
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------0"
echo "Step 1: Install Docker and setup docker bridge";
echo "--------------------------OS=$OS VER=$VER-------------------------------------1"
echo; echo;

installDependencies



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

sudo mkdir -p $DAEMON_DIR
sudo chown -R "$USER" "$DAEMON_DIR"
echo "files in $DAEMON_DIR "
ls -alt $DAEMON_DIR

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

if ps ax | grep -v grep | grep "$AGENT" > /dev/null
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

echo "cd $DAEMON_DIR "

cd $DAEMON_DIR
rm -rf NetworkAgentV2.py
rm -rf flask
ls -alt $DAEMON_DIR

#
# Step 5 Setup the Network Agent Daemon and launch
#
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------5"
echo "Step 5 Setup the Network Agent Daemon and launchy"
echo "--------------------------OS=$OS VER=$VER-------------------------------------6"
echo; echo;

echo "OS=$OS VER=$VER"

case $OS in
   "Ubuntu")
        ubuntuInstall
        ;;
    "centos")
        centosInstall
         ;;
     *)
      echo "Unsupport OS: $OS, Version: $VER"
      ;;
esac

echo "--------------------------OS=$OS VER=$VER-------------------------------------6"
