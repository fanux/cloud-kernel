#!/bin/bash
cd /tmp
md5=$(md5sum /tmp/kube$1.tar.gz | awk  '{print $1}')
echo $md5 && ossutil64 -c oss-config cp /tmp/kube$1.tar.gz oss://sealyun/$md5-$1/kube$1.tar.gz
echo oss://sealyun/$md5-$1/kube$1.tar.gz
sshcmd --passwd $2 --host store.lameleg.com --cmd "sh release-k8s-new.sh $1 $md5"

cat > k8s.yaml << EOF
market:
  body:
    spec:
      name: v$1
      price: 50
      product:
        class: cloud_kernel
        productName: kubernetes
      url: https://sealyun.oss-cn-beijing.aliyuncs.com/$md5-$1/kube$1.tar.gz
    status:
      productVersionStatus: 2
  kind: productVersion
EOF

marketctl create -f k8s.yaml --domain http://market.sealyun.com --token $3
marketctl update -f k8s.yaml --status --domain http://market.sealyun.com --token $3

curl "https://oapi.dingtalk.com/robot/send?access_token=$4" \
   -H "Content-Type: application/json" \
   -d "{\"msgtype\":\"link\",\"link\":{\"text\":\"kubernetes自动发布版本v$1,详细信息请看https://github.com/kubernetes/kubernetes/releases/tag/v$1\",\"title\":\"kubernetes版本发布成功\",\"picUrl\":\"\",\"messageUrl\":\"http://store.lameleg.com\"}}"
