#!/bin/bash
dir=$(dirname $0)

source $dir/color.sh

# deploy kubefate
cd $dir/../../k8s-deploy

echo "$INFO: kubefate Install"
make install
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

# get ingress 80 nodeport
ingressNodePort=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')

ingressPodName=$(kubectl -n ingress-nginx get pod -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')

ingressNodeIp=$(kubectl -n ingress-nginx get pod/$ingressPodName -o jsonpath='{.status.hostIP}')

# set host
echo "$INFO: set hosts"
echo $ingressNodeIp kubefate.net >> /etc/hosts

# set SERVICEURL
echo "$INFO: check kubefate version"
export FATECLOUD_SERVICEURL=kubefate.net:$ingressNodePort
echo $FATECLOUD_SERVICEURL
bin/kubefate version
if [ $? -ne 0 ];
  then
    echo "$ERROR: kubefate command line error, checkout ingress"
    exit 1
fi

# create cluster
echo "$INFO: Cluster Install"
jobUUID=$(bin/kubefate cluster install -f cluster.yaml | sed "s/^.*=//g" )

MAX_TRY=60
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "$ERROR: ClusterInstall job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe jobUUID | grep -w Status | awk '{print $2}' )
    if [ $status == "Success" ]
    then
        echo "$Success: ClusterInstall job success"
        break
    fi
    echo "[INFO] Current kubefate ClusterInstall job status: $status want Success"
    sleep 3
done

# clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')

# update cluster
echo "$INFO: Cluster Update"
jobUUID=$(bin/kubefate cluster update -f cluster-spark.yaml | sed "s/^.*=//g" )
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "$ERROR: ClusterUpdate job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $status == "Success" ]
    then
        echo "$Success: ClusterUpdate job success"
        break
    fi
    echo "[INFO] Current kubefate ClusterUpdate job status: $status want Success"
    sleep 3
done

# cluster list
# gotUUID=$(bin/kubefate cluster list |  grep -w  | awk '{print $2}' )
echo "$INFO: Cluster Describe"
clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')

# cluster describe
clusterStatus=$(bin/kubefate cluster describe $clusterUUID | grep -w Status | awk '{print $2}' )
if [ $clusterStatus == "Running" ]
then
    echo "$Success: Cluster Status is Running"
else
    echo "$ERROR: Cluster Status is $clusterStatus"
    exit 1
fi
# delete cluster
echo "$INFO: Cluster Delete"
jobUUID=$(bin/kubefate cluster delete $clusterUUID | sed "s/^.*=//g" )
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "$ERROR: ClusterDelete job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $status == "Success" ]
    then
        echo "$Success: ClusterDelete job success"
        break
    fi
    echo "[INFO] Current kubefate ClusterDelete job status: $status want Success"
    sleep 3
done
echo "$INFO: Cluster CURD test Success!"
echo "$INFO: kubefate Uninstall"
make uninstall
echo "$INFO: fate_deplot_test done."
exit 0

