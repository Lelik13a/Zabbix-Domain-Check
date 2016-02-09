#!/bin/bash 

# fail if any pipe fail and unset var
#set -uo pipefail

#
# Program: Domain Expiration Check <domain-check> for zabbix
#
# Author: Lelik.13a gmail dot com
# 
#
# Based on script Matty < matty91 at gmail dot com >
# http://www.cyberciti.biz/tips/domain-check-script.html
#
#
# Purpose:
#  domain-check checks to see if a domain has expired. domain-check
#  can be run in interactive and batch mode.
#
# License:
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warrantyof
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Notes:
#   Since each registrar provides expiration data in a unique format (if
#   they provide it at all), domain-check is currently only able to
#   processess expiration information for a subset of the available
#   registrars.
#
# Requirements:
#   Requires whois
#
# Installation:
#   Copy the shell script to a suitable location
#
#

ZABBIX="FALSE"

# Whois server to use (cmdline: -s)
WHOIS_SERVER="whois.internic.org"

# Location of system binaries
AWK="/usr/bin/awk"
WHOIS="/usr/bin/whois"
DATE="/bin/date"
CUT="/usr/bin/cut"
CAT="/bin/cat"
FIND="/usr/bin/find"
SORT="/usr/bin/sort"
ZABBIXSND="/usr/bin/zabbix_sender"
BASENAME="/usr/bin/basename"
GREP="/bin/grep"
CP="/bin/cp"

# Zabbix server param
DOMAINDB="/var/cache/zabbix/domain.db"
ZABBIXSERVER="127.0.0.1"
ZABBIXPORT="10051"
ZABBIXHOST="Domains"


#############################################################################
# Purpose: Convert a date from MONTH-DAY-YEAR to Julian format
# Acknowledgements: Code was adapted from examples in the book
#                   "Shell Scripting Recipes: A Problem-Solution Approach"
#                   ( ISBN 1590594711 )
# Arguments:
#   $1 -> Month (e.g., 06)
#   $2 -> Day   (e.g., 08)
#   $3 -> Year  (e.g., 2006)
#############################################################################
date2julian() 
{
    if [ "${1} != "" ] && [ "${2} != ""  ] && [ "${3}" != "" ]
    then
         ## Since leap years add aday at the end of February, 
         ## calculations are done from 1 March 0000 (a fictional year)
         d2j_tmpmonth=$((12 * ${3} + ${1} - 3))
        
          ## If it is not yet March, the year is changed to the previous year
          d2j_tmpyear=$(( ${d2j_tmpmonth} / 12))
        
          ## The number of days from 1 March 0000 is calculated
          ## and the number of days from 1 Jan. 4713BC is added 
          echo $(( (734 * ${d2j_tmpmonth} + 15) / 24 -  2 * ${d2j_tmpyear} + ${d2j_tmpyear}/4
                        - ${d2j_tmpyear}/100 + ${d2j_tmpyear}/400 + $2 + 1721119 ))
    else
          echo 0
    fi
}

#############################################################################
# Purpose: Convert a string month into an integer representation
# Arguments:
#   $1 -> Month name (e.g., Sep)
#############################################################################
getmonth() 
{
       LOWER=`tolower $1`
              
       case ${LOWER} in
             jan) echo 1 ;;
             feb) echo 2 ;;
             mar) echo 3 ;;
             apr) echo 4 ;;
             may) echo 5 ;;
             jun) echo 6 ;;
             jul) echo 7 ;;
             aug) echo 8 ;;
             sep) echo 9 ;;
             oct) echo 10 ;;
             nov) echo 11 ;;
             dec) echo 12 ;;
               *) echo  0 ;;
       esac
}

#############################################################################
# Purpose: Convert a integer month into an string representation
# Arguments:
#   $1 -> Month num (e.g., 01)
#############################################################################
getmonthnum() 
{
       LOWER=$1
       case ${LOWER} in
             1|01) echo jan ;;
             2|02) echo feb ;;
             3|03) echo mar ;;
             4|04) echo apr ;;
             5|05) echo may ;;
             6|06) echo jun ;;
             7|07) echo jul ;;
             8|08) echo aug ;;
             9|09) echo sep ;;
             10)   echo oct ;;
             11)   echo nov ;;
             12)   echo dec ;;
	     *)    echo 0 ;;
	esac
}


#############################################################################
# Purpose: Calculate the number of seconds between two dates
# Arguments:
#   $1 -> Date #1
#   $2 -> Date #2
#############################################################################
date_diff() 
{
        if [ "${1}" != "" ] &&  [ "${2}" != "" ]
        then
                echo $(expr ${2} - ${1})
        else
                echo 0
        fi
}

##################################################################
# Purpose: Converts a string to lower case
# Arguments:
#   $1 -> String to convert to lower case
##################################################################
tolower() 
{
     LOWER=`echo ${1} | tr [A-Z] [a-z]`
     echo $LOWER
}

##################################################################
# Purpose: Access whois data to grab the registrar and expiration date
# Arguments:
#   $1 -> Domain to check
##################################################################
check_domain_status() 
{
    # Save the domain since set will trip up the ordering
    DOMAIN=${1}
    DOMAINFILE=${2}    
    local REGISTRAR=""
    local WHOIS_TMP="${DOMAINFILE}.tmp"

    TLDTYPE="`echo ${DOMAIN} | ${CUT} -d '.' -f3 | tr '[A-Z]' '[a-z]'`" 
    if [ "${TLDTYPE}"  == "" ];
    then
	    TLDTYPE="`echo ${DOMAIN} | ${CUT} -d '.' -f2 | tr '[A-Z]' '[a-z]'`" 
    fi

    # Invoke whois to find the domain registrar and expiration date
    #${WHOIS} -h ${WHOIS_SERVER} "=${1}" > ${WHOIS_TMP}
    # Let whois select server 
    if [ "${TLDTYPE}"  == "org" ];
    then
        ${WHOIS} -h "whois.pir.org" "${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "in" ]; # India
    then
        ${WHOIS} -h "whois.registry.in" "${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "uk" ]; # United Kingdom  
    then
        ${WHOIS} -h "whois.nic.uk" "${1}" > ${WHOIS_TMP}

    elif [ "${TLDTYPE}"  == "biz" ];
    then
        ${WHOIS} -h "whois.biz" "${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "info" ];
    then
        ${WHOIS} -h "whois.afilias.net" "${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "jp" ]; # Japan
    then
        ${WHOIS} -h "whois.jprs.jp" "${1}" > ${WHOIS_TMP}

    elif [ "${TLDTYPE}"  == "ca" ]; # Canada
    then
        ${WHOIS} -h "whois.cira.ca" "${1}" > ${WHOIS_TMP}

    elif [ "${TLDTYPE}"  == "com" -o "${TLDTYPE}"  == "net" -o "${TLDTYPE}"  == "edu" ];
    then
	${WHOIS} -h ${WHOIS_SERVER} "=${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "cz" ]; # CZ
    then
        ${WHOIS} -h "whois.nic.cz" "${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "sk" ]; # SK
    then
        ${WHOIS} -h "whois.sk-nic.sk" "${1}" > ${WHOIS_TMP}
    elif [ "${TLDTYPE}"  == "pl" ]; # PL
    then
        ${WHOIS} -h "whois.dns.pl" "${1}" > ${WHOIS_TMP}
    else
	${WHOIS} "${1}" > ${WHOIS_TMP}
    fi

    # Parse out the expiration date and registrar -- uses the last registrar it finds
    REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} -F: '/Registrar/ && $2 != ""  { REGISTRAR=substr($2,2,17) } END { print REGISTRAR }'`

    if [ "${TLDTYPE}" == "uk" ]; # for .uk domain
    then
	REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != ""  { getline; REGISTRAR=substr($0,2,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "jp" ];
    then
        REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} '/Registrant/ && $2 != ""  { REGISTRAR=substr($2,1,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "org" ];
    then
        REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} '/Tech Organization:/ && $3 != ""  { REGISTRAR=substr($2,1,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "info" ];
    then
        REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $2 != ""  { REGISTRAR=substr($2,1,15) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "biz" ];
    then
        REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $2 != ""  { REGISTRAR=substr($2,20,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "ca" ];
    then
	REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} -F: '/Registrar:/ && $0 != ""  { getline; REGISTRAR=substr($0,24,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "cz" ];
    then
	REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} -F: '/registrar:/ && $2 != ""  { REGISTRAR=substr($2,5,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "sk" ];
    then
	REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} '/Tech-name/ && $2 != ""  { REGISTRAR=substr($2,1,17) } END { print REGISTRAR }'`
    elif [ "${TLDTYPE}" == "pl" ];
    then
	REGISTRAR=`${CAT} ${WHOIS_TMP} | ${AWK} '/REGISTRAR:/ && $0 != ""  { getline; REGISTRAR=substr($0,1,25) } END { print REGISTRAR }'`
    fi

    # If the Registrar is NULL, then we didn't get any data
    if [[ "${REGISTRAR}" = "" && "${ZABBIX}" != "TRUE" ]]
    then
        prints "$DOMAIN" "Unknown" "Unknown" "Unknown" "Unknown"
        return
    elif [[ "${REGISTRAR}" = "" ]]
    then 
	prints "$DOMAIN" "skipped" "" ""
	return
    fi

    # Fix domain state
    ${CP} ${WHOIS_TMP} ${DOMAINFILE}
    

    # The whois Expiration data should resemble the following: "Expiration Date: 09-may-2008"

    # for .in, .info, .org domains
    if [ "${TLDTYPE}" == "in" -o "${TLDTYPE}" == "info" -o "${TLDTYPE}" == "org" ];
    then
	    tdomdate=`${CAT} ${WHOIS_TMP} | ${AWK} '/Expiry Date:/ { print $4 }'`
            tyear=`echo ${tdomdate} | ${CUT} -d'-' -f1`
            tmon=`echo ${tdomdate} | ${CUT} -d'-' -f2`
	    tmonth=$(getmonthnum ${tmon})
            tday=`echo ${tdomdate} | ${CUT} -d'-' -f3 |cut -d'T' -f1`
	    DOMAINDATE=`echo $tday-$tmonth-$tyear`
    elif [ "${TLDTYPE}" == "biz" ]; # for .biz domain
    then
            DOMAINDATE=`${CAT} ${WHOIS_TMP} | ${AWK} '/Domain Expiration Date:/ { print $6"-"$5"-"$9 }'`
    elif [ "${TLDTYPE}" == "uk" ]; # for .uk domain
    then
            DOMAINDATE=`${CAT} ${WHOIS_TMP} | ${AWK} '/Renewal date:/ || /Expiry date:/ { print $3 }'`
    elif [ "${TLDTYPE}" == "jp" ]; # for .jp 2010/04/30
    then
	    tdomdate=`${CAT} ${WHOIS_TMP} | ${AWK} '/Expires on/ { print $3 }'`
            tyear=`echo ${tdomdate} | ${CUT} -d'/' -f1`
            tmon=`echo ${tdomdate} | ${CUT} -d'/' -f2`
	    tmonth=$(getmonthnum ${tmon})
            tday=`echo ${tdomdate} | ${CUT} -d'/' -f3`
	    DOMAINDATE=`echo $tday-$tmonth-$tyear`
    elif [ "${TLDTYPE}" == "ca" ]; # for .ca 2010/04/30
    then
	    tdomdate=`${CAT} ${WHOIS_TMP} | ${AWK} '/Expiry date/ { print $3 }'`
            tyear=`echo ${tdomdate} | ${CUT} -d'/' -f1`
            tmon=`echo ${tdomdate} | ${CUT} -d'/' -f2`
	    tmonth=$(getmonthnum ${tmon})
            tday=`echo ${tdomdate} | ${CUT} -d'/' -f3`
	    DOMAINDATE=`echo $tday-$tmonth-$tyear`
    elif [ "${TLDTYPE}" == "cz" ]; # for .cz 10.09.2016
    then
	    tdomdate=`${CAT} ${WHOIS_TMP} | ${AWK} '/expire:/ { print $2 }'`
            tyear=`echo ${tdomdate} | ${CUT} -d'.' -f3`
            tmon=`echo ${tdomdate} | ${CUT} -d'.' -f2`
	    tmonth=$(getmonthnum ${tmon})
            tday=`echo ${tdomdate} | ${CUT} -d'.' -f1`
	    DOMAINDATE=`echo $tday-$tmonth-$tyear`
    elif [ "${TLDTYPE}" == "sk" ]; # for .sk 2016-09-07
    then
	    tdomdate=`${CAT} ${WHOIS_TMP} | ${AWK} '/Valid-date/ { print $2 }'`
            tyear=`echo ${tdomdate} | ${CUT} -d'-' -f1`
            tmon=`echo ${tdomdate} | ${CUT} -d'-' -f2`
	    tmonth=$(getmonthnum ${tmon})
            tday=`echo ${tdomdate} | ${CUT} -d'-' -f3`
	    DOMAINDATE=`echo $tday-$tmonth-$tyear`
    elif [ "${TLDTYPE}" == "pl" ]; # renewal date:          2016.09.10 11:38:59
    then
	    tdomdate=`${CAT} ${WHOIS_TMP} | ${AWK} '/renewal date:/ { print $3 }'`
            tyear=`echo ${tdomdate} | ${CUT} -d'.' -f1`
            tmon=`echo ${tdomdate} | ${CUT} -d'.' -f2`
	    tmonth=$(getmonthnum ${tmon})
            tday=`echo ${tdomdate} | ${CUT} -d'.' -f3`
	    DOMAINDATE=`echo $tday-$tmonth-$tyear`
    else # .com, .edu, .net and may work with others	 
	    DOMAINDATE=`${CAT} ${WHOIS_TMP} | ${AWK} '/Expiration/ { print $NF }'`	
    fi

    #echo $DOMAINDATE # debug 
    # Whois data should be in the following format: "13-feb-2006"
    IFS="-"
    set -- ${DOMAINDATE}
    MONTH=$(getmonth ${2})
    IFS=""

    # Convert the date to seconds, and get the diff between NOW and the expiration date
    DOMAINJULIAN=$(date2julian ${MONTH} ${1#0} ${3})
    DOMAINDIFF=$(date_diff ${NOWJULIAN} ${DOMAINJULIAN})

    if [ ${DOMAINDIFF} -lt 0 ]
    then
           prints ${DOMAIN} "Expired" "${DOMAINDATE}" "${DOMAINDIFF}" ${REGISTRAR}

    else
           prints ${DOMAIN} "Valid" "${DOMAINDATE}"  "${DOMAINDIFF}" "${REGISTRAR}"
    fi
}

####################################################
# Purpose: Print a heading with the relevant columns
# Arguments:
#   None
####################################################
print_heading()
{
                printf "\n%-35s %-17s %-8s %-11s %-5s\n" "Domain" "Registrar" "Status" "Expires" "Days Left"
                echo "----------------------------------- ----------------- -------- ----------- ---------"
}

#####################################################################
# Purpose: Print a line with the expiraton interval
# Arguments:
#   $1 -> Domain
#   $2 -> Status of domain (e.g., expired or valid)
#   $3 -> Date when domain will expire
#   $4 -> Days left until the domain will expire
#   $5 -> Domain registrar
#####################################################################
prints()
{
    MIN_DATE=$(echo $3 | ${AWK} '{ print $1, $2, $4 }')

    if [[ "${ZABBIX}" != "TRUE" ]] 
    then
        printf "%-35s %-17s %-8s %-11s %-5s\n" "$1" "$5" "$2" "$MIN_DATE" "$4"
    else
        printf "%-35s %-17s %-8s %-11s %-5s\n" "$1" "$5" "$2" "$MIN_DATE" "$4"
	
	# send data to zabbix server
	if [[ $2 == "skipped" ]]
	then 
	        ${ZABBIXSND} -z ${ZABBIXSERVER} -p ${ZABBIXPORT} -i - <<EOF
"${ZABBIXHOST}" "domain.registration.check[${1},Status]" "$2"
EOF
	else
	${ZABBIXSND} -z ${ZABBIXSERVER} -p ${ZABBIXPORT} -i - <<EOF
"${ZABBIXHOST}" "domain.registration.check[${1},DaysLeft]" "$4"
"${ZABBIXHOST}" "domain.registration.check[${1},Expires]" "$3"
"${ZABBIXHOST}" "domain.registration.check[${1},Registrar]" "$5"
"${ZABBIXHOST}" "domain.registration.check[${1},Status]" "$2"
EOF
	fi
	echo ""
    fi
}

##########################################
# Purpose: Describe how the script works
# Arguments:
#   None
##########################################
usage()
{
        echo "Usage: $0 [ -z ]"
        echo ""
        echo "  -z               : Zabbix send"
        echo ""
}


# ------------------------------------------------------ Main func ---------------------------------------------------------------------

### Evaluate the options passed on the command line
while getopts "z" option
do
        case "${option}"
        in
                z) ZABBIX="TRUE";;
                \?) usage
                    exit 1;;
        esac
done

### Check to make sure a domain database directory is available
if [[ ! -d ${DOMAINDB} ]]
then
        echo "ERROR: The domain database directory does not exist in ${DOMAINDB} ."
        echo "  FIX: Please modify the \$DOMAINDB variable in the program header or create directory."
        exit 1
fi

### Check to see if the whois binary exists
if [[ ! -f ${WHOIS} ]]
then
        echo "ERROR: The whois binary does not exist in ${WHOIS} ."
        echo "  FIX: Please modify the \$WHOIS variable in the program header."
        exit 1
fi

### Check to make sure a date utility is available
if [[ ! -f ${DATE} ]]
then
        echo "ERROR: The date binary does not exist in ${DATE} ."
        echo "  FIX: Please modify the \$DATE variable in the program header."
        exit 1
fi

### Baseline the dates so we have something to compare to
MONTH=$(${DATE} "+%m")
DAY=$(${DATE} "+%d")
YEAR=$(${DATE} "+%Y")
NOWJULIAN=$(date2julian ${MONTH#0} ${DAY#0} ${YEAR})


#if [[ "${ZABBIX}" != "TRUE" ]] 
#then
	print_heading
#fi

# get domains list in modify order
# get only domains modified older than one day

${FIND} ${DOMAINDB} -type f -mtime +1 -printf '%T+ %p\n' | ${GREP} -v ".tmp$" | ${SORT} | ${AWK} '{print $2}' | \
while read DOMAINFILE
do
	DOMAIN=$(${BASENAME} $DOMAINFILE)

	check_domain_status "${DOMAIN}" "${DOMAINFILE}"
    
	# Avoid WHOIS LIMIT EXCEEDED - slowdown our whois client by adding 3 sec 
	sleep 10
done


### Exit with a success indicator
exit 0









