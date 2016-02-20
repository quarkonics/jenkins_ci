#set -x
ZSTACK_SERVER_IP=192.168.200.1
JQ=/var/lib/jenkins/jq-linux64

zstack_login()
{
	RESULT=`curl -H "Content-Type: application/json" -d '{"org.zstack.header.identity.APILogInByAccountMsg": {"password": "b109f3bbbc244eb82441917ed06d618b9008dd09b3befd1b5e07394c706a8bb980b1d7785e5976ec049b46df5f1326af5a2ea6d103fd07c95385ffab0cacbc86", "accountName": "admin"}}' http://${ZSTACK_SERVER_IP}:8080/zstack/api 2>/dev/null| ${JQ} -r '.["result"]'`
	echo ${RESULT} | ${JQ} -r '.["org.zstack.header.identity.APILogInReply"]["inventory"]["uuid"]'
}

zstack_logout()
{
	UUID=$1
	curl -H "Content-Type: application/json" -d "{\"org.zstack.header.identity.APILogOutMsg\": {\"sessionUuid\": \"${UUID}\"}}" http://${ZSTACK_SERVER_IP}:8080/zstack/api 2>/dev/null >/dev/null
}

zstack_do_job()
{
	SESSION_UUID=$1
	API_CALL=$2
	TIMEOUT=600

	JOB_UUID=`curl -H "Content-Type: application/json" -d "${API_CALL}" http://${ZSTACK_SERVER_IP}:8080/zstack/api 2>/dev/null | ${JQ} -r '.["uuid"]'`
	echo ${JOB_UUID}
	START_TIME=${SECONDS}
	while [ 1 -eq 1 ]; do
		JOB_STATUS=`curl http://192.168.200.1:8080/zstack/api/result/${JOB_UUID} 2>/dev/null | ${JQ} -r '.["state"]'`
		if [ "${JOB_STATUS}" == "Done" ]; then
			return 0
		fi
		DURATION=`echo ${SECONDS}-${START_TIME} | bc`
		if [ ${DURATION} -gt 600 ]; then
			return 1
		fi
		sleep 5
	done
}

zstack_create_vm()
{
	SESSION_UUID=$1
	VM_NAME=$2
	JOB_UUID=`zstack_do_job ${SESSION_UUID} "{\"org.zstack.header.vm.APICreateVmInstanceMsg\": {\"name\":\"${VM_NAME}\", \"instanceOfferingUuid\": \"57ae5a7dc4da405baf64790c9908c8f7\",\"imageUuid\": \"87194d47d3bb41bf9992f114687a16ab\", \"l3NetworkUuids\": [\"c579072cfd00477d9bc8b31648a10deb\"], \"session\": {\"uuid\": \"${SESSION_UUID}\"}}}"`
	RESULT=`curl http://192.168.200.1:8080/zstack/api/result/${JOB_UUID} 2>/dev/null | ${JQ} -r '.["result"]'`
	echo ${RESULT} | ${JQ} -r '.["org.zstack.header.vm.APICreateVmInstanceEvent"]["inventory"]["uuid"]'
}

zstack_destroy_vm()
{
	SESSION_UUID=$1
	VM_UUID=$2

	JOB_UUID=`zstack_do_job ${SESSION_UUID} "{\"org.zstack.header.vm.APIDestroyVmInstanceMsg\": {\"uuid\": \"${VM_UUID}\", \"session\": {\"uuid\": \"${SESSION_UUID}\"}}}"`
	JOB_UUID=`zstack_do_job ${SESSION_UUID} "{\"org.zstack.header.vm.APIExpungeVmInstanceMsg\": {\"uuid\": \"${VM_UUID}\", \"session\": {\"uuid\": \"${SESSION_UUID}\"}}}"`
}

zstack_query_vm()
{
	SESSION_UUID=$1
	VM_UUID=$2
	FIELD=$3

	RESULT=`curl -H "Content-Type: application/json" -d "{\"org.zstack.header.vm.APIQueryVmInstanceMsg\": {\"conditions\": [{\"name\": \"uuid\", \"value\": \"${VM_UUID}\", \"op\": \"=\"}], \"session\": {\"uuid\": \"${SESSION_UUID}\"}}}" http://192.168.200.1:8080/zstack/api/ 2>/dev/null | ${JQ} -r '.["result"]'`
	echo ${RESULT} | ${JQ} -r ".[\"org.zstack.header.vm.APIQueryVmInstanceReply\"]${FIELD}"
}

#SESSION_UUID=$(zstack_login)
#VM_UUID=$(zstack_create_vm ${SESSION_UUID} jenkins_try_create_vm2)
#zstack_query_vm ${SESSION_UUID} ${VM_UUID} '["inventories"][0]["vmNics"][0]["ip"]'
#zstack_destroy_vm ${SESSION_UUID} ${VM_UUID}
#zstack_logout ${SESSION_UUID}
