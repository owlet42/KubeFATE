#!/bin/bash
dir=$(dirname $0)

source $dir/color.sh

# deploy kubefate
cd $dir/../../k8s-deploy

echo -e "$INFO: kubefate Install"
make install
MAX_TRY=120
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
        echo -e "$INFO: kubefate are ok"
        break
    fi
    echo -e "[INFO] Current kubefate pod status: $status want Running"
    sleep 2
done

sleep 5

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

# upload chart

bin/kubefate chart upload -f 

# Is mirror specified
if [$FATE_IMG_REGISTRY == ""]
then
  REGISTRY=""
else
  REGISTRY=$FATE_IMG_REGISTRY
fi
if [$FATE_IMG_TAG == ""]
then
  FATE_IMG_TAG="latest"
fi
if [$FATE_SERVING_IMG_TAG == ""]
then
  FATE_SERVING_IMG_TAG="latest"
fi
echo -e "DEBUG: IMG: ${IMG}"
# set kubefate image:tag
sed -i "s#registry: ""#image: ${REGISTRY}#g" cluster.yaml
sed -i "s#registry: ""#image: ${REGISTRY}#g" cluster-spark.yaml
sed -i "s#registry: ""#image: ${REGISTRY}#g" cluster-serving.yaml

sed -i "s#imageTag: ""#imageTag: ${FATE_IMG_TAG}#g" cluster.yaml
sed -i "s#imageTag: ""#imageTag: ${FATE_IMG_TAG}#g" cluster-spark.yaml
sed -i "s#imageTag: ""#imageTag: ${FATE_SERVING_IMG_TAG}#g" cluster-serving.yaml

# create cluster
echo -e "$INFO: Cluster Install"
rust=$(bin/kubefate cluster install -f cluster.yaml )
jobUUID=""
jobUUID=$( echo $rust | sed "s/^.*=//g" | sed "s/\r//g")
echo -e "DEBUG: jobUUID: $jobUUID"
if [[ $jobUUID == "" ]]
then
    echo -e "$Error: $rust"
    exit 1
fi
MAX_TRY=120
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [[ $i -eq $MAX_TRY ]]
    then
       echo -e "$ERROR: ClusterInstall job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [[ $jobstatus == "Success" ]]
    then
        echo -e "$Success: ClusterInstall job success"
        break
    fi
    if [[ $jobstatus != "Pending" ]] && [[ $jobstatus != "Running" ]]
    then
        echo -e "$ERROR: ClusterInstall job status error, status: $jobstatus"
        bin/kubefate job describe $jobUUID
        exit 1
    fi
    echo "[INFO] Current kubefate ClusterInstall job status: $jobstatus want Success"
    sleep 5
done

# clusterUUID=$(bin/kubefate job describe $jobUUID | grep -w ClusterId | awk '{print $2}')

# update cluster
echo -e "$INFO: Cluster Update"
rust=$(bin/kubefate cluster update -f cluster-spark.yaml)
jobUUID=$( echo $rust | sed "s/^.*=//g"  | sed "s/\r//g")
echo -e "DEBUG: jobUUID: $jobUUID"
if [[ $jobUUID == "" ]]
then
    echo -e "$Error: $rust"
    exit 1
fi
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [[ $i -eq $MAX_TRY ]]
    then
       echo -e "$ERROR: ClusterUpdate job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [[ $jobstatus == "Success" ]]
    then
        echo -e "$Success: ClusterUpdate job success"
        break
    fi
    if [[ $jobstatus != "Pending" ]]  &&  [[ $jobstatus != "Running" ]]
    then
        echo -e "$ERROR: ClusterUpdate job status error, status: $jobstatus"
        bin/kubefate job describe $jobUUID
        exit 1
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
rust=$(bin/kubefate cluster delete $clusterUUID )
jobUUID=$( echo $rust | sed "s/^.*=//g"  | sed "s/\r//g")
echo -e "DEBUG: jobUUID: $jobUUID"
if [[ $jobUUID == "" ]]
then
    echo -e "$Error: $rust"
    exit 1
fi
for (( i=1; i<=$MAX_TRY; i++ ))
do
    if [[ $i -eq $MAX_TRY ]]
    then
       echo -e "$ERROR: ClusterDelete job timeOut, please check"
       bin/kubefate job describe $jobUUID
       exit 1
    fi
    jobstatus=$(bin/kubefate job describe $jobUUID | grep -w Status | awk '{print $2}' )
    if [[ $jobstatus == "Success" ]]
    then
        echo -e "$Success: ClusterDelete job success"
        break
    fi
    if [[ $jobstatus != "Pending" ]]  &&  [[ $jobstatus != "Running" ]]
    then
        echo -e "$ERROR: ClusterDelete job status error, status: $jobstatus"
        bin/kubefate job describe $jobUUID
        exit 1
    fi
    echo "[INFO] Current kubefate ClusterDelete job status: $jobstatus want Success"
    sleep 3
done
echo -e "$INFO: Cluster CURD test Success!"
echo -e "$INFO: kubefate Uninstall"
make uninstall
sed -i '$d' /etc/hosts
echo -e "$INFO: fate_deploy_test done."
exit 0

