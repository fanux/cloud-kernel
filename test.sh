#!/bin/bash
# clientip is where to run sealos server FIP
# sh test.sh 1.15.4 clientip

echo "create 4 vms"
aliyun ecs RunInstances --Amount 4 \
    --ImageId centos_7_04_64_20G_alibase_201701015.vhd \
    --InstanceType ecs.c5.xlarge \
    --Action RunInstances \
    --InternetChargeType PayByTraffic \
    --InternetMaxBandwidthIn 50 \
    --InternetMaxBandwidthOut 50 \
    --Password Fanux#123 \
    --InstanceChargeType PostPaid \
    --SpotStrategy SpotAsPriceGo \
    --RegionId cn-hongkong  \
    --SecurityGroupId sg-j6cb45dolegxcb32b47w \
    --VSwitchId vsw-j6cvaap9o5a7et8uumqyx \
    --ZoneId cn-hongkong-c > InstanceId.json
ID0=$(jq -r ".InstanceIdSets.InstanceIdSet[0]" < InstanceId.json)
ID1=$(jq -r ".InstanceIdSets.InstanceIdSet[1]" < InstanceId.json)
ID2=$(jq -r ".InstanceIdSets.InstanceIdSet[2]" < InstanceId.json)
ID3=$(jq -r ".InstanceIdSets.InstanceIdSet[3]" < InstanceId.json)

echo "sleep 40s wait for IP and FIP"
sleep 40 # wait for IP

aliyun ecs DescribeInstanceAttribute --InstanceId $ID0 > info.json
master0=$(jq -r ".VpcAttributes.PrivateIpAddress.IpAddress[0]" < info.json)
master0FIP=$(jq -r ".PublicIpAddress.IpAddress[0]" < info.json)

aliyun ecs DescribeInstanceAttribute --InstanceId $ID1 > info.json
master1=$(jq -r ".VpcAttributes.PrivateIpAddress.IpAddress[0]" < info.json)

aliyun ecs DescribeInstanceAttribute --InstanceId $ID2 > info.json
master2=$(jq -r ".VpcAttributes.PrivateIpAddress.IpAddress[0]" < info.json)

aliyun ecs DescribeInstanceAttribute --InstanceId $ID3 > info.json
node=$(jq -r ".VpcAttributes.PrivateIpAddress.IpAddress[0]" < info.json)

echo "[CHECK] all nodes IP: $master0 $master1 $master2 $node"

echo "wait for sshd start"
sleep 100 # wait for sshd
# $2 is sealos clientip
alias remotecmd="sshcmd --pk ./release.pem --host $2 --cmd"

echo "sshcmd sealos command"
SEALOS_URL=$(curl -LsSf https://api.github.com/repos/fanux/sealos/releases/latest | jq ".assets[0].browser_download_url")
# remove "
SEALOS_URL=$(echo $SEALOS_URL | sed 's/.\(.*\)/\1/' | sed 's/\(.*\)./\1/')

remotecmd "wget -c $SEALOS_URL && chmod +x sealos && mv sealos /usr/bin "

remotecmd "sealos init --master $master0 --master $master1 --master $master2 \
    --node $node --passwd Fanux#123 --version v$1 --pkg-url /tmp/kube$1.tar.gz"

echo "[CHECK] wait for everything ok"
sleep 40
sshcmd --passwd Fanux#123 --host $master0FIP --cmd "kubectl get node && kubectl get pod --all-namespaces"

echo "[CHECK] sshcmd sealos clean command"
#remotecmd "sealos clean --master $master0 --master $master1 --master $master2 \
#    --node $node --passwd Fanux#123"

echo "release instance"
sleep 20
aliyun ecs DeleteInstances --InstanceId.1 $ID0 --RegionId cn-hongkong --Force true
aliyun ecs DeleteInstances --InstanceId.1 $ID1 --RegionId cn-hongkong --Force true
aliyun ecs DeleteInstances --InstanceId.1 $ID2 --RegionId cn-hongkong --Force true
aliyun ecs DeleteInstances --InstanceId.1 $ID3 --RegionId cn-hongkong --Force true
