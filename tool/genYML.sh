#!/bin/bash

#echo "PWD=$PWD, bsename=$(basename $0), dirname=$(dirname $0)"
cd $(dirname $0)
[ -e ../ENV.sh ] && source ../ENV.sh
[ -e ../TdhBench.Current.Server ] && source ../TdhBench.Current.Server

function helpMsg {
echo -e "
# Usage : genYML.sh -t <actionType> -s <source> -d <desc> -o <outfile> -a [-verif|-db <sql:dbname> |-ref <sql:ref_path>|-mode <sql:mode>|-conf <sql:conf>]
#   -t action type: [sql|shell]
#   -s source: dir or script with args
#   -d desc: action's description
#   -o outfile: output file path
#   -a append mode enabled
#   action type:
#     > sql
#       -verif : enable gen result file & verify
#       -db : database name
#       -ref : ref_path
#       -mode : cluster|local
#       -conf : conf path
"
}

actionType=""
source=""
desc=""
outFile=""
appendMode=0
sql_verif=0
sql_db=""
sql_ref=""
sql_mode=""
sql_conf=""

while [ $# -gt 0 ]; do
  case "$1" in
    "-t")
      actionType=$2; shift 2
    ;;
    "-s")
      source=$2; shift 2
    ;;
    "-d")
      desc=$2; shift 2
    ;;
    "-o")
      outFile=$2; shift 2
    ;;
    "-a")
      appendMode=1; shift
    ;;
    "-verif")
      sql_verif=1; shift
    ;;
    "-db")
      sql_db=$2; shift 2
    ;;
    "-ref")
      sql_ref=$2; shift 2
    ;;
    "-mode")
      sql_mode=$2; shift 2
    ;;
    "-conf")
      sql_conf=$2; shift 2
    ;;
    "-h")
      helpMsg; exit 0
    ;;
    *)
      echo "Internal Error, exit 1"; exit 1
    ;;
  esac
done

#defaultPath=${HOMEDIR}/${TdhBenchCurrentServer}_logs

#if [ ! -e $defaultPath ]; then
#  echo -e "ERROR: $defaultPath not exists, please set up first"
#  exit 1
#fi
#targetFile=${defaultPath}/${outFile}

targetFile=${outFile}

targtContent=""
[ $appendMode -eq 0 ] && echo "actions:" > $targetFile

if [ $actionType == "sql" ]; then echo
  echo -e "
  - desc: $desc
    action: sql
    args:
      src: $source" >> $targetFile

if [ -n "$sql_mode" ]; then
  echo -e \
"      mode: $sql_mode" >> $targetFile
fi

if [ -n "$sql_db" ]; then
  echo -e \
"      database: $sql_db" >> $targetFile
fi

if [ -n "$sql_conf" ]; then
  echo -e \
"      conf: $sql_conf" >> $targetFile
fi

if [ $sql_verif -eq 1 ]; then
  echo -e \
"      genResultFile: 'true'
      verify: 'true'" >> $targetFile
fi

if [ -n "$sql_ref" ]; then
  echo -e \
"      reference: $sql_ref" >> $targetFile
fi
fi

if [ $actionType == "shell" ]; then
  echo -e "
  - desc: $desc
    action: shell
    args:
      cmd: $source" >> $targetFile
fi

cd - 1>/dev/null
