#!/bin/bash

## 创建新加坡2核4g的鲲鹏服务器. 初始镜像为 centos7.6
mycli hw create -c 1 --eip >  InstanceId.json

cat InstanceId.json

ID=$(jq -r '.serverIds[0]' < InstanceId.json)

mycli hw list --id $ID > info.json

## 华为删除ecs不连带删除eip.
mycli hw list ip > ip.json
FIPID=$(jq -r ".[0].id" < ip.json)

IP=$(jq -r '.addresses."a55545d8-a4cb-436d-a8ec-45c66aff725c"[0].addr' < info.json)
FIP=$(jq -r '.addresses."a55545d8-a4cb-436d-a8ec-45c66aff725c"[1].addr' < info.json)

cat info.json && echo $ID && echo $FIP && echo $IP

echo "wait for sshd start"
sleep 100 # wait for sshd

alias remotecmd="sshcmd --pk ./release.pem --host $FIP --cmd"

echo "install git"
remotecmd 'yum install -y git conntrack'

echo "clone cloud kernel"
remotecmd 'git clone https://github.com/fanux/cloud-kernel'

echo "install kubernetes bin"
remotecmd "wget https://dl.k8s.io/v$1/kubernetes-server-linux-arm64.tar.gz && \
           wget https://download.docker.com/linux/static/stable/aarch64/docker-19.03.12.tgz && \
           cp  docker-19.03.12.tgz kube/docker/docker.tgz && \
           tar zxvf kubernetes-server-linux-arm64.tar.gz && \
           cd kube && \
           cp ../kubernetes/server/bin/kubectl bin/ && \
           cp ../kubernetes/server/bin/kubelet bin/ && \
           cp ../kubernetes/server/bin/kubeadm bin/ && \
           sed s/k8s_version/$1/g -i conf/kubeadm.yaml && \
           cd shell && sh init.sh && \
           rm -rf /etc/docker/daemon.json && systemctl restart docker && \
           sh master.sh && \
           docker pull fanux/lvscare && \
           cp /usr/sbin/conntrack ../bin/ && \
           cd ../.. && sleep 360 && docker images && \
           sh save.sh && \
           tar zcvf kube$1-arm64.tar.gz kube && mv kube$1-arm64.tar.gz /tmp/kube$1-arm64.tar.gz

# run init test
sh huawei/test.sh ${DRONE_TAG} $FIP


echo "release package, need remote server passwd, WARN will pending"
remotecmd "cd /tmp/ && wget http://gosspublic.alicdn.com/ossutil/1.6.19/ossutil64  && chmod 755 ossutil64 && \
           mv ossutil64 /usr/sbin/ossutil64 && \
           ossutil64 config -e oss-accelerate.aliyuncs.com -i ${OSS_ID} -k ${OSS_KEY}  -L CH -c oss-config && \
           wget https://github.com/cuisongliu/sshcmd/releases/download/v1.5.2/sshcmd && chmod a+x sshcmd && \
           mv sshcmd /usr/sbin/sshcmd"
remotecmd "cd /root/cloud-kernel/ && sh huawei/oss.sh $1 $2"

#sshcmd --passwd $2 --host store.lameleg.com --cmd "sh release-k8s.sh $1 $FIP"

echo "release instance"
sleep 20
mycli hw delete --id $ID --eipId $FIPID