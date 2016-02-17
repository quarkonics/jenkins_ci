set -x
VM_NAME=$1
if [ "${VM_NAME}" == "" ]; then
	exit 1
fi
MEVOCO_CLI_CMD="ssh root@192.168.200.1 zstack-cli"
${MEVOCO_CLI_CMD} LogInByAccount accountName=admin password=password
VM_UUID=`${MEVOCO_CLI_CMD} QueryVmInstance name=${VM_NAME} fields=uuid | grep '"uuid":' | awk '{print $2}'`
if [ "${VM_UUID}" == "" ]; then
	exit 1
fi
VM_IP=`${MEVOCO_CLI_CMD} QueryVmInstance name=${VM_NAME} |grep '"ip":' | awk '{print $2}' | awk -F '"' '{print $2}'`

${MEVOCO_CLI_CMD} RebootVmInstance uuid=${VM_UUID}


${MEVOCO_CLI_CMD} LogOut

sleep 20
START_TIME=${SECONDS}
while [ 1 -eq 1 ]; do
	sleep 15
	ssh root@${VM_IP} date
	if [ $? -eq 0 ]; then
		exit 0
	else
		TEMP=`echo ${SECONDS}-${START_TIME} | bc`
		if [ ${TEMP} -gt 600 ] ;then
			exit 1
		fi
	fi
done
