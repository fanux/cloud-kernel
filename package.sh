#!/bin/bash
# package.sh [k8s version] [sealos version]
# package.sh 1.16.0 v2.0.5 storepass

echo "create hongkong vm"
aliyun ecs RunInstances --Amount 1 \
    --ImageId centos_7_04_64_20G_alibase_201701015.vhd \
    --InstanceType ecs.c5.xlarge \
    --Action RunInstances \
    --InternetChargeType PayByTraffic \
    --InternetMaxBandwidthIn 50 \
    --InternetMaxBandwidthOut 50 \
    --KeyPairName release \
    --InstanceChargeType PostPaid \
    --SpotStrategy SpotAsPriceGo \
    --RegionId cn-hongkong  \
    --SecurityGroupId sg-j6cg7qx8vufo7vopqwiy \
    --VSwitchId vsw-j6crutzktn5vdivgeb6tv \
    --ZoneId cn-hongkong-b > InstanceId.json
ID=$(jq -r ".InstanceIdSets.InstanceIdSet[0]" < InstanceId.json)

echo "sleep 40s wait for IP and FIP"
sleep 40 # wait for IP
aliyun ecs DescribeInstanceAttribute --InstanceId $ID > info.json
FIP=$(jq -r ".PublicIpAddress.IpAddress[0]" < info.json)
IP=$(jq -r ".VpcAttributes.PrivateIpAddress.IpAddress[0]" < info.json)
cat info.json && echo $ID && echo $FIP && echo $IP

echo "wait for sshd start"
sleep 100 # wait for sshd

alias remotecmd="sshcmd --pk ./release.pem --host $FIP --cmd"

echo "install git"
remotecmd 'yum install -y git'

echo "clone cloud kernel"
remotecmd 'git clone https://github.com/fanux/cloud-kernel'

echo "install kubernetes bin"
remotecmd "cd cloud-kernel && \
           wget https://dl.k8s.io/v$1/kubernetes-server-linux-amd64.tar.gz && \
           wget https://github.com/fanux/kube/releases/download/v$1-lvscare/kubeadm && \
           wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.0.tgz && \
           cp  docker-19.03.0.tgz kube/docker/docker.tgz && \
           tar zxvf kubernetes-server-linux-amd64.tar.gz && \
           chmod +x kubeadm && \
           cp kubeadm kube/bin/ && \
           cd kube && \
           cp ../kubernetes/server/bin/kubectl bin/ && \
           cp ../kubernetes/server/bin/kubelet bin/ && \
           sed s/k8s_version/$1/g -i conf/kubeadm.yaml && \
           cd shell && sh init.sh && sh master.sh && \
           docker pull fanux/lvscare && \
           wget https://github.com/fanux/sealos/releases/download/$2/sealos && chmod +x sealos && \
           cp sealos /usr/bin && mv sealos ../bin/ && \
           cd ../.. && sleep 160 && docker images && \
           sh save.sh && \
           tar zcvf kube$1.tar.gz kube && mv kube$1.tar.gz /tmp/"

# run init test
sh test.sh ${DRONE_TAG} $FIP

echo "release package, need remote server passwd, WARN will pending"
sshcmd --passwd $3 --host store.lameleg.com --cmd "sh release-k8s.sh $1 $FIP"

echo "release instance"
sleep 20
aliyun ecs DeleteInstances --InstanceId.1 $ID --RegionId cn-hongkong --Force true
