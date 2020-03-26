#!/bin/bash
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

# allow a command to fail with !’s side effect on errexit
# use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=l:p:ruh
LONGOPTS=list:,ports:,remove,update,help

# regarding ! and PIPESTATUS see above
# temporarily store output to be able to check for errors
# activate quoting/enhanced mode (e.g. by writing out “--options”)
# pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

remove=n listFile='' ports='' update=n help=n
while true; do
    case "$1" in
        -r|--remove)
            remove=y
            shift
            ;;
        -l|--list)
            listFile="$2"
            shift 2
            ;;
        -p|--ports)
            ports="$2"
            shift 2
            ;;
		-h|--help)
			help=y
			shift
			;;
		-u|--update)
			shift
			update=y
			;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

if [[ $help == 'y' ]]; then
	cat << EOM
Usage: bash whitelist.sh [options]
	
Options:
  -r,--remove | Removes the whitelist.
  -u,--update | Updates the ip lists files.
  -p,--ports <port1,port2> | Specifies ports delimited by comma, the whitelist to be applied to.
  -l,--list <path> | Specifies a custom ip list file.
EOM
	exit 0
fi

if [[ $update == 'y' ]]; then
	echo -e "Updating ip lists..."
	currentDir=$(pwd)
	rm $currentDir/stackpath.list $currentDir/cloudflare.list || ! echo "You need to execute the script from its own directory to update them!" || exit 1
	wget -qO - https://support.stackpath.com/hc/en-us/article_attachments/360041383752/ipblocks.txt > $currentDir/stackpath.list
	echo "$currentDir/stackpath.list was updated."
	wget -qO - https://www.cloudflare.com/{ips-v4,ips-v6} > $currentDir/cloudflare.list
	echo "$currentDir/cloudflare.list was updated."
fi

if [[ $remove == 'y' ]]; then
	echo "Removing WHITELIST chain from iptables."
	# remove reference to the chain from prerouting
	index=$(/sbin/iptables -t mangle -L PREROUTING --line-numbers | grep WHITELIST | awk '{print $1}' || true)
	[[ -n "$index" ]] && /sbin/iptables -t mangle -D PREROUTING $index || echo "Could not find any references in -t mangle of PREROUTING."
	/sbin/iptables -t mangle -F WHITELIST || true
	/sbin/iptables -t mangle -X WHITELIST || true
	# do the same for ip6tables
	index=$(/sbin/ip6tables -t mangle -L PREROUTING --line-numbers | grep WHITELIST | awk '{print $1}' || true)
	[[ -n "$index" ]] && /sbin/ip6tables -t mangle -D PREROUTING $index || echo "Could not find any references in -t mangle of PREROUTING."
	/sbin/ip6tables -t mangle -F WHITELIST || true
	/sbin/ip6tables -t mangle -X WHITELIST || true
	echo "Successfully removed!"
fi

[[ -z $listFile ]] && exit 0
[[ ! -e $listFile ]] && echo "Error: $listFile not found!" && exit 1

echo -e "\nCreating a new chain WHITELIST."
/sbin/iptables -t mangle -N WHITELIST || exit 1
/sbin/ip6tables -t mangle -N WHITELIST || exit 1

# add the ip ranges
while IFS= read -r address
do
	# check type of address
	if [[ $address =~ .*:.* ]]; then
		echo "Adding IPv6: $address"
		/sbin/ip6tables -t mangle -A WHITELIST -s $address -j ACCEPT
	else
		echo "Adding IPv4: $address"
		/sbin/iptables -t mangle -A WHITELIST -s $address -j ACCEPT
	fi
done < "$listFile"
/sbin/iptables -t mangle -A WHITELIST -j DROP
/sbin/ip6tables -t mangle -A WHITELIST -j DROP


echo -e "\nCreating a reference to WHITELIST in mangle table of PREROUTING."

if [[ -z $ports ]]; then
	/sbin/iptables -t mangle -I PREROUTING -j WHITELIST
	/sbin/ip6tables -t mangle -I PREROUTING -j WHITELIST
else
	/sbin/iptables -t mangle -I PREROUTING -p tcp -m multiport --dports $ports -j WHITELIST
	/sbin/ip6tables -t mangle -I PREROUTING -p tcp -m multiport --dports $ports -j WHITELIST
fi

echo "Finished! Check your new iptables rules with iptables -t mangle -L. Run the script with -r/--remove to undo all changes."