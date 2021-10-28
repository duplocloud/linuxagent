#!/bin/bash



#
# Agent variables
#
AGENT='NetworkAgentV2'
DAEMON_DEFAULT_FILE="/etc/default/$AGENT"
#INSTALL_DIR='/usr/local/src'
#UDPTUNNEL='udptunnelv1'
#AGENT_DIR='AgentV2'
DAEMON_NAME="NetworkAgentV2"
DAEMON_DIR='/usr/local/src/AgentV2'
PYTHON_PATH="$DAEMON_DIR/flask/bin"
DAEMON="$DAEMON_DIR/NetworkAgentV2.py"

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
  pip install flask requests  python-pytun docker
  pip install --upgrade python-iptables

  # install virtualenv flask
  virtualenv flask
  yes | flask/bin/pip install flask
  yes | flask/bin/pip install requests
  yes | flask/bin/pip install python-pytun
  yes | flask/bin/pip install --upgrade python-iptables
  yes | flask/bin/pip install docker

   #########
   cd $DAEMON_DIR
   curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentPy3/NetworkAgentV2.py
   chmod a+x NetworkAgentV2.py
   cat NetworkAgentV2.py

   #########
   cd /lib/systemd/system
   echo $PWD
   curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/AgentPy3/NetworkAgent.service
   ######
   ls -alt NetworkAgent.service
   ls -alt $DAEMON_DIR
   ######
   sudo systemctl daemon-reload
   sudo systemctl enable NetworkAgent.service
   sudo systemctl start NetworkAgent.service
   #sudo systemctl status NetworkAgent.service

}

centosInstall () {
   echo "Performing Centos Install "
   py3Install
}

ubuntuInstall () {
   echo "Performing Ubuntu Install "
   py3Install
}


installDependancies () {

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
    ###
    options=`cat /etc/default/docker | grep bridge`
    echo $options
    if [ -z "$options" ]; then
       sudo sed -i 's#-H fd://#-H fd:// -H tcp://0.0.0.0:4243#' /lib/systemd/system/docker.service
    fi
  else
      echo "Unknown OS=$OS VER=$VER "
  fi


}


getOSType () {
  #
  # Get the Linux OS Type
  #   Ubunutu: Use upstart script to start the daemon
  #   Debian: Use init.d service to start the daemon
  #   Fedora/Redhat: Use systemd
  #
  #getOSType

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

getfile() {
  curl -H "Accept: application/vnd.github.v3.raw" -O -L https://api.github.com/repos/duplocloud/linuxagent/contents/$1
  # cp /home/ubuntu/$1 .
  echo "cp /home/ubuntu/$1 "

}



#
# Step 0: get os type
#

# scp -i pravin.key -r   Agent ubuntu@10.240.3.216:/home/ubuntu/
# ssh -i pravin.key ubuntu@10.240.3.216
#pip install flask requests   python-pytun docker python-iptables
# See "systemctl status NetworkAgent.service" and "journalctl -xe" for details.
# /bin/bash -c 'PYTHONPATH=/usr/local/src/AgentV2/flask/bin; PATH=$$PYTHONPATH:$$PATH; /usr/local/src/AgentV2/flask/bin/python /usr/local/src/AgentV2/NetworkAgentV2.py'

getOSType

#
# Step 1: Install Docker and setup docker bridge
#
echo; echo;
echo "--------------------------OS=$OS VER=$VER-------------------------------------0"
echo "Step 1: Install Docker and setup docker bridge";
echo "--------------------------OS=$OS VER=$VER-------------------------------------1"
echo; echo;

installDependancies


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

mkdir -p $DAEMON_DIR
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
