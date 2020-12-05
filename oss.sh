#!/bin/bash
cd /tmp
md5=$(md5sum /tmp/kube$1.tar.gz | awk  '{print $1}')
#ossutil64 -c oss-config cp /tmp/kube$1.tar.gz oss://sealyun/$md5-$1/kube$1.tar.gz
#sshcmd --passwd $2 --host store.lameleg.com --cmd "sh release-k8s-new.sh $1 $md5"
wget https://sealyun-market.oss-accelerate.aliyuncs.com/marketctl/v1.0.1/linux_amd64/marketctl
chmod a+x marketctl
cat > marketctl_$1.yaml << EOF
market:
  body:
    spec:
      name: v$1
      price: 50
      product:
        class: cloud_kernel
        productName: kubernetes
      url: /tmp/kube$1.tar.gz
    status:
      productVersionStatus: ONLINE
  kind: productVersion
EOF

./marketctl create -f marketctl_$1.yaml --domain https://www.sealyun.com --token $2
