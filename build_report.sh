BUILD_TYPE=$1
DURATION=$2
BUILD_RESULT=$3
if [ "${BUILD_RESULT}" != "success" ]; then
	RESULT_COLOR="AA0000"
else
	RESULT_COLOR="00AA00"
fi
DURATION_MIN=`echo "${DURATION}/60" | bc`
DURATION_SEC=`echo "${DURATION}%60" | bc`
rm -rf /tmp/${BUILD_TYPE}_report.json
BIN_NAME=$(basename `ls zstack-utility/zstackbuild/target/*.bin`)
echo "{\"fallback\":\"${BUILD_TYPE} - #${BUILD_NUMBER}(<http://192.168.200.1/mirror/${BUILD_TYPE}/${BUILD_NUMBER}/|Open>|<http://192.168.200.1/mirror/${BUILD_TYPE}/${BUILD_NUMBER}/${BIN_NAME}|Download>) ${BUILD_RESULT} after ${DURATION_MIN} min ${DURATION_MIN} sec (<http://192.168.200.1/mirror/${BUILD_TYPE}/${BUILD_NUMBER}/${BUILD_TYPE}.log|Log>)\",\"fields\":[{\"value\":\"${BUILD_TYPE} - #${BUILD_NUMBER}(<http://192.168.200.1/mirror/${BUILD_TYPE}/${BUILD_NUMBER}/|Open>|<http://192.168.200.1/mirror/${BUILD_TYPE}/${BUILD_NUMBER}/${BIN_NAME}|Download>)\",\"short\":true},{\"value\":\"${BUILD_RESULT} after ${DURATION_MIN} min ${DURATION_MIN} sec (<http://192.168.200.1/mirror/${BUILD_TYPE}/${BUILD_NUMBER}/${BUILD_TYPE}.log|Log>)\",\"short\":true}],\"color\":\"${RESULT_COLOR}\"}," >> /tmp/${BUILD_TYPE}_report.json
BUILD_VERSIONS_FILE=${BUILD_TYPE}/latest/versions.txt

if [ ! -f ${BUILD_VERSIONS_FILE} ]; then
	exit 1
fi
for i in $(seq `wc -l ${BUILD_VERSIONS_FILE}|awk '{print $1}'`); do
	COMPONENT=`sed -n "${i}p" ${BUILD_VERSIONS_FILE} | awk '{print $1}' | awk -F ':' '{print $1}'`
	COMMIT=`sed -n "${i}p" ${BUILD_VERSIONS_FILE} | awk '{print $2}'`
	SUBJECT=`sed -n "${i}p" ${BUILD_VERSIONS_FILE} | awk '{for (i=2; i<NF; i++) printf("%s ",$i);print $i}' | sed 's/\"/\\\"/g'`
	OLD_COMMIT=`grep "${COMPONENT}:" versions.txt.old | awk '{print $2}'`
	if [ "${OLD_COMMIT}" == "${COMMIT}" ]; then
		COLOR="AAAAAA"
	else
		COLOR=${RESULT_COLOR}
	fi
	echo "{\"fields\":[{\"value\":\"${COMPONENT}:\",\"short\":true},{\"value\":\"${SUBJECT}\",\"short\":true}],\"color\":\"${COLOR}\"}," >> /tmp/${BUILD_TYPE}_report.json
done
echo "{}" >> /tmp/${BUILD_TYPE}_report.json
curl -X POST --data-urlencode "payload={\"username\" : \"jenkins\", \"attachments\" : [`cat /tmp/${BUILD_TYPE}_report.json`]}" https://hooks.slack.com/services/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
#curl -X POST --data-urlencode "payload={\"username\" : \"jenkins\", \"attachments\" : [`cat /tmp/${BUILD_TYPE}_report.json`]}" https://hooks.slack.com/services/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
