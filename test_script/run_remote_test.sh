set -x
. /var/lib/jenkins/test_script/zstack_http_api.sh
SERVER_IP=192.168.200.127

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
SESSION_UUID=$(zstack_login)
VM_UUID=$(zstack_create_vm ${SESSION_UUID} jenkins_${TEST_TYPE}_${BUILD_TYPE})
VM_IP=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID} '["inventories"][0]["vmNics"][0]["ip"]')

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

setup_no_password ${VM_IP}
ssh root@${VM_IP} date
ssh root@${VM_IP} rm -rf /home/${VM_IP}/
ssh root@${VM_IP} mkdir -p /home/${VM_IP}/
if [ "${TEST_TYPE}" == "bat" ]; then
	scp /var/lib/jenkins/test_script/prepare.sh root@${VM_IP}:/home/${VM_IP}/
	scp /var/lib/jenkins/test_script/run_test.sh root@${VM_IP}:/home/${VM_IP}/

	ssh root@${VM_IP} bash -ex /home/${VM_IP}/prepare.sh ${BUILD_TYPE} ${VM_IP}
	ssh root@${VM_IP} bash -ex /home/${VM_IP}/run_test.sh ${VM_IP} ${BUILD_TYPE} ${OVERALL_BUILD_NUMBER}
elif [ "${TEST_TYPE}" == "nightly" ]; then
	scp /var/lib/jenkins/test_script/prepare_nightly.sh root@${VM_IP}:/home/${VM_IP}/
	scp /var/lib/jenkins/test_script/run_nightly_test.sh root@${VM_IP}:/home/${VM_IP}/

	ssh root@${VM_IP} bash -ex /home/${VM_IP}/prepare_nightly.sh ${BUILD_TYPE} ${VM_IP}
	ssh root@${VM_IP} bash -ex /home/${VM_IP}/run_nightly_test.sh ${VM_IP} ${BUILD_TYPE} ${OVERALL_BUILD_NUMBER} ${IP_RANGE_NAME}
fi
zstack_destroy_vm ${SESSION_UUID} ${VM_UUID}
zstack_logout ${SESSION_UUID}
