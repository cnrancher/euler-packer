#!/bin/bash

set -e

VERSION="20.10.9"

if [[ "$(uname -m)" == "aarch64" ]]; then
    ARCH="aarch64"
elif [[ "$(uname -m)" == "x86_64" ]]; then
    ARCH="x86_64"
else
    echo "Unreconized arch $(uname -m)"
    exit 1
fi

echo "Install docker ${VERSION} for openEuler"

wget https://download.docker.com/linux/static/stable/${ARCH}/docker-${VERSION}.tgz -O docker.tar.gz
tar -zxvf ./docker.tar.gz
sudo cp -p docker/* /usr/bin

# /usr/lib/systemd/system/: Units provided by installed packages
# FYI: https://wiki.archlinux.org/title/Systemd#Writing_unit_files
sudo bash -c 'cat >/usr/lib/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target docker.socket
[Service]
Type=notify
WorkingDirectory=/usr/local/bin
ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock --selinux-enabled=false --log-opt max-size=1g
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable --now docker

sudo docker version

echo "$0 Finished."
