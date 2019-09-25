docker save -o images.tar `docker images|grep ago|awk '{print $1":"$2}'`
mv images.tar kube/images/
