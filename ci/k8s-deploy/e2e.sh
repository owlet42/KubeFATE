#!/bin/bash
dir=$(dirname $0)

# check kubectl
kubectl version
if [ $? -ne 0 ];
  then
    echo "K8s environment abnormal"
    exit 1
fi

# deploy kubefate
cd $dir/../../k8s-deploy

# namespace and rbac
kubectl apply -f rbac-config.yaml

# deploy kubefate
kubectl apply -f kubefate.yaml

# check kubefate deploy success
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

# check kubefate
make

# get ingress 80 nodeport
ingressNodePort=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')

ingressPodName=$(kubectl -n ingress-nginx get pod -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')

ingressNodeIp=$(kubectl -n ingress-nginx get pod/$ingressPodName -o jsonpath='{.status.hostIP}')

# set host
echo $ingressNodeIp kubefate.net >> /etc/hosts
cat /etc/hosts
# set SERVICEURL
export FATECLOUD_SERVICEURL=kubefate.net:$ingressNodePort
echo $FATECLOUD_SERVICEURL
bin/kubefate version
if [ $? -ne 0 ];
  then
    echo "kubefate command line error, checkout ingress"
    exit 1
fi
# delete
kubectl delete -f kubefate.yaml
kubectl delete -f rbac-config.yaml
# get k8s node ip (for NodePort)
exit 0

# create cluster

# update cluster

# cluster list
# cluster describe

# delete cluster

# job list

# job describe

# chart upload

# chart list