#!/bin/bash
dir=$(dirname $0)

# deploy kubefate
cd $dir/../../k8s-deploy

make install

# get ingress 80 nodeport
ingressNodePort=$(kubectl -n ingress-nginx get svc/ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')

ingressPodName=$(kubectl -n ingress-nginx get pod -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')

ingressNodeIp=$(kubectl -n ingress-nginx get pod/$ingressPodName -o jsonpath='{.status.hostIP}')

# set host
echo $ingressNodeIp kubefate.net >> /etc/hosts

# set SERVICEURL
export FATECLOUD_SERVICEURL=kubefate.net:$ingressNodePort
echo $FATECLOUD_SERVICEURL
bin/kubefate version
if [ $? -ne 0 ];
  then
    echo "kubefate command line error, checkout ingress"
    exit 1
fi

# create cluster
jobUUID=$(bin/kubefate cluster install -f cluster.yaml | sed "s/^.*=//g" )

MAX_TRY=60
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "ClusterInstall job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe jobUUID | grep -w Status | awk '{print $2}' )
    if [ $status == "Success" ]
    then
        echo "# ClusterInstall job success"
        break
    fi
    echo "# Current kubefate ClusterInstall job status: $status want Success"
    sleep 3
done

# clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')

# update cluster
jobUUID=$(bin/kubefate cluster update -f cluster-spark.yaml | sed "s/^.*=//g" )
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "ClusterUpdate job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $status == "Success" ]
    then
        echo "# ClusterUpdate job success"
        break
    fi
    echo "# Current kubefate ClusterUpdate job status: $status want Success"
    sleep 3
done

# cluster list
# gotUUID=$(bin/kubefate cluster list |  grep -w  | awk '{print $2}' )

clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')

# cluster describe
clusterStatus=$(bin/kubefate cluster describe $clusterUUID | grep -w Status | awk '{print $2}' )
if [ $clusterStatus == "Running" ]
then
    echo "# Cluster Status is Running"
else
    echo "# Cluster Status is $clusterStatus"
    exit 1
fi
# delete cluster
jobUUID=$(bin/kubefate cluster delete $clusterUUID | sed "s/^.*=//g" )
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [ $i -eq $MAX_TRY ]
    then
       echo "ClusterDelete job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [ $status == "Success" ]
    then
        echo "# ClusterDelete job success"
        break
    fi
    echo "# Current kubefate ClusterDelete job status: $status want Success"
    sleep 3
done

make uninstall

exit 0

