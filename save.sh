ctr -n=k8s.io  images export images.tar $(ctr -n=k8s.io image ls  | awk '{print $1}' | grep -v sha256  | grep -v REF)
mv images.tar kube/images/
