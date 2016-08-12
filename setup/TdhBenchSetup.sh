#!/bin/bash
# TDH bench installation procedure
BOLD='\033[1m' && CYAN='\033[01;36m' && NONE='\033[00m' && UNDERLINE='\033[4m' && GREEN='\033[01;32m'

cd $(dirname $0)
[ -e ../ENV.sh ] && source ../ENV.sh

chmod +x ./setupDB.sh
chmod +x ./SetupGuide.sh
chmod +x ./TdhBenchProfile.sh

function PressEnter
{
echo -en Press ${BOLD}Enter${NONE} to continue ...
read
}

profileFile=""
serverName=""

if [ -f ../TdhBench.Current.Server ]; then
  while read LINE; do
    tokens=(`echo $LINE | tr "=" " "`)
#    prompt=tokens
    if [ ${tokens[0]} = "TdhBenchCurrentProfile" -a -n ${tokens[1]} ]; then profileFile=${tokens[1]}.profile ; fi
    if [ ${tokens[0]} = "TdhBenchCurrentServer" -a -n ${tokens[1]} ]; then serverName=${tokens[1]} ; fi
  done < ../TdhBench.Current.Server
  #echo "profileFile = $profileFile"
  #read
  if [ -f ../$profileFile -a -n $profileFile ]; then source ../$profileFile ; fi
fi

prompt=""
while [ 1 = 1 ]; do
  clear
  echo -e TdhBench Setup - Version TDH-4.6
  echo -e 
  if [ ! -z "$prompt" ]; then echo -e 
    echo -e ${BOLD}$prompt${NONE}
    echo -e 
    prompt=""
  fi

# Prompt Menu
  echo -e ${CYAN}0${NONE}. Help on how to setup TDH, create databases and users
  echo -e ${CYAN}1${NONE}. Setup TdhBench profile
  echo -e ${CYAN}2${NONE}. Setup TdhBench Database
  echo -e ${CYAN}3${NONE}. Install TDH client software
#  echo -e `[ "$profileFile" != "none" ] && echo -e ${CYAN}3${NONE}`. - Validate TDH connection
  echo -e  Enter number from list above, or type
  echo -e  "    ${CYAN}done${NONE} - to return to tdbench or "
  echo -e  "    ${CYAN}quit${NONE} - to leave setup and tdbench "
  echo -e
  echo -en "Enter ${CYAN}1-3${NONE}, done, or quit: "
  read ans
  
  if [ "$ans" != "quit" ]; then echo "You choice is $ans "; fi
  
  case `echo $ans | tr A-Z a-z` in
    "quit"|"q")
      clear
      exit 1
    ;;
    "done")
      clear
      break
    ;;
    0)
      prompt="select option 0 : Readme"
      bash ./guide.sh
    ;;
    1)
      prompt="select option 1 : Create/Configure profile"
      if [ "$profileFile" = "" ]; then
        echo -e "\n${BOLD}Creating New Server.${NONE} \nEnter the name for profile file and logs directory for the new server."
        read -p "Enter word (up to 20 characters) to be used in those names: " ans
        if [ ${#ans} -gt 20 ]; then ans=${ans:1:20}; echo ${RED}ERROR:${NONE} Answer too long. Will use: $ans;fi
        if [ -z "$ans" ]; then prompt="Error: No name given for new profile"
        else
           if [ -f ../$ans.profile ]; then prompt="Error: That profile already exists"
           else
              profileFile=$ans.profile
           fi
        fi
      fi
      if [ "$profileFile" != "" ]; then
        echo "profileFile = $profileFile"
        ./TdhBenchProfile.sh ../$profileFile
        if [ $? != 0 ]; then PressEnter; fi
        if [ -f ../$profileFile ]; then
          echo "TdhBenchCurrentServer="${profileFile/.profile/} > ../TdhBench.Current.Server
          echo "TdhBenchCurrentProfile="${profileFile/.profile/} >> ../TdhBench.Current.Server
          chmod a+x ../TdBench.Current.Server
          TdBenchCurrentServer=${profileFile/.profile/}
          LogDir=../${TdBenchCurrentServer}_logs
          if [ -d $LogDir ]; then
            echo -e ${BOLD}NOTE${NONE} - Reusing existing $LogDir
          else  
            mkdir $LogDir
            fi
#          LogFile=$LogDir/$MyScriptName.log
          source ../$profileFile
          fi
      else
        echo $prompt
#        read -p "Press Enter to continue .." ans
       fi
    ;;
    2)
      prompt="select option 2 : Set up TdhBench's Database "
      if [ -e ${HOMEDIR}/TdhBench.Current.Server ]; then
        source ${HOMEDIR}/TdhBench.Current.Server
        profileFile=${HOMEDIR}/${TdhBenchCurrentProfile}.profile
#        prompt="DBG: profileFile = $profileFile"
        if [ ! -e $profileFile ]; then
          prompt="TdhBench Server specified, please ensure you've finished setup process";
          break
        fi
        source $profileFile
      else
        prompt="WARNING: Current Server not specified, finish setup process"
        break
      fi

      if [ ! -e ${TdhBenchPlayerPath}/player-1.0-all.jar ]; then
        prompt="WARING: TDH client not installed yet"
      fi
      bash ./setupDB.sh $profileFile
      if [ $? -ne 0 ]; then prompt="Create config file and setup DB failed"
      else prompt="Create Database ${TdhBenchDb} succeeded!"
      fi
    ;;
    3)
      prompt="selection option 3 : set up TDH client - P"
    ;;
    *)
      prompt="Error: \"$ans\" is not a valid option, retry, done or quit?"
    ;;
  esac
done

cd - 1>/dev/null