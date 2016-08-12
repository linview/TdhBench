#!/bin/bash
# set -vx
# Create DB for TDH benchmark - Copyright 2016, Transwarp
# $1 = profile path

cd $(dirname $0)

if [ ! -f $1 ]; then
  echo -e "ERROR: invalid profile $1, profile must be specified, exit 1";
  exit 1;
fi
profileFile="$1"
source $profileFile

[ -e ../ENV.sh ] && source ../ENV.sh
[ -e ../TdhBench.Current.Server ] && source ../TdhBench.Current.Server

function runJob {
# $1: yml file path
# $2: conf file path
  [ -e $1 ] && ymlFile=$1
  [ -e $2 ] && confFile=$2

  playerOpt=""
  playerJar="player-1.0-all.jar"
  [ "${TdhBenchHiveServer}" = "hive2" ] && playerOpt="$playerOpt -m"
  [ -n "${TdhBenchKbsPrincipal}" ] && playerOpt="$playerOpt -k"
  java -cp ${TdhBenchPlayerPath}/${playerJar} io.transwarp.qa.player.SuiteRunner ${playerOpt} -t $ymlFile -C $confFile # | tee ${HOMEDIR}/${TdhBenchCurrentServer}_logs/sanity_$$.log
}

logFile=${HOMEDIR}/logs/${TdhBenchCurrentServer}.log

BOLD='\033[1m' && CYAN='\033[01;36m' && NONE='\033[00m' && UNDERLINE='\033[4m' && GREEN='\033[01;32m' && RED='\033[01;31m'

# create basic case
bash $TOOLDIR/genSQL.sh -s "CREATE DATABASE IF NOT EXISTS $TdhBenchDb;" -p ${HOMEDIR}/${TdhBenchCurrentServer}_logs/ddl -o createDB_${TdhBenchDb}.sql
bash $TOOLDIR/genCONF.sh $profileFile ${HOMEDIR}/${TdhBenchCurrentServer}_logs
bash $TOOLDIR/genYML.sh -t sql -s ddl -d "Create DB" -o ../${TdhBenchCurrentServer}_logs/${TdhBenchDb}.yml -mode cluster
runJob ${HOMEDIR}/${TdhBenchCurrentServer}_logs/${TdhBenchDb}.yml ${HOMEDIR}/${TdhBenchCurrentServer}_logs/conf.xml  > ../${TdhBenchCurrentServer}_logs/createDB_${TdhBenchDb}.log

cd - 1>/dev/null
# create run.yml


