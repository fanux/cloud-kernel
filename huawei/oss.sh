#!/bin/bash
cd /tmp
md5=$(md5sum /tmp/kube$1-arm64.tar.gz | awk  '{print $1}')
echo $md5 && ossutil64 -c oss-config cp /tmp/kube$1-arm64.tar.gz oss://sealyun/$md5-$1/kube$1-arm64.tar.gz
echo oss://sealyun/$md5-$1/kube$1-arm64.tar.gz
sshcmd --passwd $2 --host store.lameleg.com --cmd "sh release-k8s-new.sh $1 $md5"
