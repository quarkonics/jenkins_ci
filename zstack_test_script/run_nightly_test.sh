IP=$1
TEST_TARGET=$2
OVERALL_BUILD_NUMBER=$3

if [ ${TEST_TARGET} == "build_zstack" ]; then
	CI_TARGET=zstack_ci
elif [ ${TEST_TARGET} == "build_mevoco" ]; then
	CI_TARGET=mevoco_ci
fi

TESTSUITES="basic virtualrouter virtualrouter(localstorage) virtualrouter(local+nfs) installation"
CENTOS_REPO="alibase 163base internalbase"
EPEL_REPO="epel aliepel"
PASS_NUMBER=0
TOTAL_NUMBER=0

rm -rf /home/${IP}/report.${IP}.json
rm -rf /home/${IP}/zstack-woodpecker/dailytest/config_xml/test-result/
rm -rf /home/${IP}/config_xml/
mkdir -p /home/${IP}/config_xml/
rm -rf /home/${IP}/log_${IP}.tgz
echo "{\"fields\":[{\"value\":\"zstack-woodpecker:\",\"short\":true},{\"value\":\"`cat /home/${IP}/zstack_woodpecker_version.txt`\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
for TS in ${TESTSUITES}; do
	rm -rf /home/nfs/*
	rm -rf /home/local-ps/*
	rm -rf /home/sftpBackupStorage/*
	rm -rf /home/${IP}/result_${IP}.summary
	BASIC_TS=`echo ${TS} | awk -F '(' '{print $1}'`
	BASIC_TS_CONF=`echo ${TS} | awk -F '(' '{print $2}' | awk -F ')' '{print $1}'`
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
			scp /home/${IP}/build_zstack.${IP}.sh /home/${IP}/zstack-woodpecker/dailytest/build_zstack.sh
			chmod a+x /home/${IP}/zstack-woodpecker/dailytest/build_zstack.sh
			DEPLOY_ZSTACK=success
			./zstest.py -b || DEPLOY_ZSTACK=failure
			if [ ${DEPLOY_ZSTACK} == "failure" ]; then
				echo "{\"fields\":[{\"value\":\"fail to setup testsuite ${TS} with yum repo:\",\"short\":true},{\"value\":\"${CR} and ${ER}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /home/${IP}/report.${IP}.json
				continue || echo continue
			fi
			
			cd ../tools/
			sh copy_test_config_to_local.sh
			scp /home/${IP}/deploy.${IP}.tmpt /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
			scp /home/${IP}/deploy.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy.xml
			scp /home/${IP}/deploy-local-ps.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy-local-ps.xml
			scp /home/${IP}/deploy-local-nfs.xml /root/.zstackwoodpecker/integrationtest/vm/virtualrouter/deploy-local-nfs.xml
			cd /home/${IP}/zstack-woodpecker/dailytest/
			rm -rf /home/${IP}/result_${IP}.log /home/${IP}/log_${IP}.tgz
			RUN_BASIC=success
			if [ "${BASIC_TS_CONF}" == "" ]; then
				./zstest.py -s ${BASIC_TS} | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
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
			cat /home/${IP}/result_${IP}.log  | sed -n '/--*$/{:1;N;/--*$/{p;b};N;b1}' | grep -v '\-\-' | awk '{if ($1~/:/) {tttt=$1;gsub(":","", tttt)} else {if ($2!=1) {printf("{\"fields\":[{\"value\":\"%s/%s\",\"short\":true},{\"value\":\"FAIL\",\"short\":true}],\"color\":\"F35A00\"},", tttt, $1, $2, $3, $4, $5)}}}' >> /home/${IP}/report.${IP}.json
			TESTSUITE_DONE=1
		done
	done
	curl -X POST --data-urlencode "payload={\"text\" : \"Nightly result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`{}]}" https://hooks.slack.com/services/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
	rsync -a /home/${IP}/zstack-woodpecker/dailytest/config_xml/ /home/${IP}/config_xml/
	tar czh /home/${IP}/config_xml/test-result/latest > /home/${IP}/log_${IP}.tgz
	mkdir -p zstack_ci/${OVERALL_BUILD_NUMBER}/
	cp /home/${IP}/log_${IP}.tgz zstack_ci/${OVERALL_BUILD_NUMBER}/log.tgz
done
