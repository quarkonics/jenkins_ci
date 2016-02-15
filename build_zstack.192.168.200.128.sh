#!/bin/bash
# build ZStack binary 
ZSTACK_TEST_ROOT=${ZSTACK_TEST_ROOT-'/usr/local/zstack'}
PULL_ZSTACK="N"
PULL_ZSTACK_UTILITY="N"
PULL_ZSTACK_WOODPECKER="N"
PULL_ZSTACK_DASHBOARD="N"

help (){
    echo "Usage: $0 [options]

    Default option is -a
Options:
  -a            equal to -zuw
  -h            show this help message and exit
  -r            set zstack 'root' path, default is '/root'
  -u            pull zstack-utility
  -w            pull zstack-woodpecker
  -z            pull zstack 
"
    exit 1
}

PULL_FLAG='N'

OPTIND=1
while getopts "r:i:azuwh" Option
do
    case $Option in
        a ) PULL_ZSTACK='Y' && PULL_ZSTACK_UTILITY='Y' && PULL_ZSTACK_WOODPECKER='Y' && PULL_ZSTACK_DASHBOARD='Y'
            ;;
        z ) PULL_ZSTACK='Y' && PULL_FLAG='Y' ;;
        u ) PULL_ZSTACK_UTILITY=='Y' && PULL_FLAG='Y' ;;
        w ) PULL_ZSTACK_WOODPECKER='Y' && PULL_FLAG='Y' ;;
        r ) ZSTACK_TEST_ROOT=$OPTARG;;
        i) ;;
        h ) help;;
        * ) help;;
    esac
done
OPTIND=1
[ $PULL_FLAG == 'N' ] && PULL_ZSTACK='Y' && PULL_ZSTACK_UTILITY='Y' && PULL_ZSTACK_WOODPECKER='Y' && PULL_ZSTACK_DASHBOARD='Y'

ZSTACK_FOLDER=$ZSTACK_TEST_ROOT/zstack
ZSTACK_UTILITY=$ZSTACK_TEST_ROOT/zstack-utility
ZSTACK_WOODPECKER=$ZSTACK_TEST_ROOT/zstack-woodpecker
ZSTACK_DASHBOARD=$ZSTACK_TEST_ROOT/zstack-dashboard
ZSTACK_BUILD=$ZSTACK_UTILITY/zstackbuild
ZSTACK_ARCHIVE=$ZSTACK_TEST_ROOT/zstack_build_archive
#zstack_build_archive="install.sh zstack-all-in-one-*.tgz woodpecker/zstacktestagent.tar.bz  woodpecker/conf/zstack.properties"
zstack_build_archive="*-installer*.bin woodpecker/zstacktestagent.tar.bz  woodpecker/conf/zstack.properties"
tab='  '

echo -e "\n - Build zstack.war and all test required packages. -"

echo_failure(){
    echo -e "$(tput setaf 1)${tab} ... ... $1\n$(tput sgr0)"
    exit 1
}

echo_pass(){
    echo -e "$(tput setaf 2)${tab} ... ... Success\n$(tput sgr0)"
}

install_pkg(){
    which $1 &>/dev/null
    if [ $? -ne 0 ];then 
        which yum &>/dev/null
        if [ $? -eq 0 ];then
            yum install -y $1
        else
            which apt-get && apt-get install -y $1
        fi
    fi
}

install_pkg git
install_pkg bzip2
install_pkg bc


echo "${tab} : Build zstack all in one package"
#cd $ZSTACK_BUILD
mkdir -p /tmp/zstack/

which ant

[ $? -ne 0 ] && which yum && yum install -y ant && yum install -y java-1.7.0-openjdk-devel && yum install -y maven

[ $? -ne 0 ] && which apt-get && apt-get install -y ant && apt-get install -y maven

mkdir -p ${ZSTACK_ARCHIVE}
rm -f ${ZSTACK_ARCHIVE}/latest
ln -s /home/192.168.200.128/zstack-all-in-one.tar ${ZSTACK_ARCHIVE}/latest
echo -e "$(tput setaf 2)\n - Build zstack successfully and saved as $zstack_archive_file - \n$(tput sgr0)"
