IP=$1
TEST_TARGET=$2
OVERALL_BUILD_NUMBER=$3
IP_RANGE_NAME=$4
TESTSUITES=$5
IP2=$6
IP3=$7
IP4=$8
IP5=$9

compare_result()
{
	E_TESTSUITE=$1
	SUMMARYFILE=/home/${IP}/result_${IP}.summary
	REFSUMMARYFILE=/home/${IP}/${E_TESTSUITE}.ref
	for i in $(seq `wc -l ${SUMMARYFILE}|awk '{print $1}'`); do
		TESTCASE=`sed -n "${i}p" ${SUMMARYFILE} | awk '{print $1}'`
		CURRENT_RESULT=`sed -n "${i}p" ${SUMMARYFILE} | awk '{print $2}'`
		REF_RESULT=`grep -w "${TESTCASE}" ${REFSUMMARYFILE} | head -1 | awk '{print $2}'`
		if [ "${REF_RESULT}" == "" ]; then
			REF_RESULT="N/A"
		fi

		if [ "${REF_RESULT}" == "${CURRENT_RESULT}" ]; then
			continue
		fi

		echo "{\"fields\":[{\"value\":\"${TESTCASE}\",\"short\":true},{\"value\":\"${REF_RESULT}->${CURRENT_RESULT}\",\"short\":true}],\"color\":\"AAAAAA\"},"
	done
}

if [ ${TEST_TARGET} == "build_zstack" -o ${TEST_TARGET} == "zstack_ci" ]; then
	CI_TARGET=zstack_ci
elif [ ${TEST_TARGET} == "build_mevoco" -o ${TEST_TARGET} == "mevoco_ci" ]; then
	CI_TARGET=mevoco_ci
fi

if [ "${TESTSUITES}" == "" ]; then
	TESTSUITES="basic virtualrouter virtualrouter_localstorage virtualrouter_local+nfs"
fi
#CENTOS_REPO="alibase internalbase 163base"
CENTOS_REPO="internalbase"
#EPEL_REPO="aliepel internalepel epel"
EPEL_REPO="internalepel"
PASS_NUMBER=0
TOTAL_NUMBER=0

rm -rf /home/${IP}/report.${IP}.json
rm -rf /home/${IP}/zstack-woodpecker/dailytest/config_xml/test-result/
rm -rf /home/${IP}/config_xml/
mkdir -p /home/${IP}/config_xml/
rm -rf /home/${IP}/log_${IP}.tgz
echo "{\"fields\":[{\"value\":\"zstack-woodpecker:\",\"short\":true},{\"value\":\"`cat /home/${IP}/zstack_woodpecker_version.txt`\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json

for TS in ${TESTSUITES}; do
	E_TS=`echo ${TS} | sed 's/(/_/' | sed 's/)//' | sed 's/+/_/'`
	rm -rf /home/nfs/*
	rm -rf /home/local-ps/*
	rm -rf /home/sftpBackupStorage/*
	rm -rf /home/${IP}/result_${IP}.summary
	if [ "${TS}" == "virt_plus" ]; then
		BASIC_TS=virt_plus
		BASIC_TS_CONF=	
	else
		BASIC_TS=`echo ${TS} | awk -F '_' '{print $1}'`
		BASIC_TS_CONF=`echo ${TS} | awk -F '_' '{print $2}'`
	fi
	TESTSUITE_DONE=0
	for CR in ${CENTOS_REPO}; do
		for ER in ${EPEL_REPO}; do
			rsync -a /home/${IP}/zstack-woodpecker/dailytest/config_xml/ /home/${IP}/config_xml/ || echo "no log yet"
			if [ ${TESTSUITE_DONE} -eq 1 ]; then
				continue || echo continue
			fi
			echo "try use ${CR} ${ER} repo"
			for IP_TMP in `echo "${IP} ${IP2} ${IP3} ${IP4} ${IP5}"`; do
				ssh ${IP_TMP} "rm -rf /etc/yum.repos.d/*" 
				scp /etc/yum.repos.d/epel.repo ${IP_TMP}:/etc/yum.repos.d/epel.repo
				scp /etc/yum.repos.d/zstack-internal-yum.repo ${IP_TMP}:/etc/yum.repos.d/zstack-internal-yum.repo
				#ssh ${IP_TMP} yum-config-manager --disable alibase > /dev/null
				#ssh ${IP_TMP} yum-config-manager --disable 163base > /dev/null
				#ssh ${IP_TMP} yum-config-manager --disable internalbase > /dev/null
				#ssh ${IP_TMP} yum-config-manager --disable internalepel > /dev/null
				#ssh ${IP_TMP} yum-config-manager --disable epel > /dev/null
				#ssh ${IP_TMP} yum-config-manager --disable aliepel > /dev/null
				ssh ${IP_TMP} yum-config-manager --enable ${CR} > /dev/null
				ssh ${IP_TMP} yum-config-manager --enable ${ER} > /dev/null
				ssh ${IP_TMP} yum clean metadata
			done
			INSTALL_VIM=success
			yum --nogpgcheck install -y vim || INSTALL_VIM=failure
			if [ ${INSTALL_VIM} == "failure" ]; then
				echo "{\"fields\":[{\"value\":\"fail to setup testsuite ${TS} with yum repo:\",\"short\":true},{\"value\":\"${CR} and ${ER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
				continue || echo continue
			fi
			yum clean metadata
			INSTALL_MARIADB=success
			yum --nogpgcheck install -y mariadb mariadb-server || INSTALL_MARIADB=failure
			if [ ${INSTALL_MARIADB} == "failure" ]; then
				echo "{\"fields\":[{\"value\":\"fail to setup testsuite ${TS} with yum repo:\",\"short\":true},{\"value\":\"${CR} and ${ER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
				continue || echo continue
			fi
			
			cd /home/${IP}/
			rm -rf zstack-woodpecker zstack-utility
			mkdir -p zstack-woodpecker
			tar -x -C zstack-woodpecker -f zstack-woodpecker.tar
			mkdir -p zstack-utility
			tar -x -C zstack-utility -f zstack-utility.tar
			
			if [ ${CR} == "alibase" ]; then
				CR1=aliyun
			elif [ ${CR} == "163base" ]; then
				CR1=163
			fi
			#sed -i "s/aliyun/${CR1}/g" /home/${IP}/zstack-woodpecker/zstackwoodpecker/zstackwoodpecker/setup_actions.py
			sed -i "s/-R aliyun//g" /home/${IP}/zstack-woodpecker/zstackwoodpecker/zstackwoodpecker/setup_actions.py
			cd /home/${IP}/zstack-woodpecker/dailytest/
			scp /home/${IP}/build_zstack.template.sh /home/${IP}/zstack-woodpecker/dailytest/build_zstack.sh
			sed -i "s/TARGET_IP/${IP}/g" /home/${IP}/zstack-woodpecker/dailytest/build_zstack.sh
			chmod a+x /home/${IP}/zstack-woodpecker/dailytest/build_zstack.sh
			DEPLOY_ZSTACK=success
			./zstest.py -b || DEPLOY_ZSTACK=failure
			if [ ${DEPLOY_ZSTACK} == "failure" ]; then
				echo "{\"fields\":[{\"value\":\"fail to setup testsuite ${TS} with yum repo:\",\"short\":true},{\"value\":\"${CR} and ${ER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
				continue || echo continue
			fi
			
			cd ../tools/
			rm -rf /root/.zstackwoodpecker/
			sh copy_test_config_to_local.sh
			scp /home/${IP}/deploy.multihosts.tmpt /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
			scp /home/${IP}/deploy.virt_plus.tmpt /root/.zstackwoodpecker/integrationtest/vm/virt_plus/deploy.tmpt
			scp /home/${IP}/deploy.vr.tmpt /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/TARGET_IP/${IP}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			if [ "${IP_RANGE_NAME}" == "IP_RANGE1" ]; then
				MANAGEMENT_IP_START="172.20.100.0"
				MANAGEMENT_IP_END="172.20.100.31"
				IP_START="172.20.100.32"
				IP_END="172.20.100.63"
				NOVLAN_ID1=200
				VID_START=300
				VID_START2=400
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE2" ]; then
				MANAGEMENT_IP_START="172.20.100.64"
				MANAGEMENT_IP_END="172.20.100.95"
				IP_START="172.20.100.96"
				IP_END="172.20.100.127"
				NOVLAN_ID1=202
				VID_START=306
				VID_START2=420
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE3" ]; then
				MANAGEMENT_IP_START="172.20.100.128"
				MANAGEMENT_IP_END="172.20.100.159"
				IP_START="172.20.100.160"
				IP_END="172.20.100.191"
				NOVLAN_ID1=204
				VID_START=312
				VID_START2=440
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE4" ]; then
				MANAGEMENT_IP_START="172.20.100.192"
				MANAGEMENT_IP_END="172.20.100.223"
				IP_START="172.20.100.224"
				IP_END="172.20.100.255"
				NOVLAN_ID1=206
				VID_START=318
				VID_START2=460
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE5" ]; then
				MANAGEMENT_IP_START="172.20.101.0"
				MANAGEMENT_IP_END="172.20.101.31"
				IP_START="172.20.101.32"
				IP_END="172.20.101.63"
				NOVLAN_ID1=200
				VID_START=300
				VID_START2=480
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE6" ]; then
				MANAGEMENT_IP_START="172.20.101.64"
				MANAGEMENT_IP_END="172.20.101.95"
				IP_START="172.20.101.96"
				IP_END="172.20.101.127"
				NOVLAN_ID1=202
				VID_START=306
				VID_START2=500
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE7" ]; then
				MANAGEMENT_IP_START="172.20.101.128"
				MANAGEMENT_IP_END="172.20.101.159"
				IP_START="172.20.101.160"
				IP_END="172.20.101.191"
				NOVLAN_ID1=204
				VID_START=312
				VID_START2=520
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE8" ]; then
				MANAGEMENT_IP_START="172.20.101.192"
				MANAGEMENT_IP_END="172.20.101.223"
				IP_START="172.20.101.224"
				IP_END="172.20.101.255"
				NOVLAN_ID1=206
				VID_START=318
				VID_START2=540
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE9" ]; then
				MANAGEMENT_IP_START="172.20.102.0"
				MANAGEMENT_IP_END="172.20.102.31"
				IP_START="172.20.102.32"
				IP_END="172.20.102.63"
				NOVLAN_ID1=200
				VID_START=300
				VID_START2=560
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE10" ]; then
				MANAGEMENT_IP_START="172.20.102.64"
				MANAGEMENT_IP_END="172.20.102.95"
				IP_START="172.20.102.96"
				IP_END="172.20.102.127"
				NOVLAN_ID1=202
				VID_START=306
				VID_START2=580
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE11" ]; then
				MANAGEMENT_IP_START="172.20.102.128"
				MANAGEMENT_IP_END="172.20.102.159"
				IP_START="172.20.102.160"
				IP_END="172.20.102.191"
				NOVLAN_ID1=204
				VID_START=312
				VID_START2=600
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE12" ]; then
				MANAGEMENT_IP_START="172.20.102.192"
				MANAGEMENT_IP_END="172.20.102.223"
				IP_START="172.20.102.224"
				IP_END="172.20.102.255"
				NOVLAN_ID1=206
				VID_START=318
				VID_START2=620
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE13" ]; then
				MANAGEMENT_IP_START="172.20.103.0"
				MANAGEMENT_IP_END="172.20.103.31"
				IP_START="172.20.103.32"
				IP_END="172.20.103.63"
				NOVLAN_ID1=200
				VID_START=300
				VID_START2=640
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE14" ]; then
				MANAGEMENT_IP_START="172.20.103.64"
				MANAGEMENT_IP_END="172.20.103.95"
				IP_START="172.20.103.96"
				IP_END="172.20.103.127"
				NOVLAN_ID1=202
				VID_START=306
				VID_START2=660
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE15" ]; then
				MANAGEMENT_IP_START="172.20.103.128"
				MANAGEMENT_IP_END="172.20.103.159"
				IP_START="172.20.103.160"
				IP_END="172.20.103.191"
				NOVLAN_ID1=204
				VID_START=312
				VID_START2=680
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE16" ]; then
				MANAGEMENT_IP_START="172.20.103.192"
				MANAGEMENT_IP_END="172.20.103.223"
				IP_START="172.20.103.224"
				IP_END="172.20.103.255"
				NOVLAN_ID1=206
				VID_START=318
				VID_START2=700
			fi

			sed -i "s/MANAGEMENT_IP_START/${MANAGEMENT_IP_START}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/MANAGEMENT_IP_END/${MANAGEMENT_IP_END}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/IP_START/${IP_START}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/IP_END/${IP_END}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			NOVLAN_ID2=`echo ${NOVLAN_ID1}+1 | bc`

			for IP_TMP in `echo "${IP} ${IP2} ${IP3} ${IP4} ${IP5}"`; do
				ssh ${IP_TMP} vconfig add eth0 ${NOVLAN_ID1} || echo ignore
				ssh ${IP_TMP} vconfig add eth0 ${NOVLAN_ID2} || echo ignore
			done

			sed -i "s/l2NoVlanNetworkName1 = .*$/l2NoVlanNetworkName1 = vlan${NOVLAN_ID1}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/l2NoVlanNetworkName2 = .*$/l2NoVlanNetworkName2 = vlan${NOVLAN_ID2}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/l2NoVlanNetworkInterface1 = .*$/l2NoVlanNetworkInterface1 = eth0.${NOVLAN_ID1}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/l2NoVlanNetworkInterface2 = .*$/l2NoVlanNetworkInterface2 = eth0.${NOVLAN_ID2}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			COUNT=1
			VID_END=`echo ${VID_START}+5 | bc`
			for VID in `seq ${VID_START} ${VID_END}`; do
				sed -i "s/l2Vlan${COUNT} = .*$/l2Vlan${COUNT} = ${VID}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
				COUNT=`echo ${COUNT}+1 | bc`
			done

			COUNT=4
			VID_END2=`echo ${VID_START2}+16 | bc`
			for VID in `seq ${VID_START2} ${VID_END2}`; do
				sed -i "s/l2Vlan${COUNT} = .*$/l2Vlan${COUNT} = ${VID}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
				COUNT=`echo ${COUNT}+1 | bc`
			done
			if [ "${TESTSUITES}" == "multihosts" ]; then
				sed -i "s/vm_ip/${IP}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
				sed -i "s/hostIp = .*$/hostIp = ${IP}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
				sed -i "s/hostIp2 = .*$/hostIp2 = ${IP2}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
				sed -i "s/hostIp3 = .*$/hostIp3 = ${IP3}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
				sed -i "s/hostIp4 = .*$/hostIp4 = ${IP4}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
				sed -i "s/hostIp5 = .*$/hostIp5 = ${IP5}/g" /root/.zstackwoodpecker/integrationtest/vm/multihosts/deploy.tmpt
			fi
			if [ "${TESTSUITES}" == "virt_plus" ]; then
				
				sed -i "s/TARGET_IP/${IP}/g" /root/.zstackwoodpecker/integrationtest/vm/virt_plus/deploy.tmpt
			fi

			scp /home/${IP}/deploy.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy.xml
			scp /home/${IP}/deploy-local-ps.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy-local-ps.xml
			scp /home/${IP}/deploy-local-nfs.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy-local-nfs.xml
			#scp /home/${IP}/integration.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/integration.xml
			#scp /home/${IP}/integration.xml /home/${IP}/zstack-woodpecker/integrationtest/vm/virtualrouter/integration.xml
			cd /home/${IP}/zstack-woodpecker/dailytest/
			rm -rf /home/${IP}/result_${IP}.log /home/${IP}/log_${IP}.tgz
			RUN_BASIC=success
			if [ "${BASIC_TS_CONF}" == "" ]; then
				./zstest.py -s ${BASIC_TS} -t 3600 | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
#				./zstest.py -c 236,243,247 -S -n | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
#				./zstest.py -c 52 | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
			else
				if [ "${BASIC_TS_CONF}" == "localstorage" ]; then
					./zstest.py -s ${BASIC_TS} -t 3600 -C /root/.zstackwoodpecker/integrationtest/vm/${BASIC_TS}/test-config-local-ps.xml | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
				elif [ "${BASIC_TS_CONF}" == "local+nfs" ]; then
					./zstest.py -s ${BASIC_TS} -t 3600 -C /root/.zstackwoodpecker/integrationtest/vm/${BASIC_TS}/test-config-local-nfs.xml | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
				fi
			fi
			cat /home/${IP}/result_${IP}.log | grep '[[:digit:]][[:space:]]*[[:digit:]][[:space:]]*[[:digit:]][[:space:]]*[[:digit:]]$' | awk '{if ($2==1) {printf("%s PASS\n", $1, $2, $3, $4, $5)} else {if ($3==1) {printf("%s FAIL\n", $1, $2, $3, $4, $5)} else {if ($4==1) {printf("%s SKIP\n", $1, $2, $3, $4, $5)} else {if ($5==1) {printf("%s TIMEOUT\n", $1, $2, $3, $4, $5)}}}}}' > /home/${IP}/result_${IP}.summary
			SUITE_SETUP=success

			cp -r /home/${IP}/zstack-woodpecker/dailytest/config_xml /home/${IP}/${CR}_${ER}_config_xml || echo ignore
			cp /usr/local/zstacktest/apache-tomcat/logs/management-server.log /home/${IP}/${CR}_${ER}_management-server.log || echo ignore
			grep suite_setup /home/${IP}/result_${IP}.summary | grep PASS || SUITE_SETUP=failure
			if [ ${SUITE_SETUP} == "failure" ]; then
				echo "{\"fields\":[{\"value\":\"fail to setup testsuite ${TS} with yum repo:\",\"short\":true},{\"value\":\"${CR} and ${ER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
				continue || echo continue
			else
				echo "{\"fields\":[{\"value\":\"setup testsuite ${TS} with yum repo:\",\"short\":true},{\"value\":\"${CR} and ${ER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
			fi
	
			TS_TOTAL_NUMBER=`cat /home/${IP}/result_${IP}.summary | wc -l`
			TS_PASS_NUMBER=`cat /home/${IP}/result_${IP}.summary | grep -w PASS | wc -l`
			let PASS_NUMBER=${PASS_NUMBER}+${TS_PASS_NUMBER}
			let TOTAL_NUMBER=${TOTAL_NUMBER}+${TS_TOTAL_NUMBER}
			echo "{\"fields\":[{\"value\":\"${TS}:\",\"short\":true},{\"value\":\"PASS/TOTAL=${TS_PASS_NUMBER}/${TS_TOTAL_NUMBER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
#			cat /home/${IP}/result_${IP}.log  | sed -n '/--*$/{:1;N;/--*$/{p;b};N;b1}' | grep -v '\-\-' | awk '{if ($1~/:/) {tttt=$1;gsub(":","", tttt)} else {if ($2!=1) {printf("{\"fields\":[{\"value\":\"%s/%s\",\"short\":true},{\"value\":\"FAIL\",\"short\":true}],\"color\":\"F35A00\"},", tttt, $1, $2, $3, $4, $5)}}}' >> /home/${IP}/report.${IP}.json
#			cat /home/${IP}/result_${IP}.summary | grep -v PASS | awk '{printf("{\"fields\":[{\"value\":\"%s\",\"short\":true},{\"value\":\"%s\",\"short\":true}],\"color\":\"F35A00\"},", $1, $2)}' >> /home/${IP}/report.${IP}.json
			compare_result ${E_TS} >> /home/${IP}/report.${IP}.json
			TESTSUITE_DONE=1
		done
	done
#	curl -X POST --data-urlencode "payload={\"text\" : \"Nightly result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`{}]}" https://hooks.slack.com/services/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
	rsync -a /home/${IP}/zstack-woodpecker/dailytest/config_xml/ /home/${IP}/config_xml/
	tar czh /home/${IP}/config_xml/test-result/latest > /home/${IP}/log_${IP}.tgz
	tar czh /usr/local/zstacktest/apache-tomcat/logs/management-server.log > /home/${IP}/management-server_${E_TS}_${IP}.log.tgz
	mkdir -p ${CI_TARGET}/${OVERALL_BUILD_NUMBER}/
	cp /home/${IP}/log_${IP}.tgz ${CI_TARGET}/${OVERALL_BUILD_NUMBER}/nightly_log_${E_TS}_${IP}.tgz
	scp -r ${CI_TARGET}/${OVERALL_BUILD_NUMBER} 192.168.200.1:/httpd/${CI_TARGET}/
	scp /home/${IP}/result_${IP}.summary 192.168.200.1:/httpd/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/result_${E_TS}_${IP}.summary
	scp /home/${IP}/result_${IP}.summary 192.168.200.1:/httpd/${CI_TARGET}/${E_TS}.ref
	scp /home/${IP}/management-server_${E_TS}_${IP}.log.tgz 192.168.200.1:/httpd/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/management-server_${E_TS}_${IP}.log.tgz
done

#curl -X POST --data-urlencode "payload={\"text\" : \"Nightly result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`{}]}" https://hooks.slack.com/services/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
curl -X POST --data-urlencode "payload={\"text\" : \"Nightly result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`{}]}" https://hooks.slack.com/services/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 || echo ignore
if [ "${SUITE_SETUP}" == "failure" ]; then
	exit 1
fi

