BUILD_TYPE=$1
TARGET_IP=$2
WORKSPACE=$3
SERVER_IP=172.20.11.87

rm -rf /home/${TARGET_IP}/
mkdir -p /home/${TARGET_IP}/

NEW_HOSTNAME=$(basename `dirname ${WORKSPACE}`)
hostnamectl set-hostname ${NEW_HOSTNAME}
echo "127.0.0.1 ${NEW_HOSTNAME}" >>/etc/hosts
scp ${SERVER_IP}:${WORKSPACE}/${BUILD_TYPE}_build_number.txt /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/test_script/run_nightly_test.sh /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/aliyun.repo /etc/yum.repos.d/
scp ${SERVER_IP}:/var/lib/jenkins/163.repo /etc/yum.repos.d/
scp ${SERVER_IP}:${WORKSPACE}/zstack-utility/zstackbuild/zstack-all-in-one.tar /home/${TARGET_IP}/
scp ${SERVER_IP}:${WORKSPACE}/zstack-utility.tar /home/${TARGET_IP}/
scp ${SERVER_IP}:${WORKSPACE}/zstack-woodpecker.tar /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/build_zstack.template.sh /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/deploy.vr.tmpt /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/deploy.multihosts.tmpt /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/deploy.xml /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/deploy-local-ps.xml /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/deploy-local-nfs.xml /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/integration.xml /home/${TARGET_IP}/
scp ${SERVER_IP}:${WORKSPACE}/zstack_woodpecker_version.txt /home/${TARGET_IP}/
scp ${SERVER_IP}:/var/lib/jenkins/zstack-internal-yum.repo /etc/yum.repos.d/

TESTSUITES="basic virtualrouter virtualrouter_localstorage virtualrouter_local+nfs"
for TS in ${TESTSUITES}; do
	E_TS=`echo ${TS} | sed 's/(/_/' | sed 's/)//' | sed 's/+/_/'`
	scp 192.168.200.1:/httpd/${BUILD_TYPE}/${E_TS}.ref /home/${TARGET_IP}/ || echo ignore
done
