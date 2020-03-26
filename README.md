# iptables-whitelist-script

A small bash script that can automatically setup a custom [iptables](https://en.wikipedia.org/wiki/Iptables) chain which accepts connections only from specified ip ranges. The main reason it exists is to manage cloudflare's and stackpath's ip ranges to prevent people from accessing the web server behind the reverse proxy directly by ip. Could be used in case of DDoS attacks or just as a general counter intelligence tool. 


# Features

 - Automatic creation and removal of iptables rules 
 - Self-updating argument for keeping ip ranges up to date for [Cloudflare](https://www.cloudflare.com/ips/) and [Stackpath](https://support.stackpath.com/hc/en-us/articles/360001091666)
 - Works with custom files containing line separated ip ranges in CIDR notation
 - Can be used only on specific ports

## Commands and parameters

    
    Usage: bash whitelist.sh [options]
    
    Options:
	    -r,--remove | Removes the whitelist.
	    -u,--update | Updates the ip lists files.
	    -p,--ports <port1,port2> | Specifies ports delimited by comma, the whitelist to be applied to.
	    -l,--list <path> | Specifies a custom ip list file.

A general example:

    bash whitelist.sh --list cloudflare.list --ports 80,443 
You can even update, remove old and set new rules at once!

    bash whitelist.sh -u -r -l cloudflare.list -p 80,443

## Requirements and dependencies

 - A system running GNU/Linux
 - iptables
 - bash
 - wget (for updating the lists)

## Installation
Just clone this repository and run the script as shown...

## IPtables configuration and advice
**Please note that if you don't specify ports for the whitelist to be applied to it will be applied to all which would effectively block you from connecting remotely via ssh or ftp!**

It might be a good idea to setup a crontab job that updates daily the ipranges in case they change. Here is an example of how you can do that. Just substitute **\<DIR>** with the full path to the directory of the script. **This needs to run with root privileges because of iptables!**

    0  0  *  *  * cd <DIR> && bash whitelist.sh -u -r -l cloudflare.list -p 80

For any additional help consult the documentation of your firewall or check a tutorial on how iptables works. I recommend checking [this one](https://www.booleanworld.com/depth-guide-iptables-linux-firewall/) out. 

# Links and additional info

I don't see how this can be further developed but if you have any ideas you are welcome to [join my discord](https://discord.gg/VMSDGVD) and ask for help or give me a heads up for problems with the script. This was developed entirely for personal use but I figured other people might find it useful as well so any feedback is appreciated!