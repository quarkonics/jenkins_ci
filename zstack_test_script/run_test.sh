IP=$1
TEST_TARGET=$2
OVERALL_BUILD_NUMBER=$3

if [ ${TEST_TARGET} == "build_zstack" ]; then
	CI_TARGET=zstack_ci
elif [ ${TEST_TARGET} == "build_mevoco" ]; then
	CI_TARGET=mevoco_ci
fi

CENTOS_REPO="alibase 163base"
EPEL_REPO="epel aliepel"

for CR in ${CENTOS_REPO}; do
	for ER in ${EPEL_REPO}; do
		echo "try use ${CR} ${ER} repo"
		yum-config-manager --disable alibase > /dev/null
		yum-config-manager --disable 163base > /dev/null
		yum-config-manager --disable epel > /dev/null
		yum-config-manager --disable aliepel > /dev/null
		yum-config-manager --enable ${CR} > /dev/null
		yum-config-manager --enable ${ER} > /dev/null
		yum clean metadata
		INSTALL_VIM=success
		yum --nogpgcheck install -y vim || INSTALL_VIM=failure
		if [ ${INSTALL_VIM} == "failure" ]; then
			continue || echo continue
		fi
		yum clean metadata
		INSTALL_MARIADB=success
		yum --nogpgcheck install -y mariadb mariadb-server || INSTALL_MARIADB=failure
		if [ ${INSTALL_MARIADB} == "failure" ]; then
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
			continue || echo continue
		fi
		
		cd ../tools/
		sh copy_test_config_to_local.sh
		scp /home/${IP}/deploy.${IP}.tmpt /root/.zstackwoodpecker/integrationtest/vm/deploy.tmpt
		cd /home/${IP}/zstack-woodpecker/dailytest/
		rm -rf /home/${IP}/result_${IP}.log /home/${IP}/log_${IP}.tgz
		RUN_BASIC=success
		./zstest.py -s basic | tee /home/${IP}/result_${IP}.log || RUN_BASIC=failure
		cat /home/${IP}/result_${IP}.log | sed -n '/--*$/{:1;N;/--*$/{p;b};N;b1}' | grep -v '\-\-' | awk '{if ($1~/:/) {tttt=$1;gsub(":","", tttt)} else {if ($2==1) {printf("%s/%s PASS\n", tttt, $1, $2, $3, $4, $5)} else {if ($3==1) {printf("%s/%s FAIL\n", tttt, $1, $2, $3, $4, $5)} else {if ($4==1) {printf("%s/%s SKIP\n", tttt, $1, $2, $3, $4, $5)} else {if ($5==1) {printf("%s/%s TIMEOUT\n", tttt, $1, $2, $3, $4, $5)}}}}}}' > /home/${IP}/result_${IP}.summary
		SUITE_SETUP=success
		grep suite_setup /home/${IP}/result_${IP}.summary | grep PASS || SUITE_SETUP=failure
		if [ ${SUITE_SETUP} == "failure" ]; then
			continue || echo continue
		fi

		tar czh config_xml/test-result/latest > /home/${IP}/log_${IP}.tgz
		rm -rf /home/${IP}/report.${IP}.json
		TOTAL_NUMBER=`cat /home/${IP}/result_${IP}.summary | wc -l`
		PASS_NUMBER=`cat /home/${IP}/result_${IP}.summary | grep -w PASS | wc -l`
		echo "{\"fields\":[{\"value\":\"zstack-woodpecker:\",\"short\":true},{\"value\":\"`cat /home/${IP}/zstack_woodpecker_version.txt`\",\"short\":true}],\"color\":\"${COLOR}\"}," > /home/${IP}/report.${IP}.json
		cat /home/${IP}/result_${IP}.log  | sed -n '/--*$/{:1;N;/--*$/{p;b};N;b1}' | grep -v '\-\-' | awk '{if ($1~/:/) {tttt=$1;gsub(":","", tttt)} else {if ($2!=1) {printf("{\"fields\":[{\"value\":\"%s/%s\",\"short\":true},{\"value\":\"FAIL\",\"short\":true}],\"color\":\"F35A00\"},", tttt, $1, $2, $3, $4, $5)}}}' >> /home/${IP}/report.${IP}.json
		echo "{}" >> /home/${IP}/report.${IP}.json
		curl -X POST --data-urlencode "payload={\"text\" : \"BAT result(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/log.tgz|Log>) against ${TEST_TARGET} - #${OVERALL_BUILD_NUMBER}(<http://192.168.200.1/mirror/${CI_TARGET}/${OVERALL_BUILD_NUMBER}/|Open>)PASS/TOTAL=${PASS_NUMBER}/${TOTAL_NUMBER}\", \"username\" : \"jenkins\", \"attachments\" : [`cat /home/${IP}/report.${IP}.json`]}" https://hooks.slack.com/services/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
		mkdir -p zstack_ci/${OVERALL_BUILD_NUMBER}/
		cp /home/${IP}/log_${IP}.tgz zstack_ci/${OVERALL_BUILD_NUMBER}/log.tgz
		exit 0
	done
done
