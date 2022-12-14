#!/bin/bash
# Install docker binaries: https://docs.docker.com/engine/install/binaries/
# Install containerd binaries: https://github.com/containerd/containerd/blob/main/docs/getting-started.md#option-1-from-the-official-binaries

set -e

# Docker release note: https://docs.docker.com/engine/release-notes/#201021
# Get stable version of Docker: https://download.docker.com/linux/static/stable
DOCKER_VERSION="20.10.21"
CONTAINERD_VERSION="1.6.9"
CRICTL_VERSION="1.25.0"
BUILDX_VERSION="0.9.1"

if [[ "$(uname -m)" == "aarch64" ]]; then
    DOCKER_ARCH="aarch64"
    CONTAINERD_ARCH="arm64"
    CRICTL_ARCH="arm64"
    BUILDX_ARCH="arm64"
elif [[ "$(uname -m)" == "x86_64" ]]; then
    DOCKER_ARCH="x86_64"
    CONTAINERD_ARCH="amd64"
    CRICTL_ARCH="amd64"
    BUILDX_ARCH="amd64"
else
    echo "Unrecognized arch $(uname -m)"
    exit 1
fi

echo "Install docker ${DOCKER_VERSION} and containerd ${CONTAINERD_VERSION} for openEuler..."
# Download containerd binaries
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${CONTAINERD_ARCH}.tar.gz -O containerd.tar.gz
# Download crictl binaries
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${CRICTL_ARCH}.tar.gz -O crictl.tar.gz
# Download docker binaries
wget https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz -O docker.tar.gz
# Download buildx binaries
sudo wget https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${BUILDX_ARCH} -O docker-buildx
sudo chmod +x ./docker-buildx
# Install containerd
echo "Extracting containerd binaries..."
sudo tar Czxvf /usr/local containerd.tar.gz
# Install crictl binary
sudo tar Czxvf /usr/local/bin crictl.tar.gz
# Install docker
echo "Extracting docker binaries..."
tar -zxf ./docker.tar.gz
sudo cp -p docker/* /usr/bin
# Install buildx
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo mv docker-buildx /usr/local/lib/docker/cli-plugins

# https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo bash -c 'cat > /etc/systemd/system/containerd.service <<EOF
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
#uncomment to enable the experimental sbservice (sandboxed) version of containerd/cri integration
#Environment="ENABLE_CRI_SANDBOXES=sandboxed"
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF'

# https://github.com/moby/moby/tree/master/contrib/init/systemd
sudo bash -c 'cat >/etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target docker.socket containerd.service
Wants=network.target containerd.service
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat >/etc/systemd/system/docker.socket <<EOF
[Unit]
Description=Docker Socket for the API

[Socket]
# If /var/run is not implemented as a symlink to /run, you may need to
# specify ListenStream=/var/run/docker.sock instead.
ListenStream=/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF'

# Add docker user group
sudo groupadd docker
sudo usermod -aG docker $USER

echo "Enabling and start docker services..."
sudo systemctl daemon-reload
sudo systemctl enable --now docker
echo "Run docker version:"
sudo docker version

echo "$0 Finished."
