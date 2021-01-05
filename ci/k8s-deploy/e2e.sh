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
go build -buildmode=exe -o bin/kubefate.exe kubefate.go

export FATECLOUD_SERVICEURL=kubefate.net:31246

bin/kubefate version
if [ $? -ne 0 ];
  then
    echo "kubefate error"
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