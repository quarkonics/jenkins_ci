BUILD_TYPE=$1
START_TIME=${SECONDS}
bash -ex ${JENKINS_HOME}/real_build.sh ${BUILD_TYPE}
RET=$?
END_TIME=${SECONDS}
DURATION=`echo "${END_TIME}-${START_TIME}" | bc`
if [ ${RET} -ne 0 ]; then
	bash -ex ${JENKINS_HOME}/build_report.sh ${BUILD_TYPE} ${DURATION} Failure
else
	bash -ex ${JENKINS_HOME}/build_report.sh ${BUILD_TYPE} ${DURATION} success
fi
