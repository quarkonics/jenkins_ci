IP=$1
TEST_TARGET=$2
OVERALL_BUILD_NUMBER=$3
IP_RANGE_NAME=$4
TESTSUITES=$5

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
CENTOS_REPO="alibase 163base internalbase"
EPEL_REPO="aliepel epel"
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
	BASIC_TS=`echo ${TS} | awk -F '_' '{print $1}'`
	BASIC_TS_CONF=`echo ${TS} | awk -F '_' '{print $2}'`
	TESTSUITE_DONE=0
	for CR in ${CENTOS_REPO}; do
		for ER in ${EPEL_REPO}; do
			rsync -a /home/${IP}/zstack-woodpecker/dailytest/config_xml/ /home/${IP}/config_xml/ || echo "no log yet"
			if [ ${TESTSUITE_DONE} -eq 1 ]; then
				continue || echo continue
			fi
			echo "try use ${CR} ${ER} repo"
			yum-config-manager --disable alibase > /dev/null
			yum-config-manager --disable 163base > /dev/null
			yum-config-manager --disable internalbase > /dev/null
			yum-config-manager --disable epel > /dev/null
			yum-config-manager --disable aliepel > /dev/null
			yum-config-manager --enable ${CR} > /dev/null
			yum-config-manager --enable ${ER} > /dev/null
			yum clean metadata
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
			sed -i "s/aliyun/${CR1}/g" /home/${IP}/zstack-woodpecker/zstackwoodpecker/zstackwoodpecker/setup_actions.py
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
			sh copy_test_config_to_local.sh
			scp /home/${IP}/deploy.vr.tmpt /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/TARGET_IP/${IP}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			if [ "${IP_RANGE_NAME}" == "IP_RANGE1" ]; then
				MANAGEMENT_IP_START="192.168.201.2"
				MANAGEMENT_IP_END="192.168.201.16"
				IP_START="192.168.201.17"
				IP_END="192.168.201.31"
				NOVLAN_ID1=200
				VID_START=300
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE2" ]; then
				MANAGEMENT_IP_START="192.168.201.32"
				MANAGEMENT_IP_END="192.168.201.46"
				IP_START="192.168.201.47"
				IP_END="192.168.201.61"
				NOVLAN_ID1=202
				VID_START=306
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE3" ]; then
				MANAGEMENT_IP_START="192.168.201.62"
				MANAGEMENT_IP_END="192.168.201.76"
				IP_START="192.168.201.77"
				IP_END="192.168.201.91"
				NOVLAN_ID1=204
				VID_START=312
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE4" ]; then
				MANAGEMENT_IP_START="192.168.201.92"
				MANAGEMENT_IP_END="192.168.201.106"
				IP_START="192.168.201.107"
				IP_END="192.168.201.121"
				NOVLAN_ID1=206
				VID_START=318
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE5" ]; then
				MANAGEMENT_IP_START="192.168.201.122"
				MANAGEMENT_IP_END="192.168.201.136"
				IP_START="192.168.201.137"
				IP_END="192.168.201.151"
				NOVLAN_ID1=208
				VID_START=324
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE6" ]; then
				MANAGEMENT_IP_START="192.168.201.152"
				MANAGEMENT_IP_END="192.168.201.166"
				IP_START="192.168.201.167"
				IP_END="192.168.201.181"
				NOVLAN_ID1=210
				VID_START=330
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE7" ]; then
				MANAGEMENT_IP_START="192.168.201.182"
				MANAGEMENT_IP_END="192.168.201.196"
				IP_START="192.168.201.197"
				IP_END="192.168.201.211"
				NOVLAN_ID1=212
				VID_START=336
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE8" ]; then
				MANAGEMENT_IP_START="192.168.201.212"
				MANAGEMENT_IP_END="192.168.201.226"
				IP_START="192.168.201.227"
				IP_END="192.168.201.241"
				NOVLAN_ID1=214
				VID_START=342
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE9" ]; then
				MANAGEMENT_IP_START="192.168.202.2"
				MANAGEMENT_IP_END="192.168.202.16"
				IP_START="192.168.202.17"
				IP_END="192.168.202.31"
				NOVLAN_ID1=216
				VID_START=348
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE10" ]; then
				MANAGEMENT_IP_START="192.168.202.32"
				MANAGEMENT_IP_END="192.168.202.46"
				IP_START="192.168.202.47"
				IP_END="192.168.202.61"
				NOVLAN_ID1=218
				VID_START=354
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE11" ]; then
				MANAGEMENT_IP_START="192.168.202.62"
				MANAGEMENT_IP_END="192.168.202.76"
				IP_START="192.168.202.77"
				IP_END="192.168.202.91"
				NOVLAN_ID1=220
				VID_START=360
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE12" ]; then
				MANAGEMENT_IP_START="192.168.202.92"
				MANAGEMENT_IP_END="192.168.202.106"
				IP_START="192.168.202.107"
				IP_END="192.168.202.121"
				NOVLAN_ID1=222
				VID_START=366
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE13" ]; then
				MANAGEMENT_IP_START="192.168.202.122"
				MANAGEMENT_IP_END="192.168.202.136"
				IP_START="192.168.202.137"
				IP_END="192.168.202.151"
				NOVLAN_ID1=224
				VID_START=372
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE14" ]; then
				MANAGEMENT_IP_START="192.168.202.152"
				MANAGEMENT_IP_END="192.168.202.166"
				IP_START="192.168.202.167"
				IP_END="192.168.202.181"
				NOVLAN_ID1=226
				VID_START=378
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE15" ]; then
				MANAGEMENT_IP_START="192.168.202.182"
				MANAGEMENT_IP_END="192.168.202.196"
				IP_START="192.168.202.197"
				IP_END="192.168.202.211"
				NOVLAN_ID1=228
				VID_START=384
			elif [ "${IP_RANGE_NAME}" == "IP_RANGE16" ]; then
				MANAGEMENT_IP_START="192.168.202.212"
				MANAGEMENT_IP_END="192.168.202.226"
				IP_START="192.168.202.227"
				IP_END="192.168.202.241"
				NOVLAN_ID1=230
				VID_START=390
			fi

			sed -i "s/MANAGEMENT_IP_START/${MANAGEMENT_IP_START}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/MANAGEMENT_IP_END/${MANAGEMENT_IP_END}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/IP_START/${IP_START}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			sed -i "s/IP_END/${IP_END}/g" /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			NOVLAN_ID2=`echo ${NOVLAN_ID1}+1 | bc`
			vconfig add eth0 ${NOVLAN_ID1} || echo ignore
			vconfig add eth0 ${NOVLAN_ID2} || echo ignore
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

			scp /home/${IP}/deploy.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy.xml
			scp /home/${IP}/deploy-local-ps.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy-local-ps.xml
			scp /home/${IP}/deploy-local-nfs.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy-local-nfs.xml
			cd /home/${IP}/zstack-woodpecker/dailytest/
			rm -rf /home/${IP}/result_${IP}.log /home/${IP}/log_${IP}.tgz
			RUN_BASIC=success
			if [ "${BASIC_TS_CONF}" == "" ]; then
				./zstest.py -s ${BASIC_TS} | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
#				./zstest.py -c 236 | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
			else
				if [ "${BASIC_TS_CONF}" == "localstorage" ]; then
					./zstest.py -s ${BASIC_TS} -C /root/.zstackwoodpecker/integrationtest/vm/${BASIC_TS}/test-config-local-ps.xml | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
				elif [ "${BASIC_TS_CONF}" == "local+nfs" ]; then
					./zstest.py -s ${BASIC_TS} -C /root/.zstackwoodpecker/integrationtest/vm/${BASIC_TS}/test-config-local-nfs.xml | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
				fi
			fi
			cat /home/${IP}/result_${IP}.log | sed -n '/--*$/{:1;N;/--*$/{p;b};N;b1}' | grep -v '\-\-' | awk '{if ($1~/:/) {tttt=$1;gsub(":","", tttt)} else {if ($2==1) {printf("%s/%s PASS\n", tttt, $1, $2, $3, $4, $5)} else {if ($3==1) {printf("%s/%s FAIL\n", tttt, $1, $2, $3, $4, $5)} else {if ($4==1) {printf("%s/%s SKIP\n", tttt, $1, $2, $3, $4, $5)} else {if ($5==1) {printf("%s/%s TIMEOUT\n", tttt, $1, $2, $3, $4, $5)}}}}}}' > /home/${IP}/result_${IP}.summary
			SUITE_SETUP=success
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
	mkdir -p ${CI_TARGET}/${OVERALL_BUILD_NUMBER}/
	cp /home/${IP}/log_${IP}.tgz ${CI_TARGET}/${OVERALL_BUILD_NUMBER}/nightly_log.tgz
	scp -r ${CI_TARGET}/${OVERALL_BUILD_NUMBER} 192.168.200.1:/httpd/${CI_TARGET}/
	scp /home/${IP}/result_${IP}.summary 192.168.200.1:/httpd/${CI_TARGET}/${OVERALL_BUILD_NUMBER}
	scp /home/${IP}/result_${IP}.summary 192.168.200.1:/httpd/${CI_TARGET}/${E_TS}.ref
done

#curl -X POST --data-urlencode "payload={\"text\" : \"Nightly result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`{}]}" https://hooks.slack.com/services/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
curl -X POST --data-urlencode "payload={\"text\" : \"Nightly result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`{}]}" https://hooks.slack.com/services/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
if [ "${SUITE_SETUP}" == "failure" ]; then
	exit 1
fi

