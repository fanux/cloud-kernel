list=$(crictl  images|grep -v 'IMAGE ID'|awk '{print $1":"$2}')
for image in ${list[@]}
do
  ctr images pull $image
done
ctr images export images.tar `crictl  images|grep -v 'IMAGE ID'|awk '{print $1":"$2}'`
mv images.tar kube/images/
