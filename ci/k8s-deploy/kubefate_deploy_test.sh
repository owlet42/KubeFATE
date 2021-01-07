#!/bin/bash
dir=$(dirname $0)

source $dir/color.sh

# check kubectl
echo -e "$INFO: check kubectl"
kubectl version
if [ $? -ne 0 ];
  then
    echo -e "$ERROR: K8s environment abnormal"
    exit 1
fi

# deploy kubefate
cd $dir/../../k8s-deploy

echo -e "$INFO: apply rbac"
# namespace and rbac
kubectl apply -f rbac-config.yaml

echo -e "$INFO: apply kubefate"
# Is mirror specified
if [$KubeFATE_IMG == ""]
then
  IMG=federatedai/kubefate:latest
else
  IMG=$KubeFATE_IMG
fi
echo -e "DEBUG: IMG: ${IMG}"
# set kubefate image:tag
sed -i "s#image: federatedai/kubefate:.*#image: ${IMG}#g" kubefate.yaml
# deploy kubefate
kubectl apply -f kubefate.yaml

# check kubefate deploy success
echo -e "$INFO: check kubefate deploy success"
MAX_TRY=60
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "kubefate deploy timeOut, please check"
       kubectl get pod -n kube-fate
       exit 1
    fi
    status=$(kubectl get pod -l fate=kubefate -n kube-fate -o jsonpath='{.items[0].status.phase}')
    if [ $status == "Running" ]
    then
        echo "# kubefate are ok"
        break
    fi
    echo "# Current kubefate pod status: $status want Running"
    sleep 3
done

# get ingress nodeip
ingressPodName=$(kubectl -n ingress-nginx get pod -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
ingressNodeIp=$(kubectl -n ingress-nginx get pod/$ingressPodName -o jsonpath='{.status.hostIP}')
# set host
echo -e "$INFO: set hosts"
echo $ingressNodeIp kubefate.net >> /etc/hosts

# set SERVICEURL
echo -e "$INFO: check kubefate version"
# get ingress 80 nodeport
ingressNodePort=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')
export FATECLOUD_SERVICEURL=kubefate.net:$ingressNodePort
echo $FATECLOUD_SERVICEURL
bin/kubefate version
if [ $? -ne 0 ];
  then
    echo -e "$ERROR: kubefate command line error, checkout ingress"
    exit 1
fi

# delete
echo -e "$INFO: clean kubefate"
kubectl delete -f kubefate.yaml
kubectl delete -f rbac-config.yaml

# clean host
sed -i '$d' /etc/hosts
echo -e "$INFO: kubefate_deploy_test done."
exit 0
