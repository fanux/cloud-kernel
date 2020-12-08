#!/bin/bash
# package.sh [k8s version] password
# package.sh 1.16.0 storepass

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
    --SecurityGroupId sg-j6cb45dolegxcb32b47w \
    --VSwitchId vsw-j6cvaap9o5a7et8uumqyx \
    --ZoneId cn-hongkong-c > InstanceId.json
cat InstanceId.json
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
remotecmd 'yum install -y git conntrack'

echo "clone cloud kernel"
## version >= 1.20 Use containerd
version_ge(){
    test "$(echo "$@" | tr ' ' '\n' | sort -rV | head -n 1)" == "$1"
}
if version_ge "$1" 1.20; then
	remotecmd "git clone https://github.com/fanux/cloud-kernel && cd cloud-kernel && git checkout containerd"
else 
	remotecmd 'git clone https://github.com/fanux/cloud-kernel'
fi

echo "install kubernetes bin"
remotecmd "cd cloud-kernel && \
           wget https://dl.k8s.io/v$1/kubernetes-server-linux-amd64.tar.gz && \
           wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.12.tgz && \
           cp  docker-19.03.12.tgz kube/docker/docker.tgz && \
           tar zxvf kubernetes-server-linux-amd64.tar.gz && \
           cd kube && \
           cp ../kubernetes/server/bin/kubectl bin/ && \
           cp ../kubernetes/server/bin/kubelet bin/ && \
           cp ../kubernetes/server/bin/kubeadm bin/ && \
           sed s/k8s_version/$1/g -i conf/kubeadm.yaml && \
           cd shell && chmod a+x docker.sh && sh docker.sh && \
           rm -rf /etc/docker/daemon.json && systemctl restart docker && \
           sh init.sh && sh master.sh && \
           docker pull fanux/lvscare && \
           cp /usr/sbin/conntrack ../bin/ && \
           cd ../.. &&  sleep 180 && docker images && \
           sh save.sh && \
           tar zcvf kube$1.tar.gz kube && mv kube$1.tar.gz /tmp/"

# run init test
sh test.sh ${DRONE_TAG} $FIP


echo "release package, need remote server passwd, WARN will pending"
remotecmd "cd /root/cloud-kernel/ && sh oss.sh $1 ${MARKET_TOKEN}"

curl "https://oapi.dingtalk.com/robot/send?access_token=${DD_TOKEN}" \
   -H "Content-Type: application/json" \
   -d "{\"msgtype\":\"link\",\"link\":{\"text\":\"kubernetes自动发布版本v$1,详细信息请看https://github.com/kubernetes/kubernetes/releases/tag/v$1\",\"title\":\"kubernetes版本发布成功\",\"picUrl\":\"\",\"messageUrl\":\"http://store.lameleg.com\"}}"
#sshcmd --passwd $2 --host store.lameleg.com --cmd "sh release-k8s.sh $1 $FIP"

echo "release instance"
sleep 20
aliyun ecs DeleteInstances --InstanceId.1 $ID --RegionId cn-hongkong --Force true
