# Copyright 2019-2020 VMware, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# you may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash

BASEDIR=$(dirname "$0")
cd $BASEDIR
WORKINGDIR=$(pwd)

# fetch fate-python image
source ${WORKINGDIR}/.env
source ${WORKINGDIR}/parties.conf

cd ${WORKINGDIR}

work_mode=1


get_party_ip(){
    target_party_id=$1
    for ((i = 0; i < ${#partylist[*]}; i++)); do
        if [ "${partylist[$i]}" = "$target_party_id" ]; then
            target_party_ip=${partyiplist[$i]}
        fi
    done
    return $target_party_ip
}

Test() {

    while [ "$1" != "" ]; do
		case $1 in
		toy_example)
            shift
                if [ "$1" = "" ] || [ "$2" = ""  ]; then
                    echo "No party id was provided, please check your arguments "
                    echo "Example: "
                    echo "         'bash test.sh toy_example 9999 10000'"
                    exit 1
                fi
            toy_example $@
			break
			;;
        min_test_task)
            shift
            min_test_task $@
            break
        ;;
        serving)
            shift
            serving $@
            break
        ;;
		esac
		shift
	done

}

toy_example() {
    echo "start test toy_example"
    guest=$1
    host=$2
    echo "guest_id: "$guest
    echo "host_id: "$host

    target_party_id=$1
    echo "target_party_id: "$target_party_id
    for ((i = 0; i < ${#partylist[*]}; i++)); do
        if [ "${partylist[$i]}" = "$target_party_id" ]; then
            target_party_ip=${partyiplist[$i]}
        fi
    done
    echo "*********************start docker log***************************"
	ssh -tt $user@$target_party_ip <<eeooff
cd $dir
cd confs-$target_party_id

docker-compose exec -T python bash -c '
source /data/projects/python/venv/bin/activate;
cd ../examples/toy_example; 
python run_toy_example.py $guest $host 1
'

exit
eeooff
    echo "*********************end docker log***************************"
    echo "party $target_party_id cluster toy_example test is success!"

}

upload_data() {
    echo "start test upload_data"
    target_party_id=$1
    echo "target_party_id: "$target_party_id
    for ((i = 0; i < ${#partylist[*]}; i++)); do
        if [ "${partylist[$i]}" = "$target_party_id" ]; then
            target_party_ip=${partyiplist[$i]}
        fi
    done
    echo "*********************start docker log***************************"
	ssh -tt $user@$target_party_ip <<eeooff
cd $dir
cd confs-$target_party_id

docker-compose exec -T python bash -c '
source /data/projects/python/venv/bin/activate;
cd ../examples/scripts; 
python upload_default_data.py -m ${work_mode}
'

exit
eeooff
    echo "*********************end docker log***************************"
    echo "party $target_party_id cluster upload_data test is success!"
}

min_test_task(){
    echo "start test min_test_task"
    guest_id=$1
    host_id=$2
    arbiter_id=$3
    echo "guest_id: "$guest_id
    echo "host_id: "$host_id
    echo "arbiter_id: "$arbiter_id
    upload_data  $guest_id
    upload_data  $host_id
    upload_data  $arbiter_id
    
    target_party_id=$1
    for ((i = 0; i < ${#partylist[*]}; i++)); do
        if [ "${partylist[$i]}" = "$target_party_id" ]; then
            target_party_ip=${partyiplist[$i]}
        fi
    done
    echo "*********************start docker log***************************"
    ssh -tt $user@$target_party_ip <<eeooff
cd $dir
cd confs-$target_party_id

docker-compose exec -T python bash -c '
source /data/projects/python/venv/bin/activate;
cd ../examples/min_test_task; 
python run_task.py -m ${work_mode} -gid ${guest_id} -hid ${host_id} -aid ${arbiter_id}
'

exit
eeooff
    echo "*********************end docker log***************************"
    echo "party $target_party_id cluster min_test_task test is success!"

}

serving_host(){
    echo "start test serving_host"
    
}


ShowUsage() {
	echo "Usage: "
	echo "Deploy all parties or specified partie(s): bash test.sh type ${guest_id} ${host_id} ${arbiter_id}"
    echo "Example: "
    echo "         'bash test.sh toy_example 9999 10000'"
    echo "         'bash test.sh min_test_task 9999 10000 10000'"
}

main() {
	if [ "$1" = "" ] || [ "$" = "--help" ]; then
		ShowUsage
		exit 1
	else
		Test "$@"
	fi

	exit 0
}

main $@