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
SESSION_UUID=$(zstack_login)
VM_UUID=$(zstack_create_vm ${SESSION_UUID} jenkins_try_create_vm2)
VM_IP=$(zstack_query_vm ${SESSION_UUID} ${VM_UUID} '["inventories"][0]["vmNics"][0]["ip"]')

if [ "${BUILD_TYPE}" == "mevoco_ci" ]; then
	TEST_TYPE=mevoco_bat
elif [ "${BUILD_TYPE}" == "zstack_ci" ]; then
	TEST_TYPE=zstack_bat
elif [ "${BUILD_TYPE}" == "mevoco_ui_dev" ]; then
	TEST_TYPE=mevoco_ui_dev_bat
fi

START_TIME=${SECONDS}
while [ 1 -eq 1 ]; do
	sleep 15
	ping ${VM_IP}
	if [ $? -eq 0 ]; then
		break
	else
		TEMP=`echo ${SECONDS}-${START_TIME} | bc`
		if [ ${TEMP} -gt 600 ] ;then
			exit 1
		fi
	fi
done

setup_no_password ${VM_IP}
START_TIME=${SECONDS}
while [ 1 -eq 1 ]; do
	sleep 15
	if [ $? -eq 0 ]; then
		break
	else
		TEMP=`echo ${SECONDS}-${START_TIME} | bc`
		if [ ${TEMP} -gt 600 ] ;then
			exit 1
		fi
	fi
done
ssh root@${VM_IP} date
#
#
#ssh root@${VM_IP} rm -rf /home/${VM_IP}/
#ssh root@${VM_IP} mkdir -p /home/${VM_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/${BUILD_TYPE}_build_number.txt /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/zstack_test_script/run_test.sh /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack-utility/zstackbuild/zstack-all-in-one.tar /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack-utility.tar /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack-woodpecker.tar /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/build_zstack.${TARGET_IP}.sh /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/deploy.${TARGET_IP}.tmpt /home/${TARGET_IP}/
#scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack_woodpecker_version.txt /home/${TARGET_IP}/

zstack_destroy_vm ${SESSION_UUID} ${VM_UUID}
zstack_logout ${SESSION_UUID}
