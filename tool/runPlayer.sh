#!/bin/bash

#echo "PWD=$PWD, bsename=$(basename $0), dirname=$(dirname $0)"
cd $(dirname $0)
[ -e ../ENV.sh ] && source ../ENV.sh
[ -e ../TdhBench.Current.Server ] && source ../TdhBench.Current.Server
[ -e ../${TdhBenchCurrentProfile}.profile ] && source ../${TdhBenchCurrentProfile}.profile

function helpMsg
{
echo -e "
# Usage: runPlayer.sh -a <action list> -p <pilotname>
#  -a : action list, 1~n action names
#  -p : pilot name
"
}

actList=""
findAction=0
pilot=""
playerJar="player-1.0-all.jar"
playerOpt=""


[ "${TdhBenchHiveServer}" = "hive2" ] && playerOpt="$playerOpt -m"
[ -n "${TdhBenchKbsPrincipal}" ] && playerOpt="$playerOpt -k"

while [ $# -gt 0 ]; do
  case "$1" in
    "-a")
      actList="$2";
      findAction=1;
      shift 2
    ;;
    "-p")
      pilot=$2;
      findAction=0;
      shift 2
    ;;
    *)
      if [ $findAction -eq 1 ]; then
        actList="$actList $1"
        shift
      else
        echo -e "ERROR: insufficient args or wrong usage"
        helpMsg
      fi
    ;;
  esac
done
echo -e "INFO : running pilot=$pilot, actions=${actList[*]}, PID=$$"

if [ -n "$pilot" -a -f ../temp/pids.txt ]; then
  echo "pilot ${pilot} $$" >> ../temp/pids.txt
fi

if [ ${#actList} -lt 1 ]; then echo -e "ERROR: action list is empty"; exit 1; fi
for action in ${actList[*]}; do
  if [ -e ../temp/${action}.act ]; then refinedList=($refinedList $action)
  else echo "WARNING: action file ${action}.act not found in temp dir";
  fi
done
set -f

for action in ${refinedList[*]} ; do
  echo "action ${action} $$" >> ../temp/pids.txt
  logFile="../${TdhBenchCurrentServer}_logs/${pilot}-${action}-$$.log"
  ms=`date +"%N"`
  startTime=${SECONDS}.${ms:0:3}
  eval "java -cp ${TdhBenchPlayerPath}/${playerJar} io.transwarp.qa.player.SuiteRunner ${playerOpt} -t ../temp/${action}.yml -C ../${TdhBenchCurrentServer}_logs/conf.xml" >> $logFile 2>&1
  rc=$?
  ms=`date +"%N"`
  endTime=${SECONDS}.${ms:0:3}
  duration=$(awk "BEGIN{print $endTime - $startTime}")
  result=$(tail -1 $logFile)                # get last line as summary
  # write $pilot report file
  echo "${pilot}-${action}-$$ | ${result/*Total/} | DURATION:${duration}s" >> ../${TdhBenchCurrentServer}_logs/${pilot}.rpt


  if [ $rc != 0 ]; then
    echo "${pilot}-${action}-$$ FAILED" >> ../temp/pids_done.txt
  else
    echo "${pilot}-${action}-$$ FINISHED" >> ../temp/pids_done.txt
  fi

  # clean action pid
  sed -i "/action ${action} $$/d" ../temp/pids.txt
done

  # clean pilot pid
set -f
sed -i "/pilot ${pilot/\*/\\*} $$/d" ../temp/pids.txt

cd - 1>/dev/null
