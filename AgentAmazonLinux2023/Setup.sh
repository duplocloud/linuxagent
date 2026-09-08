#!/bin/bash
set -eu

AGENT='NetworkAgentV2'
DAEMON_DEFAULT_FILE="/etc/default/$AGENT"
DAEMON_DIR='/usr/local/src/AgentV2'
PYTHON_PATH="$DAEMON_DIR/flask/bin"
DAEMON="$DAEMON_DIR/NetworkAgentV2.py"
# Agent script and systemd unit are shared with Amazon Linux 2. Only the install steps differ on AL2023.
DOWNLOAD_URL="https://api.github.com/repos/duplocloud/linuxagent/contents/AgentAmazonLinux2"

DOCKER_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_OVERRIDE_FILE="$DOCKER_OVERRIDE_DIR/api.conf"

# GitHub redirects raw content to a signed CDN URL, so -L is required. These pin both hops to https.
CURL_HTTPS_OPTS=(--proto '=https' --proto-redir '=https' -fsSL)

if [[ -z "${DOWNLOAD_REF:-}" ]]; then
    DOWNLOAD_REF=''
else
    DOWNLOAD_REF="?ref=${DOWNLOAD_REF}"
fi

# AL2023 has no amazon-linux-extras. Docker comes from the default repo.
install_dependencies () {
    echo "AL2023: installing Docker and base packages"
    sudo dnf update -q -y
    sudo dnf install -q -y \
        docker \
        amazon-ecr-credential-helper \
        git wget net-tools vim \
        gcc \
        python3 python3-pip python3-devel \
        iptables-devel kernel-headers

    sudo usermod -a -G docker ec2-user
    mkdir -p ~/.docker
    echo '{ "credsStore": "ecr-login" }' > ~/.docker/config.json

    sudo mkdir -p "$DOCKER_OVERRIDE_DIR"
    sudo tee "$DOCKER_OVERRIDE_FILE" > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:4243 --containerd=/run/containerd/containerd.sock
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl restart docker
    sudo systemctl status docker --no-pager || true
    sudo docker info || true
}

# Strip the Amazon ECS container agent if present. The pinned AL2023 base does not ship it, and the ECS
# agent lacks the role to start anyhow. Insurance if source_ami_filter is ever loosened to a variant.
remove_ecs_agent () {
    echo "AL2023: removing any Amazon ECS agent leftovers"
    sudo systemctl disable --now ecs 2>/dev/null || true
    sudo systemctl mask ecs 2>/dev/null || true
    sudo dnf -q -y remove ecs-init || true
    sudo rm -rf /var/lib/ecs /etc/ecs /var/log/ecs
    for image in amazon/amazon-ecs-agent amazon/amazon-ecs-pause; do
        sudo docker image rm -f "$image:latest" 2>/dev/null || true
        sudo docker image rm -f "$image:0.1.0"  2>/dev/null || true
    done
    sudo docker rm -f ecs-agent 2>/dev/null || true
}

agent_install () {
    echo "AL2023: installing NetworkAgent in Python 3 venv"

    if [[ -f "$DAEMON_DEFAULT_FILE" ]]; then
        sudo rm $DAEMON_DEFAULT_FILE
        sudo touch $DAEMON_DEFAULT_FILE
    fi

    echo "DAEMON=$DAEMON"           | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null
    echo "DAEMON_DIR=$DAEMON_DIR"   | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null
    echo "PYTHON_PATH=$PYTHON_PATH" | sudo tee --append $DAEMON_DEFAULT_FILE > /dev/null
    cat $DAEMON_DEFAULT_FILE

    cd "$DAEMON_DIR"
    python3 -m venv flask
    flask/bin/pip install --upgrade pip
    # Install all agent dependencies in a single pip invocation so the
    # resolver picks a globally-consistent set. Sequential pip installs
    # silently downgrade urllib3 from 2.x to 1.26.x because botocore's
    # transitive constraint is only seen on the boto3 install call.
    flask/bin/pip --trusted-host pypi.python.org install \
        flask \
        requests \
        python-pytun \
        python-iptables \
        docker \
        boto3

    cd "$DAEMON_DIR"
    curl "${CURL_HTTPS_OPTS[@]}" \
        -H "Accept: application/vnd.github.v3.raw" \
        -o NetworkAgentV2.py "$DOWNLOAD_URL/NetworkAgentV2.py$DOWNLOAD_REF"
    chmod a+x NetworkAgentV2.py
    ls -alt "$DAEMON_DIR"

    cd /lib/systemd/system
    sudo curl "${CURL_HTTPS_OPTS[@]}" \
        -H "Accept: application/vnd.github.v3.raw" \
        -o NetworkAgent.service "$DOWNLOAD_URL/NetworkAgent.service$DOWNLOAD_REF"
    ls -alt NetworkAgent.service

    sudo systemctl daemon-reload
    sudo systemctl enable NetworkAgent.service
    # Do not start NetworkAgent.service here. Starting it during the
    # Packer bake disrupts iptables/networking and severs the SSM/SSH
    # session, which surfaces as `Bad exit status: -1`. The unit is
    # enabled and will start automatically on first boot.
}

get_os_type () {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

get_os_type
echo "Detected OS=$OS VER=$VER"
if [[ "$OS" != "amzn" ]] || [[ "$VER" != "2023" ]]; then
    echo "WARNING: this script targets Amazon Linux 2023; detected $OS $VER"
fi

echo "--------------------------OS=$OS VER=$VER--------------------------"
echo "Step 1: install Docker and base packages"
echo "--------------------------OS=$OS VER=$VER--------------------------"
install_dependencies

echo "==========================="
echo "     Docker installed      "
echo "==========================="

echo "--------------------------OS=$OS VER=$VER--------------------------"
echo "Step 1b: remove Amazon ECS agent if present"
echo "--------------------------OS=$OS VER=$VER--------------------------"
remove_ecs_agent

echo "--------------------------OS=$OS VER=$VER--------------------------"
echo "Step 2: ensure agent directory exists"
echo "--------------------------OS=$OS VER=$VER--------------------------"
sudo mkdir -p "$DAEMON_DIR"
sudo chown -R "${USER:-ec2-user}" "$DAEMON_DIR"
ls -alt "$DAEMON_DIR"

echo "--------------------------OS=$OS VER=$VER--------------------------"
echo "Step 3: stop any running $AGENT"
echo "--------------------------OS=$OS VER=$VER--------------------------"
if pgrep -f "$DAEMON" > /dev/null; then
    echo "$AGENT is running, killing"
    sudo pkill -9 -f "$DAEMON" || true
else
    echo "$AGENT is not running"
fi

echo "--------------------------OS=$OS VER=$VER--------------------------"
echo "Step 4: install NetworkAgent"
echo "--------------------------OS=$OS VER=$VER--------------------------"
cd "$DAEMON_DIR"
sudo rm -rf NetworkAgentV2.py flask
agent_install

echo "AL2023 setup complete"
exit 0
