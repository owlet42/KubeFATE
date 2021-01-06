#!/bin/bash
dir=$(dirname $0)

source $dir/color.sh

# deploy kubefate
cd $dir/../../k8s-deploy

echo -e "$INFO: kubefate Install"
make install
MAX_TRY=60
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo -e "kubefate deploy timeOut, please check"
       kubectl get pod -n kube-fate
       exit 1
    fi
    status=$(kubectl get pod -l fate=kubefate -n kube-fate -o jsonpath='{.items[0].status.phase}')
    if [ $status == "Running" ]
    then
        echo -e "# kubefate are ok"
        break
    fi
    echo -e "# Current kubefate pod status: $status want Running"
    sleep 3
done

# get ingress 80 nodeport
ingressNodePort=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')

ingressPodName=$(kubectl -n ingress-nginx get pod -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')

ingressNodeIp=$(kubectl -n ingress-nginx get pod/$ingressPodName -o jsonpath='{.status.hostIP}')

# set host
echo -e "$INFO: set hosts"
echo $ingressNodeIp kubefate.net >> /etc/hosts

# set SERVICEURL
echo -e "$INFO: check kubefate version"
ingressNodePort=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')
export FATECLOUD_SERVICEURL=kubefate.net:$ingressNodePort
echo $FATECLOUD_SERVICEURL
bin/kubefate version
if [ $? -ne 0 ];
  then
    echo -e "$ERROR: kubefate command line error, checkout ingress"
    exit 1
fi

# create cluster
echo -e "$INFO: Cluster Install"
jobUUID=$(bin/kubefate cluster install -f cluster.yaml | sed "s/^.*=//g" | sed "s/\r//g")
echo -e "DEBUG: jobUUID: $jobUUID"
MAX_TRY=60
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo -e "$ERROR: ClusterInstall job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $jobstatus == "Success" ]
    then
        echo -e "$Success: ClusterInstall job success"
        break
    fi
    echo "[INFO] Current kubefate ClusterInstall job status: $jobstatus want Success"
    sleep 3
done

# clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')

# update cluster
echo -e "$INFO: Cluster Update"
jobUUID=$(bin/kubefate cluster update -f cluster-spark.yaml | sed "s/^.*=//g"  | sed "s/\r//g")
echo -e "DEBUG: jobUUID: $jobUUID"
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo -e "$ERROR: ClusterUpdate job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $jobstatus == "Success" ]
    then
        echo -e "$Success: ClusterUpdate job success"
        break
    fi
    echo "[INFO] Current kubefate ClusterUpdate job status: $jobstatus want Success"
    sleep 3
done

# cluster list
# gotUUID=$(bin/kubefate cluster list |  grep -w  | awk '{print $2}' )
echo -e "$INFO: Cluster Describe"
clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')
echo -e "DEBUG: clusterUUID: $clusterUUID"
# cluster describe
clusterStatus=$(bin/kubefate cluster describe $clusterUUID | grep -w Status | awk '{print $2}' )
if [ $clusterStatus == "Running" ]
then
    echo -e "$Success: Cluster Status is Running"
else
    echo -e "$ERROR: Cluster Status is $clusterStatus"
    exit 1
fi
# delete cluster
echo -e "$INFO: Cluster Delete"
jobUUID=$(bin/kubefate cluster delete $clusterUUID | sed "s/^.*=//g"  | sed "s/\r//g")
echo -e "DEBUG: jobUUID: $jobUUID"
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo -e "$ERROR: ClusterDelete job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $jobstatus == "Success" ]
    then
        echo -e "$Success: ClusterDelete job success"
        break
    fi
    echo "[INFO] Current kubefate ClusterDelete job status: $jobstatus want Success"
    sleep 3
done
echo -e "$INFO: Cluster CURD test Success!"
echo -e "$INFO: kubefate Uninstall"
make uninstall
echo -e "$INFO: fate_deplot_test done."
exit 0

