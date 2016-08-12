#!/usr/bin/env bash
#/bin/bash
# set -vx
# Profile Menu for Tdhbench - Copyright 2016, Transwarp
# $1 = profile path

BOLD='\033[1m' && CYAN='\033[01;36m' && NONE='\033[00m' && UNDERLINE='\033[4m' && GREEN='\033[01;32m' && RED='\033[01;31m'

if [ -z "$1" ]; then echo "Internal Error, Name of profile not specified"; return 1; fi

profileFile=$1

prompts=(""
"TDH Server IP that running for TdhBench"
"TDH Metastore IP that running for TdhBench"
"TDH Benchmark Database"
"TDH Hive Version, choose hive1 or hive2"
"LDAP user name"
"LDAP password"
"Kerberos Principal"
"Player Path"
)

variables=(""
InceptorServerIp
MetastoreIp
Db
HiveVersion
LdapUser
LdapPasswd
KbsPrincipal
PlayerPath
)

function display {
echo -e TdhBench Profile Settings - ${BOLD}Editing $profileFile${NONE}
echo
for (( i=1; i<${#prompts[*]}; i++ )); do
        eval x=\$TdhBench${variables[i]}
    printf "${CYAN}%2d${NONE}=${BOLD}%-20s${NONE} %-50s\n" $i "$x" "${variables[i]}: ${prompts[i]}"  
done
}

function writeprofile {
  echo \#TdhBench profile created at `date +"%Y/%m/%d %H:%M:%S"` > $profileFile
  echo >> $profileFile

  echo TdhBenchInceptorServerIp=$TdhBenchInceptorServerIp >> $profileFile
  echo TdhBenchMetastoreIp=$TdhBenchMetastoreIp >> $profileFile
  echo TdhBenchDb=$TdhBenchDb >> $profileFile
  echo TdhBenchHiveVersion=$TdhBenchHiveVersion >> $profileFile
  echo TdhBenchLdapUser=$TdhBenchLdapUser >> $profileFile
  echo TdhBenchLdapPasswd=$TdhBenchLdapPasswd >> $profileFile
  echo TdhBenchKbsPrincipal=$TdhBenchKbsPrincipal >> $profileFile
  echo TdhBenchPlayerPath=$TdhBenchPlayerPath >> $profileFile

#  chmod g+x $profileFile
  chmod 777 $profileFile
  echo "New profile written: ${profileFile##*/}"
  
  read -e p "Press Enter to continue ..."
}

function defaultprofile {
defaultAll=${1:-NO}       # if ALL is selected, all values will be defaulted, else blank will be defaulted
[ $defaultAll = "ALL" ] && TdhBenchIncepterServerIp=
[ $defaultAll = "ALL" ] && TdhBenchMetastoreIp=
[ -z "$TdhBenchLdapUser" -o $defaultAll = "ALL" ] && $TdhBenchLdapUser="admin"
[ -z "$TdhBenchLdapPasswd" -o $defaultAll = "ALL" ] && $TdhBenchLdapPasswd="admin"
[ -z "$TdhBenchKbsPrincipal" -o $defaultAll = "ALL" ] && $TdhBenchKbsPrincipal="hive@TDH"
[ -z "$TdhBenchDb" -o $defaultAll = "ALL" ] && $TdhBenchDb="tdhbench"
[ -z "$TdhBenchHiveVersion" -o $defaultAll = "ALL" ] && $TdhBenchHiveVersion="hive2"
[ -z "$TdhBenchPlayerPath" -o $defaultAll = "ALL" ] && $TdhBenchPlayerPath="/usr/lib/qa/lib"
}

# --------------------------- Main Loop ---------------------------
if [ -e ../TdhBench.persona ]; then
  source ../TdhBench.persona
else
  echo "Error: did not find ../TdhBench.persona - should be copied by setup in advance";
#  exit 1;
fi

if [ -e $profileFile ]; then
  source $profileFile;
#else
#  defaultprofile ALL
fi

clear
display

while [ 1 = 1 ]; do
   echo;echo "(if you don't have rights to TDH server, check README or ask admin to set up your ENV)"
   echo -en "Enter ${CYAN}#${NONE}=${BOLD}newvalue${NONE}, ${CYAN}default${NONE}, ${CYAN}help${NONE}, ${CYAN}quit${NONE}, or ${CYAN}write${NONE}: "
   read ans
   case `echo $ans | tr A-Z a-z` in
     default)
       read -p "Do you want to force non-empty entries to default? (Y or N): " ans
       if [ "`echo $ans | tr a-z A-Z`" = "Y" ]; then
         defaultprofile ALL
       else
	     defaultprofile NO
       fi
	 clear
	 display
     ;;
     debug)
       cmd=x
       while [ -n "$cmd" ]; do
         read -p "enter linux or shell cmd: " cmd
         eval $cmd
         done
       ;;
     quit|q)
	   clear
       break
     ;;
     write|w)
       needed=""
       badvalue=""
          read
          [ -z "$TdhBenchInceptorServerIp" ] && needed="$needed 1"
          [ -z "$TdhBenchMetastoreIp" ] && needed="$needed 2"
          [ -z "$TdhBenchDb" ] && needed="$needed 3"
          [ -z "$TdhBenchHiveVersion" ] && needed="$needed 4"
          hiveVer=`echo $TdhBenchHiveVersion | tr A-Z a-z`
          [ `echo $TdhBenchHiveVersion | tr A-Z a-z` != "hive1" -a `echo $TdhBenchHiveVersion | tr A-Z a-z` != "hive2" ] && badvalue="$badvalue 4"

          if [ -z "$needed" -a -z "$badvalue" ]; then writeprofile; clear; break
          else
            echo -e ${RED}ERROR${NONE} Essential info must be provided correctly before writing
#            echo "needed = $needed, badvalue = $badvalue"
            for i in $needed; do echo $i - ${variables[i]}: ${prompts[i]}; done
            echo -e ${RED}ERROR${NONE} Following option has bad value, please check...
            echo -e TDH hive version: $TdhBenchHiveVersion
            for i in $badvalue; do
              eval val=\$TdhBench${variables[i]}
              echo $i - ${variables[i]}: $val;
              `echo $TdhBenchHiveVersion | tr A-Z a-z`
            done
            read -e -p "Press Enter key or type Quit to exit without saving :"
            clear
          fi
	 ;;
     help)
	   clear
echo -e "TdhBench Profile instructions - Version $TdhBenchVersion

To fill in the values, enter a number=value  ... example:
   ${CYAN}1=TdhBenchInceptorServerIp${NONE}			(assumes /etc/hosts entries for TdhBenchInceptorServerIp , ...)

When done, type in \"${CYAN}write${NONE}\" to save values. You will then be asked if you want to continue setup.
If you don't want to save changes, type in \"${CYAN}quit${NONE}\". You will still be asked if you want to continue setup
even though no changes were made which will refresh views, macros, but preserve table contents.

You can use \"${CYAN}default${NONE}\" to fill in default profile for TDH benchmark. You will be asked
if you want to overlay the non-blank values to protect what you've entered previously.

Properties list in Profile :

   TdhBenchInceptorServerIp:  The TDH server to receive SQL request
   TdhBenchMetastoreIp:  The TDH meta data server for you benchmark
   TdhBenchDb:  The Benchmark DB to be used
   TdhHiveVersion:  The Hive version being used
   TdhBenchLdapUser: LDAP authentication's User
   TdhBenchLdapPasswd: LDAP authentication's password
   TdhBenchKbsPrincipal: Kerberos authentication's principal
   TdhBenchPlayerPath: ClassPath to TDH Player client
   ${BOLD}grant all on xxx_benchmark to xxx_benchmark with grant option;${NONE}
      (used for canceling queries in flight and getting node, AMP and TASM information)
"
	PressEnter
	clear
   	display
	;;
      *)
    tokens=( `echo $ans | tr "=" " "` )
    i=${tokens[0]}
    if [ -n "`echo $i | tr -d 0-9`" ]; then
      echo -e ${RED}ERROR:${NONE} Invalid entry: $ans; echo
      PressEnter
	else
	  eval TdhBench${variables[$i]}="${tokens[1]}"
	fi
    clear
    display
	;;
  esac
done