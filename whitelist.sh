#!/bin/sh
checkDependencies() {
    mainShellPID="$$"
    printf "curl\niptables\ngrep\ncut" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

# contains(string, substring)
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}


checkDependencies
###################
# PROCESS ARGUMENTS #
###################

remove=n listFile='' ports='' update=n help=n
# loop over the arguments
# leaving this here just in case https://stackoverflow.com/questions/34434157/posix-sh-syntax-for-for-loops-sc2039
while [ -n "$1" ]; do
    if [ "$1" = "--remove" ] || [ "$1" = "-r" ]; then 
        remove=y
    elif [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
        update=y
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        help=y
    elif [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        shift
        listFile="$1"
    elif [ "$1" = "--ports" ] || [ "$1" = "-p" ]; then
        shift
        ports="$1"
    else 
        echo "Invalid argument: $1. Run with --help to see available options." && exit
    fi
    shift
done

######################
# EXECUTE THE COMMANDS #
######################

if [ $help = 'y' ]; then
	cat << EOM
Usage: sh whitelist.sh [options]
	
Options:
  -r,--remove | Removes the whitelist.
  -u,--update | Updates the ip lists files.
  -p,--ports <port1,port2> | Specifies ports delimited by comma, the whitelist to be applied to.
  -l,--list <path> | Specifies a custom ip list file.
EOM
	exit 0
fi

if [ $update = 'y' ]; then
	echo "Updating ip lists..."
	currentDir=$(pwd)
    if [ ! -f "$currentDir/cloudflare.list" ] || [ ! -f "$currentDir/stackpath.list" ] ; then
        echo "[Error]: cloudflare.list or stackpath.list not found!" >&2
        echo "You need to execute the script from its own directory to update them!" >&2
        exit 1
    fi
	curl -s "https://support.stackpath.com/hc/en-us/article_attachments/360083735711/ipblocks.txt" > "$currentDir/stackpath.list"
	echo "$currentDir/stackpath.list was updated."
	curl -s "https://www.cloudflare.com/{ips-v4,ips-v6}" > "$currentDir/cloudflare.list"
	echo "$currentDir/cloudflare.list was updated."
fi

if [ $remove = 'y' ]; then
	echo "Removing WHITELIST chain from iptables."
    rule=$(/sbin/iptables -t mangle -S PREROUTING -w | grep "WHITELIST" | cut -f 1 -d ' ' --complement)
    if [ -z "$rule" ]; then
        echo "Could not find any references in -t mangle of PREROUTING."
    else
        eval /sbin/iptables -t mangle -D "$rule" -w
        echo "Removed: $rule"
    fi
	/sbin/iptables -t mangle -F WHITELIST -w
	/sbin/iptables -t mangle -X WHITELIST -w
	# do the same for ip6tables
    rule=$(/sbin/ip6tables -t mangle -S PREROUTING -w | grep "WHITELIST" | cut -f 1 -d ' ' --complement)
    if [ -z "$rule" ]; then
        echo "Could not find any references in -t mangle of PREROUTING."
    else
        eval /sbin/ip6tables -t mangle -D "$rule" -w
        echo "Removed: $rule"
    fi
	/sbin/ip6tables -t mangle -F WHITELIST -w
	/sbin/ip6tables -t mangle -X WHITELIST -w
fi

[ -z "$listFile" ] && exit 0
[ ! -e "$listFile" ] && echo "Error: $listFile file not found!" >&2 && exit 1

if [ -z "$ports" ]; then
    while true; do
        echo "You have not specified any ports. THIS COULD POSSIBLY LOCK YOU OUT OF THE SYSTEM!"
        printf "Do you want to continue? (yes/no):"
        read -r yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Stopping..." && exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

printf "\nCreating a new chain WHITELIST.\n"
/sbin/iptables -t mangle -N WHITELIST
/sbin/ip6tables -t mangle -N WHITELIST
# Whitelisting any traffic from the loopback interface
/sbin/iptables -t mangle -I WHITELIST -i lo -m comment --comment "Accept everything from loopback" -j ACCEPT
/sbin/ip6tables -t mangle -I WHITELIST -i lo -m comment --comment "Accept everything from loopback" -j ACCEPT

# add the ip ranges
while IFS= read -r address
do
	# check type of address
	if contains "$address" "::"; then
		echo "Adding IPv6: $address"
		/sbin/ip6tables -t mangle -A WHITELIST -s "$address" -j ACCEPT
	else
		echo "Adding IPv4: $address"
		/sbin/iptables -t mangle -A WHITELIST -s "$address" -j ACCEPT
	fi
done < "$listFile"
/sbin/iptables -t mangle -A WHITELIST -j DROP
/sbin/ip6tables -t mangle -A WHITELIST -j DROP


printf "\nCreating a reference to WHITELIST in mangle table of PREROUTING.\n"

if [ -z "$ports" ]; then
	/sbin/iptables -t mangle -I PREROUTING -j WHITELIST
	/sbin/ip6tables -t mangle -I PREROUTING -j WHITELIST
else
	/sbin/iptables -t mangle -I PREROUTING -p tcp -m multiport --dports "$ports" -j WHITELIST
	/sbin/ip6tables -t mangle -I PREROUTING -p tcp -m multiport --dports "$ports" -j WHITELIST
fi

echo "Finished! Check your new iptables rules with iptables -t mangle -L. Run the script with -r/--remove to undo all changes."