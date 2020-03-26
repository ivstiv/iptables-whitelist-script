#!/bin/bash
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

# allow a command to fail with !’s side effect on errexit
# use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=l:p:r
LONGOPTS=list:,ports:,remove

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

remove=n list='' ports=''
while true; do
    case "$1" in
        -r|--remove)
            remove=y
            shift
            ;;
        -l|--list)
            list="$2"
            shift 2
            ;;
        -p|--ports)
            ports="$2"
            shift 2
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

if [[ $remove == 'y' ]]; then
    echo "Removing WHITELIST chain from iptables."
    # remove reference to the chain from prerouting
	index=$(iptables -t mangle -L PREROUTING --line-numbers | grep WHITELIST | awk '{print $1}')
	iptables -t mangle -D PREROUTING $index
	# remove the WHITELIST chain 
    iptables -t mangle -F WHITELIST
    iptables -t mangle -X WHITELIST
    # do the same for ip6tables
	index=$(ip6tables -t mangle -L PREROUTING --line-numbers | grep WHITELIST | awk '{print $1}')
	ip6tables -t mangle -D PREROUTING $index
	ip6tables -t mangle -F WHITELIST
    ip6tables -t mangle -X WHITELIST
fi

#iptables -t mangle -N WHITELIST
#iptables -t mangle -A WHITELIST -s 3.3.3.3 -j DROP
#iptables -t mangle -A PREROUTING -p tcp -m multiport --dports 80,443 -j WHITELIST
#iptables -t mangle -L PREROUTING --line-numbers | grep WHITELIST | awk '{print $1}'

#ip6tables -t mangle -N WHITELIST
#ip6tables -t mangle -A WHITELIST -s  2001:db8:1f0a:3ec::2/128 -j DROP
#ip6tables -t mangle -A PREROUTING -p tcp -m multiport --dports 80,443 -j WHITELIST
#ip6tables -t mangle -L PREROUTING --line-numbers | grep WHITELIST | awk '{print $1}'


echo "remove: $remove, list: $list, ports: $ports"
