BUILD_TYPE=$1
TARGET_IP=$2
SERVER_IP=192.168.200.127

if [ "${BUILD_TYPE}" == "mevoco_ci" ]; then
	TEST_TYPE=mevoco_bat
elif [ "${BUILD_TYPE}" == "zstack_ci" ]; then
	TEST_TYPE=zstack_bat_test
elif [ "${BUILD_TYPE}" == "mevoco_ui_dev" ]; then
	TEST_TYPE=mevoco_ui_dev_bat_test
fi
rm -rf /home/${TARGET_IP}/
mkdir -p /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/${BUILD_TYPE}_build_number.txt /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/test_script/run_test.sh /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack-utility/zstackbuild/zstack-all-in-one.tar /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack-utility.tar /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack-woodpecker.tar /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/build_zstack.template.sh /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/deploy.template.tmpt /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/jobs/${TEST_TYPE}/workspace/zstack_woodpecker_version.txt /home/${TARGET_IP}/
