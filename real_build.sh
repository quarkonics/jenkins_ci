BUILD_TYPE=$1
if [ -d ../promotions/${BUILD_TYPE}_bat_pass/builds/ ]; then
	cd ../promotions/${BUILD_TYPE}_bat_pass/builds/
	NEXT_PROMOTION_NUM=`cat ../nextBuildNumber`
	DELETE_UNTIL=`echo ${NEXT_PROMOTION_NUM}-20 | bc`
	rm -rf `seq ${DELETE_UNTIL}`
fi
cd ${WORKSPACE}/

rm -rf ${BUILD_TYPE} ${BUILD_TYPE}_build_number.txt
echo ${BUILD_NUMBER} > ${BUILD_TYPE}_build_number.txt
cd ${WORKSPACE}/../builds/
DELETE_UNTIL=`echo ${BUILD_NUMBER}-20 | bc`
rm -rf `seq ${DELETE_UNTIL}`
cd ${WORKSPACE}/
mkdir -p ${BUILD_TYPE}/${BUILD_NUMBER}

rm -rf zstack.tar zstack-utility.tar

cd zstack
tar cfp ../zstack.tar .
echo -n "zstack: " > ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
git log -1 --format="%H %ci %an: %s" >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
git branch -f master
if [ "${BUILD_TYPE}" == "zstack_ci" ]; then
	sed -i /\<module\>test/d pom.xml
	sed -i /\<module\>premium/d pom.xml
fi
cd ..

if [ -d zstack-agent ]; then
	cd zstack-agent
	echo -n "zstack-agent: " >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git log -1 --format="%H %ci %an: %s" >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git branch -f master
	cd ..
fi

cd zstack-utility
git clean -xdf
tar cfp ../zstack-utility.tar .
echo -n "zstack-utility: " >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
git log -1 --format="%H %ci %an: %s" >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
git branch -f master
cd ..

if [ -d mevoco-ui ]; then
	cd mevoco-ui
	echo -n "mevoco-ui: " >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git log -1 --format="%H %ci %an: %s" >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git branch -f master
	cd ..
fi

if [ -d zstack-dashboard ]; then
	cd zstack-dashboard
	echo -n "zstack-dashboard: " >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git log -1 --format="%H %ci %an: %s" >> ../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git branch -f master
	cd ..
fi


if [ -d zstack/premium ]; then
	cd zstack/premium
	echo -n "premium: " >> ../../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git log -1 --format="%H %ci %an: %s" >> ../../${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt
	git branch -f master
	cd ../..
fi

CHECKSUM=`md5sum ${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt | awk '{print $1}'`
OLD_CHECKSUM=`md5sum versions.txt | awk '{print $1}'`
if [ "${CHECKSUM}" == "${OLD_CHECKSUM}" ]; then
	echo Already build before
	exit 127
fi
scp versions.txt versions.txt.old || echo ignore failure
scp ${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt versions.txt

cp ${JENKINS_HOME}/apache-tomcat-7.0.35.zip .
cd zstack
#mvn -DskipTests clean install
cd ..
cp ${JENKINS_HOME}/apache-cassandra-2.2.3-bin.tar.gz .
cp ${JENKINS_HOME}/kairosdb-1.1.1-1.tar.gz .
cd zstack-utility/zstackbuild
cp ${JENKINS_HOME}/centos7_repo.tar .
tar xf centos7_repo.tar
rm -rf centos7_repo.tar
export GOROOT=/usr/lib/golang
ORIGINAL_PRODUCT_VERSION=`cat build.properties|grep product.version|awk -F '=' '{print $2}'`
TIME_STAMP=`date +"%y%m%d"`
#ant -Dzstack_build_root=${WORKSPACE} -Dzstackdashboard.build_version=master offline-centos7
if [ "${BUILD_TYPE}" == "mevoco_ci" -o "${BUILD_TYPE}" == "mevoco_ui_dev" ]; then
	if [ "${BUILD_TYPE}" == "mevoco_ui_dev" ]; then
		ORIGINAL_PRODUCT_VERSION="mevoco-ui-dev"
	fi
	ant -Dzstack_build_root=${WORKSPACE} -Dbuild_war_flag=premium -Dproduct.version=${ORIGINAL_PRODUCT_VERSION}-${TIME_STAMP}-${BUILD_NUMBER} -Dzstackdashboard.build_version=master -Dproduct.name=MEVOCO -Dproduct.bin.name=mevoco-installer all-in-one
elif [ "${BUILD_TYPE}" == "zstack_ci" -o "${BUILD_TYPE}" == "zstack_1.1_ci" ]; then
	ant -Dzstack_build_root=${WORKSPACE} -Dproduct.version=${ORIGINAL_PRODUCT_VERSION}-${TIME_STAMP}-${BUILD_NUMBER} all-in-one
fi
cd ../../
BIN_NAME=$(basename `ls zstack-utility/zstackbuild/target/*.bin`)
cp zstack-utility/zstackbuild/target/*.bin ${BUILD_TYPE}/${BUILD_NUMBER}/

echo "<html>" > ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "<head>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "<title>${BUILD_TYPE} ${ORIGINAL_PRODUCT_VERSION}-${TIME_STAMP}-${BUILD_NUMBER}</title" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "<body>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "<table border=1>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "<tr>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "    <th>${BUILD_TYPE}</th>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "    <th><a href=${BIN_NAME}>${BIN_NAME}</a></th>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "    <th></th>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "</tr>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html

for i in $(seq `wc -l ${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt|awk '{print $1}'`); do
	COMPONENT=`sed -n "${i}p" ${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt | awk '{print $1}'`
	COMMIT=`sed -n "${i}p" ${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt | awk '{print $2}'`
	SUBJECT=`sed -n "${i}p" ${BUILD_TYPE}/${BUILD_NUMBER}/versions.txt | awk '{for (i=3; i<NF; i++) printf("%s ",$i);print $i}'`
	echo "<tr>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
	echo "    <td>${COMPONENT}</td>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
	echo "    <td>${COMMIT}</td>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
	echo "    <td>${SUBJECT}</td>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
	echo "</tr>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
done
echo "</table>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "</body>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html
echo "</html>" >> ${BUILD_TYPE}/${BUILD_NUMBER}/index.html

rm -rf ${BUILD_TYPE}/latest
ln -s ${BUILD_NUMBER} ${BUILD_TYPE}/latest
if [ "${BUILD_TYPE}" == "mevoco_ci" -o "${BUILD_TYPE}" == "mevoco_ui_dev" ]; then
	ln -s ${BIN_NAME} ${BUILD_TYPE}/latest/mevoco-installer.bin
elif [ "${BUILD_TYPE}" == "zstack_ci" ]; then
	ln -s ${BIN_NAME} ${BUILD_TYPE}/latest/zstack-installer.bin
fi
rsync -avz --copy-links ${BUILD_TYPE}/ root@192.168.200.1:/httpd/${BUILD_TYPE}
