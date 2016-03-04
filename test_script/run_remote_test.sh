set -x
. /var/lib/jenkins/test_script/zstack_http_api.sh
SERVER_IP=172.20.11.87

setup_no_password()
{
	TARGET_IP=$1
	sshpass -p password scp /var/lib/jenkins/.ssh/* root@${TARGET_IP}:/root/.ssh/
	sshpass -p password scp /etc/ssh/ssh_config root@${TARGET_IP}:/etc/ssh/ssh_config
}

BUILD_TYPE=$1
TEST_TYPE=$2
OVERALL_BUILD_NUMBER=$3
IP_RANGE_NAME=$4
WORKSPACE=$5
TESTSUITES=$6
SESSION_UUID=$(zstack_login)
if [ "${TESTSUITES}" == "" ]; then
	VM_NAME=jenkins_${TEST_TYPE}_${BUILD_TYPE}_${OVERALL_BUILD_NUMBER}
else
	VM_NAME=jenkins_${TEST_TYPE}_${BUILD_TYPE}_${OVERALL_BUILD_NUMBER}_`echo ${TESTSUITES} | sed 's/\ /_/g'`
fi
if [ "${IP_RANGE_NAME}" == "IP_RANGE1" ]; then
	CANDIDATE_HOST_IP=192.168.200.2
elif [ "${IP_RANGE_NAME}" == "IP_RANGE2" ]; then
	CANDIDATE_HOST_IP=192.168.200.3
elif [ "${IP_RANGE_NAME}" == "IP_RANGE3" ]; then
	CANDIDATE_HOST_IP=192.168.200.4
elif [ "${IP_RANGE_NAME}" == "IP_RANGE4" ]; then
	CANDIDATE_HOST_IP=192.168.200.5
elif [ "${IP_RANGE_NAME}" == "IP_RANGE5" ]; then
	CANDIDATE_HOST_IP=192.168.200.6
elif [ "${IP_RANGE_NAME}" == "IP_RANGE6" ]; then
	CANDIDATE_HOST_IP=192.168.200.7
elif [ "${IP_RANGE_NAME}" == "IP_RANGE7" ]; then
	CANDIDATE_HOST_IP=192.168.200.8
elif [ "${IP_RANGE_NAME}" == "IP_RANGE8" ]; then
	CANDIDATE_HOST_IP=192.168.200.9
elif [ "${IP_RANGE_NAME}" == "IP_RANGE9" ]; then
	CANDIDATE_HOST_IP=192.168.200.10
fi

CANDIDATE_HOST_UUID=$(zstack_query_host_by_ip ${SESSION_UUID} ${CANDIDATE_HOST_IP} '["inventories"][0]["uuid"]')
VM_UUID=$(zstack_create_vm_host ${SESSION_UUID} ${VM_NAME} ${CANDIDATE_HOST_UUID})
VM_IP=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID} '["inventories"][0]["vmNics"][0]["ip"]')
HOST_UUID=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID} '["inventories"][0]["hostUuid"]')
HOST_IP=$(zstack_query_host ${SESSION_UUID} ${HOST_UUID} '["inventories"][0]["managementIp"]')

if [ "${TESTSUITES}" == "multihosts" ]; then
	VM_UUID2=$(zstack_create_vm_host ${SESSION_UUID} ${VM_NAME}2 ${CANDIDATE_HOST_UUID})
	VM_IP2=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID2} '["inventories"][0]["vmNics"][0]["ip"]')
	VM_UUID3=$(zstack_create_vm_host ${SESSION_UUID} ${VM_NAME}3 ${CANDIDATE_HOST_UUID})
	VM_IP3=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID3} '["inventories"][0]["vmNics"][0]["ip"]')
	VM_UUID4=$(zstack_create_vm_host ${SESSION_UUID} ${VM_NAME}4 ${CANDIDATE_HOST_UUID})
	VM_IP4=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID4} '["inventories"][0]["vmNics"][0]["ip"]')
	VM_UUID5=$(zstack_create_vm_host ${SESSION_UUID} ${VM_NAME}5 ${CANDIDATE_HOST_UUID})
	VM_IP5=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID5} '["inventories"][0]["vmNics"][0]["ip"]')
fi

keep_stop_raid_check()
{
	HOST_IP=$1
	while [ 1 -eq 1 ]; do
		IS_CHECKING=1
		sshpass -p password ssh root@${HOST_IP} cat /proc/mdstat |grep check || IS_CHECKING=0
		if [ ${IS_CHECKING} -eq 1 ]; then
			MD_NAME=`sshpass -p password ssh root@${HOST_IP} 'cat /proc/mdstat' | grep active | awk '{print $1}'`
			sshpass -p password ssh root@${HOST_IP} "echo idle > /sys/block/${MD_NAME}/md/sync_action"
		fi
		sleep 60
	done
}

check_vm_status()
{
	local VM_IP=$1
	START_TIME=${SECONDS}
	while [ 1 -eq 1 ]; do
		sleep 15
		PING_STATUS='success'
		ping -c 4 ${VM_IP} || PING_STATUS='failure'
		if [ "${PING_STATUS}" == "success" ]; then
			break || echo break
		else
			TEMP=`echo ${SECONDS}-${START_TIME} | bc`
			if [ ${TEMP} -gt 600 ] ;then
				exit 1
			fi
		fi
	done
}

check_vm_status ${VM_IP}

if [ "${TESTSUITES}" == "multihosts" ]; then
	check_vm_status ${VM_IP2}
	check_vm_status ${VM_IP3}
	check_vm_status ${VM_IP4}
	check_vm_status ${VM_IP5}
fi

setup_no_password ${VM_IP}
ssh root@${VM_IP} date
ssh root@${VM_IP} rm -rf /home/${VM_IP}/
ssh root@${VM_IP} mkdir -p /home/${VM_IP}/
RUN_TEST=success
if [ "${TEST_TYPE}" == "bat" ]; then
	scp /var/lib/jenkins/test_script/prepare.sh root@${VM_IP}:/home/${VM_IP}/
	scp /var/lib/jenkins/test_script/run_test.sh root@${VM_IP}:/home/${VM_IP}/

	ssh root@${VM_IP} bash -ex /home/${VM_IP}/prepare.sh ${BUILD_TYPE} ${VM_IP}
	keep_stop_raid_check ${HOST_IP} &
	CHECKER_PID=$!
	ssh root@${VM_IP} bash -ex /home/${VM_IP}/run_test.sh ${VM_IP} ${BUILD_TYPE} ${OVERALL_BUILD_NUMBER} || RUN_TEST=fail 
elif [ "${TEST_TYPE}" == "nightly" ]; then
	scp /var/lib/jenkins/test_script/prepare_nightly.sh root@${VM_IP}:/home/${VM_IP}/
	scp /var/lib/jenkins/test_script/run_nightly_test.sh root@${VM_IP}:/home/${VM_IP}/

	ssh root@${VM_IP} bash -ex /home/${VM_IP}/prepare_nightly.sh ${BUILD_TYPE} ${VM_IP} ${WORKSPACE}
	keep_stop_raid_check ${HOST_IP} &
	CHECKER_PID=$!
	ssh root@${VM_IP} bash -ex /home/${VM_IP}/run_nightly_test.sh ${VM_IP} ${BUILD_TYPE} ${OVERALL_BUILD_NUMBER} ${IP_RANGE_NAME} "${TESTSUITES}" ${VM_IP2} ${VM_IP3} ${VM_IP4} ${VM_IP5} || RUN_TEST=fail
fi

if [ "${RUN_TEST}" == "fail" ]; then
	kill -9 ${CHECKER_PID}
	exit 1
fi
#if [ "${TEST_TYPE}" == "bat" ]; then
	zstack_destroy_vm ${SESSION_UUID} ${VM_UUID}
#fi

if [ "${TESTSUITES}" == "multihosts" ]; then
	zstack_destroy_vm ${SESSION_UUID} ${VM_UUID2}
	zstack_destroy_vm ${SESSION_UUID} ${VM_UUID3}
	zstack_destroy_vm ${SESSION_UUID} ${VM_UUID4}
	zstack_destroy_vm ${SESSION_UUID} ${VM_UUID5}
fi
zstack_logout ${SESSION_UUID}
