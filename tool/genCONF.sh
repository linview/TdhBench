#!/bin/bash

# $1 = profileFile
# $2 = out path : default in ${HOMEDIR}/${TdhBenchCurrentServer}_logs/conf.xml

#echo "PWD=$PWD, bsename=$(basename $0), dirname=$(dirname $0)"
cd $(dirname $0)
[ -e ../ENV.sh ] && source ../ENV.sh

profileFile=$1
outPath=$2

if [ ! -e $profileFile ]; then
  source ../TdhBench.Current.Server
  profileFile="../${TdhBenchCurrentProfile}.profile"
fi
source $profileFile

if [ ! -d $outPath ]; then
  outPath=${HOMEDIR}/${TdhBenchCurrentServer}_log
fi

echo -e "
<!-- Test Framework Configuration XML file -->

<configuration>
  <property>
    <name>hdfs.uri</name>
    <value>hdfs://localhost:8020</value>
  </property>
  <property>
    <name>inceptor.server</name>
    <value>$TdhBenchInceptorServerIp</value>
  </property>
  <property>
    <name>inceptor.metastore</name>
    <value>$TdhBenchMetastoreIp</value>
  </property>
  <property>
    <name>ldap.user</name>
    <value>$TdhBenchLdapUser</value>
  </property>
  <property>
    <name>ldap.password</name>
    <value>$TdhBenchLdapPasswd</value>
  </property>
  <property>
    <name>kerberos.principal</name>
    <value>$TdhBenchKbsPrincipal</value>
  </property>
</configuration>
" > $outPath/conf.xml

cd - 1>/dev/null

