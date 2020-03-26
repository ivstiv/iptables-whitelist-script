#!/bin/bash
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=l:p:r
LONGOPTS=list:,ports:,remove

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

remove=n list='' ports=''
# now enjoy the options in order and nicely split until we see --
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
if [[ $remove === 'y' ]]; then
    echo "Removing  WHITELIST chain."
    # remove reference to the chain from prerouting
    iptables -F WHITELIST
    iptables -X WHITELIST
    # do the same for iptables 6
fi

echo "remove: $r, list: $list, ports: $ports"
