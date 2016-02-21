TEST_TARGET=$1
OVERALL_BUILD_NUMBER=$2
TARGET_BIN=$3
cp ${TARGET_BIN} .
rm -rf zstack zstack-utility zstack-dashboard ${TEST_TARGET} zstack-woodpecker
mkdir -p ${TEST_TARGET}/${OVERALL_BUILD_NUMBER}
mkdir -p zstack
tar -x -C zstack -f zstack.tar
rm -rf zstack.tar
cd zstack
echo -n "zstack: " > ../${TEST_TARGET}/${OVERALL_BUILD_NUMBER}/versions.txt
git log -1 --format="%H %an: %s" >> ../${TEST_TARGET}/${OVERALL_BUILD_NUMBER}/versions.txt
git branch -f master
cd ..
mkdir -p zstack-utility
tar -x -C zstack-utility -f zstack-utility.tar
#rm -rf zstack-utility.tar
cd zstack-utility
echo -n "zstack-utility: " >> ../${TEST_TARGET}/${OVERALL_BUILD_NUMBER}/versions.txt
git log -1 --format="%H %an: %s" >> ../${TEST_TARGET}/${OVERALL_BUILD_NUMBER}/versions.txt
git branch -f master
cd ..
mkdir -p zstack-woodpecker
tar -x -C zstack-woodpecker -f zstack-woodpecker.tar
#rm -rf zstack-woodpecker.tar
cd zstack-woodpecker
echo -n "zstack-woodpecker: " >> ../${TEST_TARGET}/${OVERALL_BUILD_NUMBER}/versions.txt
git log -1 --format="%H %an: %s" >> ../${TEST_TARGET}/${OVERALL_BUILD_NUMBER}/versions.txt
git branch -f master
cd ..
cp ${JENKINS_HOME}/apache-tomcat-7.0.35.zip apache-tomcat-7.0.35.zip
cd zstack
#mvn -DskipTests clean install
cd ../zstack-utility/zstackbuild

#ant -Dzstack_build_root=${WORKSPACE} -Dzstackdashboard.build_version=master -Dproduct.version=qa all-in-one 
ant build-testconf -Dzstack_build_root=${WORKSPACE}
ant buildtestagent -Dzstack_build_root=${WORKSPACE}

cp -r target/woodpecker/ woodpecker/
#tar cf zstac-all-in-one.tar woodpecker/zstacktestagent.tar.bz woodpecker/conf/zstack.properties ../../zstack-all-in-one.tgz ../../install.sh 
cp ../../${TARGET_BIN} .
tar cf zstack-all-in-one.tar woodpecker/zstacktestagent.tar.bz woodpecker/conf/zstack.properties `basename ${TARGET_BIN}`
