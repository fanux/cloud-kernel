#!/bin/sh
command_exists() {
   command -v "$@" > /dev/null 2>&1
}
if ! command_exists docker; then
   set -x
   tar --strip-components=1 -xvzf ../docker/docker.tgz -C /usr/bin
   cp ../conf/docker.service /usr/lib/systemd/system/docker.service
   systemctl enable  docker.service
   systemctl restart docker.service

storage=${1:-/var/docker/lib}
harbor_ip=${2:-127.0.0.1}
mkdir -p $storage
cat > /etc/docker/daemon.json  << eof
{
  "registry-mirrors": [
     "http://373a6594.m.daocloud.io"
  ],
  "insecure-registries":
        ["$harbor_ip"],
  "graph":"${storage}"
}
eof
   systemctl restart docker.service
   docker version
fi
