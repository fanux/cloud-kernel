aliyun ecs RunInstances --Amount 1 --ImageId centos_7_04_64_20G_alibase_201701015.vhd --InstanceType ecs.c5.xlarge --Action RunInstances --InternetChargeType PayByTraffic --InternetMaxBandwidthIn 5 --InternetMaxBandwidthOut 5 --Password Fanux#123 --InstanceChargeType PostPaid --SpotStrategy SpotAsPriceGo --RegionId cn-hongkong  --SecurityGroupId sg-j6cg7qx8vufo7vopqwiy --VSwitchId vsw-j6crutzktn5vdivgeb6tv --ZoneId cn-hongkong-b > InstanceId.json
ID=$(jq -r ".InstanceIdSets.InstanceIdSet[0]" < InstanceId.json)
sleep 40 # wait for IP
aliyun ecs DescribeInstanceAttribute --InstanceId $ID > info.json
FIP=$(jq -r ".PublicIpAddress.IpAddress[0]" < info.json)
IP=$(jq -r ".VpcAttributes.PrivateIpAddress.IpAddress[0]" < info.json)
cat info.json && echo $ID && echo $FIP && echo $IP
sleep 40 # wait for sshd
echo "ssh pass"
# sshpass -p Fanux#123 ssh root@$FIP 'touch /root/hello' 
sshcmd --passwd Fanux#123 --host $FIP --cmd 'touch /root/hello' 

echo "install docker"
sshcmd --passwd Fanux#123 --host $FIP --cmd 'yum install -y docker && systemctl start docker' 

echo "install sealos"
sshcmd --passwd Fanux#123 --host $FIP --cmd 'wget https://github.com/fanux/sealos/releases/download/v2.0.5/sealos && chmod +x sealos && mv sealos /usr/bin' 

echo "test install"
sshcmd --passwd Fanux#123 --host $FIP --cmd "sealos init --master $IP --passwd Fanux#123 --pkg-url https://sealyun.oss-cn-beijing.aliyuncs.com/free/kube1.15.0.tar.gz --version v1.15.0" 

echo "release instance"
sleep 100
aliyun ecs DeleteInstances --InstanceId.1 $ID --RegionId cn-hongkong --Force true
