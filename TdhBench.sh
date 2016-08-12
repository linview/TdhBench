#!/bin/bash

BOLD='\033[1m' && CYAN='\033[01;36m' && NONE='\033[00m' && UNDERLINE='\033[4m' && GREEN='\033[01;32m' && RED='\033[01;31m'

export HOMEDIR=$PWD
export TEMPDIR=temp
export LOGDIR=$HOMEDIR/logs
export TOOLDIR=$HOMEDIR/tool

echo HOMEDIR=$HOMEDIR > ENV.sh
echo TEMPDIR=$TEMPDIR >> ENV.sh
echo LOGDIR=$LOGDIR >> ENV.sh
echo TOOLDIR=$TOOLDIR >> ENV.sh

[ -e ./TdhBench.Current.Server ] && source ./TdhBench.Current.Server
[ -e ./${TdhBenchCurrentProfile}.profile ] && source ./${TdhBenchCurrentProfile}.profile


# debug settings
TDHBENCHTRACE="OFF"
TDHBENCHTRACELEVEL=3
STOPRUN=""

# Global variables
ReturnCode=0
haddefine="n"
debug_level=1

function fHadCtrlc     # ---------------- fHadCtrlc ---------------------
{
  trap - INT               # if user hits ctrl-c while this runs, we are done
  fTrace 1 Ctrl-C trapped in TdhBench.sh - ignored
  fLog warning Ctrl-C intercepted in TdhBench while processing commands - ignored
  trap fHadCtrlc INT
}

function fTrace     # ---------------------- fTrace -------------------------
{
local lvl hhmmss
lvl=$1
shift 1
if [ "$TDHBENCHTRACE" = "ON" -a $lvl -le $TDHBENCHTRACELEVEL ]; then
  hhmmss=$(date +%H:%M:%S.%N);echo ${hhmmss:0:12} "$*" >> $TEMPDIR/tdhbench.trace
  if [ "$TDHBENCHTRACEQUIET" != "QUIET" ]; then echo $(date +%H:%M:%S.%N) "$*"; fi
fi
}

function fLog     # --------------------- fLog -------------------------
{
  LOGLINENO=$(( $LOGLINENO+1 ))

  local verbose=0
  if [ $1 = "-v" -a $debug_level -gt 2 ]; then
    verbose=1
    shift
  fi

  local LOGTYPE=$1
  shift 1
  local D=`date +"%Y-%m-%d %H:%M:%S.%N"`

  [ ! -e $HOMEDIR/$TEMPDIR/tdhbenchrun.log ] && touch $HOMEDIR/$TEMPDIR/tdhbenchrun.log
  echo ${LOGLINENO}\|${SECONDS}\|${D:0:23}\|${LOGTYPE}\|"$*" >> $HOMEDIR/$TEMPDIR/tdhbenchrun.log
  if [ $verbose -eq 1 ]; then
    echo ${D:0:23} ${LOGTYPE} "$*" | tee -a $HOMEDIR/TdhBench.log
  else
    echo ${D:0:23} ${LOGTYPE} "$*" >> $HOMEDIR/TdhBench.log
  fi

  case $(echo "$LOGTYPE" | tr A-Z a-z) in
    "input:")
      :
      ;;
    "log")
      :
      ;;
    "error")
      echo -e ${RED}ERROR${NONE} "$*"
      ;;
    "warning")
      echo -e ${BOLD}WARNING${NONE} "$*"
      ;;
    "info")
      echo ..... "$*"
      ;;
    "note")
      echo "$*"
      ;;
    "runcount")
      echo -e "${BOLD}Queries submitted for execution:${NONE} $1    (RUNCOUNT)"
      ;;
    "runerrors")
      if [ $1 -gt 0 ]; then
        echo -e "${RED}Count of queries with errors: $1${NONE}    (RUNERRORS)"
      else
        echo -e "Count of queries with errors: $1    (RUNERRORS)"
        fi
      ;;
    "runseconds")
      echo -e "${BOLD}Total seconds of run execution:${NONE} $1    (RUNSECONDS)"
      ;;
    *)
      echo -e ${RED}$LOGTYPE $*${NONE} ... unrecognized fLog type
      ;;
   esac
}

function cmdCLEAN
{
# Usage : clean all the pilot/action pids in pids.txt
  if [ -f ${TEMPDIR}/pids.txt ]; then
    cat ${TEMPDIR}/pids.txt | while read type name pid; do
      if [ "$pid" != $$ -a -n "$pid" ]; then
         fKill $pid
         echo "$type-$name-$pid KILLED" > ${TEMPDIR}/pids_done.txt
      fi
    done
  fi

  fLog -v INFO "Checking other TdhBench related process \(QA-Player etc\)"
  ps -a -o pid,args --noheader | grep "qa\.player" | while read pid cmdline; do
    [ "${cmdline:0:4}" != "grep" ] && echo "kill $pid \# command: $cmdline"
  done

  echo $*
}

function fKill  # ----------------------- fKill ------------------------------
{
# This recursive routine is passed a single PID. It will look for the children of the PID
# and for each found, call itself.  When there are no children, it will kill the pid it was
# passed.

  local Child Children pid cmd
  Children=$( ps --ppid $1 -o pid --noheader )
  for Child in $Children; do fKill $Child $2; done
  ps -p $1 -o pid,cmd --noheader | while read pid cmd; do
    kill $pid
    rc=$?
    if [ $rc != 0 ]; then echo Error killing $pid - rc=$rc - cmd:$cmd; fi
    if [ "$2" != "quiet" ]; then
        echo killed pid: $pid Command:$cmd
        fi
    fTrace 1 main fKill killed pid: $pid Command:$cmd
    done

}

function cmdOS
{
  local EXECRC
  set +f      # NOTE, TURNING ON FILE EXPANSION FOR THE USER, WILL TURN OFF BEFORE RETURNING
  if [ "$1" = "" ]; then
    echo ------------- interactive shell entered. Type exit to return to TdhBench.sh ----------
    bash
  else
    eval "$*"
  fi
  EXECRC=$?
  if [ $EXECRC -eq 127 ]; then fLog ERROR "Above cmd \"$1\" was not a TdhBench command or valid linux command"
  elif [ $EXECRC != 0 ]; then fLog ERROR "Above command \"$1\" ended with rc=$EXECRC"; fi
  set -f     # file expansion turned back off
}

function cmdRUN
{
  local currentJob=$(cat $HOMEDIR/$TEMPDIR/currentJob)
  local jobFile=${HOMEDIR}/${TEMPDIR}/${currentJob}.job
  local pilot

  [ -f ${TEMPDIR}/pids_done.txt ] && rm -rf ${TEMPDIR}/pids_done.txt

  if [ $# -eq 0 -a -e $jobFile ]; then
    grep -i "PILOT" $jobFile > $TEMPDIR/run.list
    set -f
    while read LINE; do
      local tokens=(`echo $LINE`)
      dbg INFO "Type: ${tokens[0]}, name: ${tokens[1]}"
      [ "${tokens[0]}" = "PILOT" ] && runPilot ${tokens[1]}
      unset tokens
    done < $TEMPDIR/run.list
  elif [ $# -gt 0 ]; then
    for pilot in $@; do
      echo "PILOT $pilot" > $TEMPDIR/run.list
      dbg INFO "run pilot: $pilot"
      runPilot $pilot &
    done
  else
    fLog -v ERROR "$0: Job file ${currentJob}.job not found or corrupted!"
    return;
  fi
}

function runPilot
{
# $1 : .plt file name
  local pltFile="${TEMPDIR}/${1}.plt"
  local threadNum=1
  local actList=""

  if [ ! -e $pltFile ]; then fLog -v WARNING "$0 : pilot file $pltFile not exists"; return; fi
  while read LINE; do
    local tokens=(`echo $LINE`)
    if [ "${tokens[0]}" = "THREADNUM" ]; then threadNum=${tokens[1]}; fLog INFO "PILOT \"$1\" have $threadNum threads"; fi
    if [ "${tokens[0]}" = "ACTION" ]; then actList="$actList ${tokens[1]}"; fLog INFO "PILOT \"$1\" +ACTION \"${tokens[1]}\""; fi
    unset tokens
  done < $pltFile

  local rptFile=${HOMEDIR}/${TdhBenchCurrentServer}_logs/${1}.rpt
  local ms=`date +"%N"`
  local duration=${SECONDS}.${ms:0:3}
  if [ -d ${HOMEDIR}/${TdhBenchCurrentServer}_logs ]; then
    echo ">>> Run Summary of pilot ${1} " > $rptFile
    echo "START TIME: `date +"%T"`" >> $rptFile
  else
    fLog WARNING "Dir ${HOMEDIR}/${TdhBenchCurrentServer}_logs not exists, no report will be generated."
  fi

  dbg INFO "Run Pilot $1, threadNu $threadNum, actions=${actList[*]}"
  for (( i=0; i<$threadNum; i++ )); do
  {
    bash $TOOLDIR/runPlayer.sh -p ${1} -a ${actList[*]}
  } &
  done
  wait              # there is risk to hang here, need a way to detect & kill long-run thread
  fLog INFO "Pilot ${1} finished, report file is $rptFile"

  if [ -d ${HOMEDIR}/${TdhBenchCurrentServer}_logs ]; then
    ms=`date +"%N"`
    duration=$(awk "BEGIN{print ${SECONDS}.${ms:0:3} - $duration}")
    echo -e "END TIME: `date +"%T"`" >> $rptFile
    local passNum=`grep -i -e "Failed:0" $rptFile | wc -l`
    local failNum=`grep -i -e "Failed:[^0]" $rptFile | wc -l`
    local errorNum=$(( $(cat $rptFile | wc -l) - $(grep -i -e "\(Run Summary\|START\|END\|Actions\)" $rptFile | wc -l) ))
    printf "Total | PASSED: $passNum\t FAILED:$failNum\t ERROR:$errorNum | DURATION: $duration s\n" >> $rptFile
  fi
}


function cmdACTION
{
# Usage : ACTION field_$1 field_$2
# $1 = ACTION name
# $2 = [SQL_DIR/*.sql|"SQL_CLAUSE"|.act file]
# $3 = [repeat time|param list]. NOT support yet
  local actionContent=$*

  local inquote="n"               # in a quote ""
  local quotefind="\""
  local inparen="n"               # in a paren pairs ()
  local logicalparm=0             # field indicator
  local repeatcnt=0
  local actionname sqlstr sqlsearch filelist parmstr allsql
  unset actionname sqlstr sqlsearch filelist parmstr allsql

  if [ $haddefine = "n" ]; then fLog WARNING "Job must be DEFINEd before declaring an ACTION. NO ACTION recorded..."; return;  fi
  while [ $# -gt 0 ]; do
    if [ "${1:0:1}" = "$quotefind" -a $inquote = "n" ]; then
      inquote="y"
      sqlstr="${1:1}"
      shift
      if [ "${sqlstr: -1:1}" = "$quotefind" ]; then inquote="n"; sqlstr="${sqlstr/$quotefind/}"; fi
      while [ $inquote = "y" -a $# -gt 0 ]; do
        if [ "${1: -1:1}" = "$quotefind" ]; then inquote="n"; sqlstr="${sqlstr} ${1/$quotefind/}";
        else sqlstr="$sqlstr $1";
        fi
        shift
      done
      if [ $# -eq 0 -a $inquote = "y" ]; then
        dbg INFO "\$#=$#, $\*=$*, \$inquote=$inquote"
        fLog -v WARNING "quote pair not match in ACTION clause: \"ACTION $actionContent\""
        return
      fi
      logicalparm=$(( $logicalparm + 1 ))
    elif [ "${1:0:1}" = "(" -a $inparen = "n" ]; then
      inparen="y"
      parmstr="${1:1}"
      shift
      if [ "${parmstr: -1:1}" = ")" ]; then
        inparen="n"
        parmstr="${parmstr/)/}"
      else
        while [ $inparen = "y" -a $# -gt 0 ]; do
          if [ "${1: -1:1}" = ")" ]; then inparen="n"; parmstr="$parmstr ${1/)/}"
          else parmstr="$parmstr $1"
          fi
          shift
        done
      fi
      logicalparm=$(( $logicalparm + 1 ))
    elif [ "${1:0:1}" = "(" -a $inparen = "y" ]; then
      fLog -v WARNING "parenthesis pair not match in ACTION clause: \"ACTION $actionContent\""
      return
    else
      logicalparm=$(( $logicalparm + 1 ))
      set -f
      if [ $logicalparm -eq 1 ]; then actionname=$1
      elif [ $logicalparm -eq 2 ]; then sqlsearch=$1     # input is sql file dir
      elif [ $logicalparm -eq 3 ]; then repeatcnt=$1
      else
        fLog ERROR "logical parameter $logicalparm \"$1\" not understood"
        return
      fi
    fi
    shift
  done

  if [ $logicalparm -lt 2 ]; then fLog -v ERROR "Insufficient param list."; return; fi
  dbg INFO "$LINENO : actionname=$actionname, sqlstr=$sqlstr, parmstr=$parmstr, sqlsearch=$sqlsearch, repeatcnt=$repeatcnt"

# ------------------------------- Prepare Parameters --------------------------------------------------
  x=$(echo $actionname | tr A-Z a-z)
  if [ "$actionname" != "$x" ]; then fLog NOTE "transfer ACTION $actionname into $x"; actionname=$x; fi

  if [ -n "$sqlsearch" ]; then
    if [ ${sqlsearch:0:1} != "/" ]; then sqlsearch=${PWD}/${sqlsearch} ; fi
    local searchdir=""
    local searchfiles=""
    if [ -d $sqlsearch ]; then
      filelist=$sqlsearch
    else
      searchdir=$(dirname $sqlsearch | uniq);
      searchfiles=${sqlsearch:$((${#searchdir}+1))};
      dbg INFO "$LINENO : sqlsearch=$sqlsearch, searchDIR=$searchdir, searchFILE=$searchfiles"
      if [ -d $searchdir ];then
        set +f
        read -a filelist <<< $(ls $searchdir/$searchfiles)
        set -f
      else
        fLog -v ERROR "Search dir \"$searchdir\" not exists";
        return;
      fi
      if [ ${#filelist[*]} -eq 0 ];then
        fLog -v ERROR "Can't find target files in \"$searchdir\" with pattern \"$searchfiles\"";
        return;
      fi

      local allsql="true"               # assume the files are all sql, then check
      for (( i=0; i<${#filelist[@]}; i++ ))
       do
        local testStr=${filelist[$i]};
        dbg INFO "$0 : testStr=$testStr, line = $i / ${#filelist[@]}"
        if [ "${testStr/.sql/}" = "${testStr}" ]; then
          allsql="false"
          break
        fi
      done
    fi
    dbg INFO "sqlsearch=$sqlsearch, searchdir=$searchdir, searchfiles=$searchfiles; filelist=${filelist[*]}, allsql=$allsql"
  fi

  if [ -n "$(echo $repeatcnt | tr -d 0-9)" ];  then fLog ERROR repeat count was not numeric; return; fi

# -------------------------- Creating act file for single ACTION -----------------------------
  local actFile="${TEMPDIR}/${actionname}.act"
  local actLine lineNo actType conType
# act file format :
# [line#] [action_type] [content_type] [content]
  if [ ! -e $actFile ]; then touch $actFile; fi

  lineNo=`cat $actFile | wc -l`;
  dbg INFO "$LINENO : sqlstr=$sqlstr"
  if [ -n "$sqlstr" -a "${sqlstr//';'/}" != "$sqlstr" ]; then              # sql caluse
    actType="sql"
    conType="query"
    actLine=`printf "$lineNo\t$actType\t$conType\t\"$sqlstr\""`
    if [ $repeatcnt -gt 0 ]; then actLine="$actLine $repeatcnt";fi
  elif [ -n "$sqlstr" -a "${sqlstr//';'/}" = "$sqlstr" ]; then              # sql file list
    actType="sql"
    conType="files"
    actLine=`printf "$lineNo\t$actType\t$conType\t\"${sqlstr//' '/,}\""`
  elif [ -d ${filelist} ]; then
    actType="sql"
    conType="dir"
    actLine=`printf "$lineNo\t$actType\t$conType\t$filelist"`;
  elif [ ${#filelist[*]} -gt 0 -a $allsql = "true" ]; then
    actType="sql"
    conType="files"
    local slist=""
    for file in ${filelist[*]}; do
      slist="$slist,$file"
    done
    slist=${slist:1}
    actLine=`printf "$lineNo\t$actType\t$conType\t\"$slist\""`;
  elif [ ${#filelist[*]} -gt 0 -a $allsql = "false" ]; then
    actType="shell"
    conType="files"
    actLine=`printf "$lineNo\t$actType\t$conType\t\"${filelist[*]}\""`;
  else
    actLine=""
    fLog ERROR "Unsupported action type"
    return
  fi

  dbg INFO "actLine=$actLine"
  if [ -n "$actLine" ]; then echo $actLine >> $actFile; fi

  if [ -f $HOMEDIR/$TEMPDIR/${JOBNAME}.job ]; then
    [ `grep "ACTION $actionname" $HOMEDIR/$TEMPDIR/${JOBNAME}.job | wc -l` -eq 0 ] && echo "ACTION $actionname" >> $HOMEDIR/$TEMPDIR/${JOBNAME}.job
  fi
}

function cmdPILOT
{
# $1 : PILOT name
# $2 : ACTION list
# $3 : concurrency num
# Usage :
#   PILOT p1 a1             # 1 action in single thread
#   PILOT p1 (a1 a2)        # 2 actions in single thread
#   PILOT pi* a1 10         # 1 action in 10 threads, named pi[0~9]
#   PILOT pi* "a1 a2 a3" 5  # 3 actions in 5 threads, named pi[0~9]
  local pilotContent=$*

  local inquote="n"
  local quotefind="\""
  local inparen="n"
  local logicalparm=0
  local threadNum=1
  local pilotName actList
  unset pilotName actList

  if [ $haddefine = "n" ]; then
    fLog WARNING "Job must be DEFINEd before declaring a PILOT, no PILOT recorded..."
  fi
  set -f
  while [ $# -gt 0 ]; do
#    dbg INFO "original \$1=$1"
    if [ "${1:0:1}" = "$quotefind" -a $inquote = "n" ]; then
      inquote="y"
      actList="${1:1}"
      if [ "${1: -1:1}" = "$quotefind" ]; then inquote="n"; actList="${actList/$quotefind/}"; fi
      while [ $inquote = "y" -a $# -gt 0 ]; do
        shift
        if [ "${1: -1:1}" = "$quotefind" ]; then inquote="n"; actList="${actList} ${1/$quotefind/}";
        else actList="$actList $1"
        fi
      done
      if [ $# -eq 0 -a $inquote = "y" ]; then
        fLog -v WARNING "quote pair not match in PILOT clause: \"PILOT $pilotContent\""
        return
      fi
      logicalparm=$(( $logicalparm + 1 ))
#      dbg INFO "actList=$actList"
    elif [ "${1:0:1}" = "(" -a $inparen = "n" ]; then
#      dbg INFO "in parenthesis, \$1=$1"
      inparen="y"
      actList="${1:1}"
      shift
      if [ "${actList: -1:1}" = ")" ];then
        inparen="n"
        actList="${actList/)/}"
      else
        while [ $# -gt 0 -a $inparen = "y" ]; do
          if [ "${1: -1:1}" = ")" ]; then inparen="n"; actList="$actList ${1/)/}"
          else actList="$actList $1"
          fi
          shift
        done
      fi
      logicalparm=$(( $logicalparm + 1 ))
    elif [ "${1:0:1}" = "(" -a $inparen = "y" ]; then
      fLog -v WARNING "parenthesis pair not match in PILOT clause: \"PILOT $pilotContent\""
      return
    else
      logicalparm=$(( $logicalparm + 1 ))
      set -f
      if [ $logicalparm -eq 1 ]; then pilotName=$1
      elif [ $logicalparm -eq 2 ]; then actList=$1
      elif [ $logicalparm -eq 3 ]; then threadNum=$1
      else
        fLog ERROR "logical parameter $logicalparm \"$1\" not understood"
        return
      fi
    fi
    shift
  done

  if [ $logicalparm -lt 2 ]; then fLog -v ERROR "Insufficient param list."; return; fi
  dbg INFO "pilotName=$pilotName, actionList=$actList, threadNum=$threadNum"

# ------------------------- Refine Parameters --------------------------------


  x=$(echo $pilotName | tr A-Z a-z)
  if [ "$pilotName" != "$x" ]; then fLog NOTE "transfer PILOT $pilotName into $x"; pilotName=$x; fi
  if [ -n "$threadNum" -a -n "$(echo $threadNum | tr -d 0-9)" ]; then
    fLog -v ERROR "thread num must be numeric"
    return
  elif [ $threadNum -gt 1 -a "${pilotName: -1:1}" != "*" ]; then
    fLog -v ERROR "PILOT name must end with * if multi-thread enabled. Suggested name: \"${pilotName}*\" "
  fi

# -------------------- Create all files needed in a pilot ---------------------
  local pltFile="${TEMPDIR}/${pilotName}.plt"
  if [ -f $pltFile ]; then
    fLog -v WARNING "PILOT ${BOLD}$pilotName${NONE} already exists, create new or delete it. Skip..."
    return
  else
    echo "THREADNUM $threadNum" >> $pltFile
    for action in ${actList[*]} ; do
      addAction $action
      echo "ACTION $action" >> $pltFile
    done
  fi

#  echo "current job : ${JOBNAME}"
  if [ -f $HOMEDIR/$TEMPDIR/${JOBNAME}.job ]; then
    [ `grep "PILOT $pilotName" $HOMEDIR/$TEMPDIR/${JOBNAME}.job | wc -l` -eq 0 ] && echo "PILOT $pilotName" >> $HOMEDIR/$TEMPDIR/${JOBNAME}.job
  fi

}

function cmdREPORT
{
# $1 : pilot name
# Usage:
#    REPORT p1*
  local rptFile=${TdhBenchCurrentServer}_logs/${1}.rpt
  if [ ! -f $rptFile ]; then fLog ERROR "Report file $rptFile not exists. Skip report"; return 1; fi
  echo -e "${BOLD}===============================================================${NONE}"
  while read LINE; do
    if [ "$LINE" != "${LINE/Summary/}" ]; then
      echo -e "${CYAN}${BOLD}$LINE${NONE}"
    else
      echo -e "$LINE"
    fi
  done < $rptFile
  echo -e "${BOLD}===============================================================${NONE}"
}

function addAction
{
  # $1 : action name
  # $2 : action type
  local actFile=${HOMEDIR}/${TEMPDIR}/${1}.act
  local actDir=${HOMEDIR}/${TEMPDIR}/${1}
  local ymlFile=${HOMEDIR}/${TEMPDIR}/${1}.yml
  local sqlFile=${actDir}/sql/query.sql
  local sources fileList

#  cd $HOMEDIR/$TEMPDIR
#  if [ $# -lt 1 -a ! -f $actFile ]; then fLog ERROR "ACTION file $actFile not found."; cd -; return 1; fi
  if [ $# -lt 1 -a ! -f $actFile ]; then fLog ERROR "ACTION file $actFile not found."; return 1; fi
  local queryNum=$(grep -i "query" $actFile | wc -l )  # all queries will be collect in $sqlFile
  [ -e $ymlFile ] && rm -rf $ymlFile; touch $ymlFile; echo "actions:" > $ymlFile
  [ -e $sqlFile ] && rm -rf $sqlFile; mkdir -p $(dirname $sqlFile);  touch $sqlFile

  set -f
  while read LINE; do
    tokens=(`echo $LINE`)
    dbg INFO "$LINENO : LINE= '${tokens[*]}';token[1]=${tokens[1]}; token[2]=${tokens[2]}; token[3]=${tokens[3]}; token[rest]=${tokens[@]:3} "
    if [ ${tokens[1]} = "sql" ]; then
      if [ ${tokens[2]} = "dir" ]; then
        sources=${tokens[3]}
        if [ ! -d $sources ]; then fLog WARNING "Dir $sources not exists, skipped in ACTION $1"; break; fi
        cp -rf $sources $actDir
        sources=${1}/$(basename $sources)
#       sources=${tokens[3]/${HOMEDIR}\/${TEMPDIR}\//}
        dbg INFO "$0 $LINENO : refined=$sources"
        bash $TOOLDIR/genYML.sh -t sql -s $sources -o $ymlFile -d "action ${1} - ${tokens[0]}" -a -db ${TdhBenchDb}
      elif [ ${tokens[2]} = "files" ]; then
        sources=""
        filelist=${tokens[3]//"\""/}
        filelist=${filelist//,/" "}
        for file in $filelist ; do
          if [ ! -e $file ]; then fLog WARNING "File $file not exists, skipped in ACTION $1"; continue; fi
          cp -rf $file ${actDir}/sql/$(basename $file)
          sources="${sources},${1}/sql/$(basename $file)"
        done
        sources=${sources:1}
        dbg INFO "$LINENO : refined=$sources"
        bash $TOOLDIR/genYML.sh -t sql -s $sources -o $ymlFile -d "action ${1} - ${tokens[0]}" -a -db ${TdhBenchDb}
      elif [ ${tokens[2]} = "query" -a $queryNum -gt 0 ]; then
        local queries=${tokens[@]:3}
        queries=${queries//"\""/}
#        dbg INFO "queries = $queries"
        while [ ${#queries} -gt 0 ]; do
          read ans
#          dbg INFO "queries=$queries"
          echo ${queries:0:$(expr index "$queries" ';')} >> $sqlFile
          queries=${queries:$(expr index "$queries" ';')}
        done
        queryNum=$(( $queryNum - 1 ))
        unset queries
      else
        echo "NOT SUPPORTED sql type"
      fi
    elif [ ${tokens[1]} = "shell" ] && [ ${tokens[2]} = "files" ]; then
      sources=""
      filelist=${tokens[3]//"\""/}
      filelist=${filelist//,/" "}
      for file in $filelist ; do
        if [ ! -e $file ]; then fLog WARNING "File $file not exists, skipped in ACTION $1"; continue; fi
        [ ! -e ${actDir}/shell ] && mkdir -p ${actDir}/shell
        cp -rf $file ${actDir}/shell/$(basename $file)
        sources="${sources},${1}/shell/$(basename $file)"
      done
      sources=${sources:1}
      dbg INFO "$0 $LINENO: refined=$sources"
      bash $TOOLDIR/genYML.sh -t shell -s $sources -o $ymlFile -d "action ${1} - ${tokens[0]}" -a
    else
      echo "type ${tokens[1]} NOT supported"
    fi
  done < $actFile
  if [ `cat $sqlFile | wc -l` -gt 0 ]; then
    bash $TOOLDIR/genYML.sh -t sql -s ${sqlFile/${HOMEDIR}\/${TEMPDIR}\//} -o $ymlFile -d "action ${1} - queries" -a -db ${TdhBenchDb}
  fi
#  cd -
}

function delAction
{
# $1 : action name
  dbg INFO "$LINENO : arg = $1"
  local actList jobList actName

  set +f
  jobList=(`ls ${HOMEDIR}/${TEMPDIR}/*.job`)
  set -f
  if [ "$1" = "ALL" ]; then
    set +f
    actList=(`ls ${HOMEDIR}/${TEMPDIR}/*.act`)
    set -f
  else
    actList=${HOMEDIR}/${TEMPDIR}/${1}.act
    if [ $# -ne 1 -o ! -f $actList ]; then fLog -v WARNING "Action file \"$actList\" not exists or using wrong args list."; return 1; fi
  fi

  for actFile in ${actList[*]}; do
    local actName=$(basename $actFile)
    actName=${actName/.act/}
    set +f
    rm -rf ${TEMPDIR}/${actName}
    rm -rf ${TEMPDIR}/${actName}.yml
    set -f
    rm -rf $actFile

    actName=$(basename $actFile); actName=${actName/.act/}
    # remove actions referenced in .job files
    for jobFile in ${jobList}; do
      sed -i "/ACTION ${actName}/d" $jobFile
    done
  done
}

function delPilot
{
# $1 : pilot name
# $2 : -quick | -full
  local pltList jobList pltName
  local delFull=0

  set +f
  jobList=(`ls ${HOMEDIR}/${TEMPDIR}/*.job`)
  set -f
  if [ "$1" = "ALL" ]; then
    set +f
    pltList=(`ls ${HOMEDIR}/${TEMPDIR}/*.plt`)
    set -f
  else
    pltList=${HOMEDIR}/${TEMPDIR}/${1}.plt
    if [ $# -lt 2 -o ! -f $pltList ]; then fLog -v WARNING "Pilot file \"$pltList\" not exists or using wrong args list."; return 1; fi
  fi
  if [ $# -eq 2 -a "$2" = "-quick" ]; then delFull=0
  elif [ $# -eq 2 -a "$2" = "-full" ]; then delFull=1
  else fLog -v WARNING "unavailable arg \"$2\", skip ... "; return 1;
  fi

  for pltFile in ${pltList[*]}; do
  if [ $delFull -eq 1 ]; then
  while read LINE ; do
    tokens=(`echo $LINE`)
    if [ "${tokens[0]}" = "ACTION" ]; then delAction ${tokens[1]} ; fi
  done < $pltFile
  fi

  rm -rf $pltFile
  pltName=$(basename $pltFile); pltName=${pltName/.plt/}
  # remove pilot referenced in .job files
  for jobFile in ${jobList}; do
    sed -i "/PILOT ${pltName/\*/\\*}/d" $jobFile
  done
  done  # end of reading .plt file
}

function delJob
{
# $1 : job name
  local jobFile=${HOMEDIR}/${TEMPDIR}/${1}.job
  if [ $# -ne 1 -o ! -f $jobFile ]; then fLog -v WARNING "Job file \"$jobFile\" not exists or using wrong args list."; return 1; fi
  dbg INFO "$LINENO : arg = $1, jobFile=$jobFile"

  while read LINE ; do
    tokens=(`echo $LINE`)
    dbg INFO "$LINENO : tokens[0]=${tokens[0]}, tokens[1]=${tokens[1]}"
    if [ "${tokens[0]}" = "ACTION" ]; then delAction ${tokens[1]} ; fi
    if [ "${tokens[0]}" = "PILOT" ]; then delPilot ${tokens[1]} -quick ; fi
  done < $jobFile
  rm -rf $jobFile
}

function cmdDELETE
{
# $1 = target type : [JOB|ACTION|PILOT]
# $2 = target name : <name>|ALL
# TODO: add job-action-pilot file deps check before delete
  if [ $# -ne 2 ]; then fLog ERROR "CLEAN <target type> <target name> expected, your cmd is \"$*\""; return; fi

  local targetType=$(echo $1 | tr a-z A-Z)
  local targetName=$2

  case "$targetType" in
    "JOB")
      delJob $targetName
    ;;
    "PILOT")
      delPilot $targetName -quick
    ;;
    "ACTION")
      delAction $targetName
    ;;
    *)
      fLog -v ERROR "Unrecognized type: $targetType"
      return
    ;;
  esac
}

function cmdDOOM
{
#  dbg INFO "$0 : $HOMEDIR/$TEMPDIR/*"
  set +f
  `rm -rf $HOMEDIR/$TEMPDIR/*`
  set -f
}

function deleteJob
{
# DESC: delete *.job files in PWD
# $1 : .job file
  local jobname=""
  if [ $# -eq 1 ]; then jobname=${1/.job/}
  else jobname=$JOBNAME
  fi

  dbg INFO "delteJob - pwd=$PWD, jobname=$jobname";
#  cd $HOMEDIR/$TEMPDIR
  if [ -e ${jobname}.job ]; then
    [ -d ${jobname}/sql ] && rm -rf ${jobname}/sql
    while read LINE; do
      tokens=(`echo $LINE`)
      [ ${tokens[0]} = "#" ] && continue
      if [ ${tokens[0]} = "ACTION" ]; then
        [ -e ${tokens[1]}.act ] && rm -rf ${tokens[1]}.act
        [ -e ${tokens[1]}.yml ] && rm -rf ${tokens[1]}.yml
      elif [ ${tokens[0]} = "PILOT" ]; then
        [ -e ${tokens[1]}.act ] && rm -rf ${tokens[1]}.plt
      else
        fLog WARNING "Unrecognized file \"$LINE\" in ${jobname}.job "
      fi
    done < ${jobname}.job
    rm -rf ${jobname}.job
  else
    fLog WARNING "Job File $1 not exits, do nothing"
  fi
#  cd -
}

function cmdDEFINE
{
# $1 = Job name
# $2:* = Job description

  if [ $# -lt 1 ]; then fLog ERROR "Job name must be defined"; return; fi
  if [ $PWD != $HOMEDIR ]; then cd $HOMEDIR; echo -e "change directory to $HOMEDIR"; fi

#----------------- Global Info for each Job -------------------
  LOGLINENO=0           # line indicator in log file for this RUNID
  ACNT=0                # reset number of ACTIONs
  unset ACUR            # global current ACTION pid
  unset ANAMES          # ACTION name and the file name
  unset APIDS
  unset AINTERVAL       # interval time between ACTIONs
  unset ATYPE           # save the type ACTION or PILOT
  unset PLTNAMES        # save ACTION files for each PILOT
#  unset PLTLOGONS       # save lists of logons
  unset MASTERPIDS      # the PID of ACTION master
  RUNID=""
  MASTERCNT=0
  PILOTCNT=0
  unset HADCLEANUP
  declare -a ANAMES APIDS PLTNAMES #PLTLOGONS

#  cmdDOOM
  set +f
  if [ -d $TEMPDIR ]; then cd $TEMPDIR; fi

  # this part would change to support multi job definition. after job selection is done
  local joblist=( $(find . -name "*.job") )
  for JOB in ${joblist[*]}; do
    deleteJob $JOB
  done
  unset joblist

  if [ "$(basename $PWD)" = "$TEMPDIR" ]; then cd - 1>/dev/null;  fi
  set -f

  MASTERPIDS=$$
  echo -e "master tdhbench $$" > $TEMPDIR/pids.txt  # FORAMT: NAME ROLE PID

  export JOBNAME=$1
  shift
  JOBDESC=$*
  export JOBDESC=`echo $JOBDESC | tr \' \"`
  echo $JOBNAME > $TEMPDIR/currentJob
  echo "# JOB $JOBNAME" > $TEMPDIR/${JOBNAME}.job

  echo -e "${BOLD}
------------------- Job:$JOBNAME   Desc:$JOBDESC -------------------${NONE}"
  haddefine="y"
}

function dbg
{
  if [ $debug_level -gt 2 ]; then
    TYPE=$1
    shift
    INFO=$*
    echo -e "$TYPE : $INFO"
  fi
}

#=====================================================================================================

mkdir -p $TEMPDIR

# ============================================ Main Process Loop ==============================================
trap fHadCtrlc INT

dbg INFO Start Main

# ENV check
MISSING=0;
if [ ! -d $TEMPDIR ]; then ((MISSING++)); echo "TEMPDIR not defined, $TEMPDIR"; fi
if [ ! -e ${TdhBenchCurrentServer}_logs/conf.xml ]; then ((MISSING++)); echo "TdhBench config file not found, check ${TdhBenchCurrentServer}_logs"; fi
set +f
if [ $( ls *.profile 2>/dev/null | wc -l ) -eq 0 ]; then ((MISSING++)); echo "No profile found in current dir"; fi
set -f
# [ ! -f TdhBench.persona ] && ((MISSING++))

dbg INFO MISSING FILE cnt = $MISSING

# Set up TdhBench profile
if [ $MISSING -gt 0 -o "$1" = "setup" ]; then
  echo
  echo "Running Setup - Establish TdhBench files and directories"
  read -e -p "Press Enter key to continues ..."

  cd $HOMEDIR/setup
  bash ./TdhBenchSetup.sh
  if [ $? -gt 1 ]; then echo "ERROR: Setup process has error, please check log in $LOGDIR "; exit 1; fi
  cd $HOMEDIR

  set +f
  if [ ! -f *.profile ]; then exit 1; fi
  set -f
fi

# --------------------------------------- Command Process Loop ---------------------------------------------
while true; do
  read -e -p "Enter CMD: " CMDLINE #  <&6
  fLog Input: "$CMDLINE"
  CMD1="${CMDLINE%%" "*}"
  CMDREST="${CMDLINE:${#CMD1}}"
  CMDREST="${CMDREST#*" "}"
  CMD1="`echo $CMD1 | tr a-z A-Z`"

  if [ "$CMD1" = "EXIT" ]; then CMD1=QUIT; fi
  if [ "$CMD1" = "GO" ]; then CMD1=RUN; fi

  if [ "$HADCLEANUP" = "Y" -a "$CMD1" != "DEFINE" -a "$CMD1" != "QUIT" ];then
    fLog ERROR "After all job cleaned, your statement shall be DEFINE or QUIT"
    CMD1=""
  fi

  if [ -e $HOMEDIR/stoprun ]; then
    fLog INFO "found file $HOMEDIR/stoprun, stopping jobs"
    fTrace 1 "main master Found $HOMEDIR/stoprun - stopping jobs"
    STOPRUN=true
  fi

  dbg INFO CMD1=$CMD1, CMDREST=$CMDREST
  if [ -z "$STOPRUN" ];then
#    dbg INFO In cmd process branch
    case ${CMD1} in
      "DEFINE")
        cmdDEFINE $CMDREST
        ;;
      "ACTION")
        cmdACTION $CMDREST
        ;;
      "PILOT")
        cmdPILOT $CMDREST
        ;;
      "DELETE")
        cmdDELETE $CMDREST
        ;;
      "DOOM")
        cmdDOOM
        ;;
      "EXEC")
        ;;
      "LABEL")
        ;;
      "CD")
        ;;
      "CLEAN")
        cmdCLEAN $CMDREST
        ;;
      "REPORT")
        cmdREPORT $CMDREST
        ;;
      "OS")
        cmdOS "$CMDREST"
        ;;
      "RUN")
        if [ "$hasDefine" = "n" ]; then fLog ERROR "There is no job DEFINEd before RUN"
        else cmdRUN $CMDREST
        fi
        ;;
      "DEBUG")
        fDebug
        ;;
      "QUIT"|"EXIT")
        skipping=n
        if [ $( cat $TEMPDIR/pids.txt | wc -l ) -ne 1 ]; then
          fLog WARNING "There is unfinished process in pids.txt. Start cleanup process"
          cmdCLEAN "Cleaning..."
        fi
        echo -e "Thanks for using TDHbench, goodbye~"
        cd $HOMEDIR
        exit 0
        break
        ;;
      *)
#        cmdOS "$CMDLINE"
        ;;
    esac

#    [ ${ReturnCode} -eq 0 ] && exit $ReturnCode
  fi
done
