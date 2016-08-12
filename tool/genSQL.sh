#!/bin/bash

#echo "PWD=$PWD, bsename=$(basename $0), dirname=$(dirname $0)"
cd $(dirname $0)
[ -e ../ENV.sh ] && source ../ENV.sh
[ -e ../TdhBench.Current.Server ] && source ../TdhBench.Current.Server

function helpMsg {
echo -e "
# Usage: genSQL.sh -s <sql> -o <file> -p <path> -a
# -s : sql clause
# -o : out file
# -p : out path
# -a : append mode to out file, default is rewrite sql file
"
}

sql=""
outFile=""
outPath=""
appendMode=0

while [ $# -gt 0 ]; do
  case $1 in
    "-s")
      sql=$2; shift 2
    ;;
    "-o")
      outFile=$2; shift 2
    ;;
    "-p")
      outPath=$2; shift 2
    ;;
    "-a")
      appendMode=1; shift
    ;;
    "-h")
      helpMsg; exit 0
    ;;
    *)
      echo "Internal Error, exit 1"; exit 1
    ;;
  esac
done

if [[ -z $sql || -z $outFile || -z $outPath ]]; then
  echo "Sql, outPath and outFile must be specified: sql=\"$sql\", outPath=$outPath, outFile=$outFile"
  exit 1;
fi

[ ! -e ${outPath} ] && mkdir -p $outPath
echo "$sql" > ${outPath}/${outFile}
[ -e ${outPath}/${outFile} -a $appendMode -eq 1 ] && echo "$sql" >> $outPath/$outFile

cd - 1>/dev/null