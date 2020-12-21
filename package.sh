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

ERROR=$(cat InstanceId.json | grep ERROR | cut -d ":" -f 2 | sed 's/^[ ]*//g')
if [[ $ERROR = "SDK.ServerError" ]]; then
    ErrorCode=$(cat InstanceId.json | grep ErrorCode | cut -d ":" -f 2 | sed 's/^[ ]*//g')
    Message=$(cat InstanceId.json | grep Message | cut -d ":" -f 2 | sed 's/^[ ]*//g')
    Recommend=http:$(cat InstanceId.json | grep Recommend | cut -d ":" -f 3 | sed 's/^[ ]*//g')
    curl "https://oapi.dingtalk.com/robot/send?access_token=${DD_TOKEN}" \
       -H "Content-Type: application/json" \
       -d "{\"msgtype\":\"link\",\"link\":{\"text\":\"打包版本v$1失败,错误码: $ErrorCode,详细信息: $Message\",\"title\":\"kubernetes版本v$1打包失败\",\"picUrl\":\"\",\"messageUrl\":\"$Recommend\"}}"
    exit
fi

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
remotecmd 'git clone https://github.com/fanux/cloud-kernel && cd cloud-kernel && git checkout containerd'

echo "install kubernetes bin"
remotecmd "cd cloud-kernel && \
           wget https://dl.k8s.io/v$1/kubernetes-server-linux-amd64.tar.gz && \
           wget https://github.com/containerd/containerd/releases/download/v1.3.9/cri-containerd-cni-1.3.9-linux-amd64.tar.gz && \
           cp  cri-containerd-cni-1.3.9-linux-amd64.tar.gz kube/containerd/cri-containerd-cni-linux-amd64.tar.gz && \
           tar zxvf kubernetes-server-linux-amd64.tar.gz && \
           cd kube && \
           cp ../kubernetes/server/bin/kubectl bin/ && \
           cp ../kubernetes/server/bin/kubelet bin/ && \
           cp ../kubernetes/server/bin/kubeadm bin/ && \
           sed s/k8s_version/$1/g -i conf/kubeadm.yaml && \
           cd shell && chmod a+x containerd.sh && sh containerd.sh && \
           systemctl restart containerd && \
           sh init.sh && sh master.sh && \
           ctr -n=k8s.io images pull docker.io/fanux/lvscare:latest && \
           cp /usr/sbin/conntrack ../bin/ && \
           cp /usr/lib64/libseccomp* ../lib64/ && \
           cd ../.. &&  sleep 180 && crictl images && \
           sh save.sh && \
           tar zcvf kube$1.tar.gz kube && mv kube$1.tar.gz /tmp/"

# run init test
sh test.sh ${DRONE_TAG} $FIP


echo "release package, need remote server passwd, WARN will pending"
remotecmd "cd /root/cloud-kernel/ && sh oss.sh $1 ${MARKET_TOKEN}"

#curl "https://oapi.dingtalk.com/robot/send?access_token=${DD_TOKEN}" \
#   -H "Content-Type: application/json" \
#   -d "{\"msgtype\":\"link\",\"link\":{\"text\":\"kubernetes自动发布版本v$1,详细信息请看https://github.com/kubernetes/kubernetes/releases/tag/v$1\",\"title\":\"kubernetes版本发布成功\",\"picUrl\":\"\",\"messageUrl\":\"http://store.lameleg.com\"}}"
#sshcmd --passwd $2 --host store.lameleg.com --cmd "sh release-k8s.sh $1 $FIP"

echo "release instance"
sleep 20
aliyun ecs DeleteInstances --InstanceId.1 $ID --RegionId cn-hongkong --Force true
