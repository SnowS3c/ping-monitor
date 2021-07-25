#!/bin/bash

#=====================================================================================
#
#   USAGE
#	- Enter and Q keys close the program
#	- L key to show the log file. Q to exit view
#
#   EXAMPLE
#       ping-monitor.sh enp2s0 08:00:27:77:e8:67 08:00:27:99:17:A3 08:00:27:A0:51:6E
#
#=====================================================================================


# Check root privileges
! [ "$(id -u)" -eq 0 ] && echo "Administrative privileges needed" && exit 1


#=====================================================================================
#
#   GLOBAL VARIABLES
#
#=====================================================================================
ips=()
macs=()
log_file="/var/log/ping-monitor.log"
Cl_end="\e[0m"      # Standard
Cl_bold="\e[01m"    # Bold
Cl_r="\e[31m"       # Red
Cl_v="\e[32m"       # Green verde
Cl_m="\e[33m"       # Brown
Cl_a="\e[34m"       # Blue
Cl_p="\e[35m"       # Purple
Cl_c="\e[36m"       # Cyan
colors=("$Cl_v" "$Cl_m" "$Cl_a" "$Cl_p" "$Cl_c")

export log_file
export Cl_end
export Cl_bold
export Cl_r
export Cl_v
export Cl_m
export Cl_a
export Cl_p
export Cl_c




#=====================================================================================
#   FUNCTION Ctrl_c
#
#   Function to control the program flow
#=====================================================================================
function ctrl_c(){
	tmux kill-session -t ping-session 2>/dev/null
	tput cnorm
	# Write the end of the session in the log file
	echo -e "####################################################################################################\n\n" >> "$log_file"

}

export -f ctrl_c


#=====================================================================================
#   FUNCTION get_ips
#
#	Function to obtain the ip of each machine and save it in the ips array
#=====================================================================================
function get_ips(){
    echo -ne "\t[+] Checking macs and looking for ips..."
    arp_table=$(arp-scan --interface "$interface" -l)
    for id in "${!macs[@]}"; do
        ip=$(echo "$arp_table" | grep -i "${macs[$id]}" | awk {' print $1 '})
        [ "$ip" ] && ips["$id"]="$ip"
    done
    echo "Done!"
}


#=====================================================================================
#   FUNCTION ping_ip
#
#	Execute ping and check if it is correct
#=====================================================================================
function ping_ip(){
	tput civis
	trap ctrl_c 2
    ip="$1"
    mac="$2"
    color="$3"
    icmp_last=0
    error=1             # Error Mode - 1: false  0: true
    no_error_count=0    # Consecutive successful pings
    while read -r line; do
		# Hide the first line of ping
        if [[ "$line" =~ ^PING ]]; then
		   sleep 1
		   clear
		   continue
		fi

		# Current icmp
        icmp=$(echo "$line" | cut -d" " -f 5 | cut -d"=" -f2)

        # Correct Ping
        if [[ "$line" =~ ^64\ bytes ]] && [[ "$icmp" -eq $((icmp_last+1)) ]]; then
            echo -en "[\\${color}${Cl_bold}${ip}${Cl_end}] "

			# If error mode is active, show the ping in red and add 1 to ping counter without error
            if [ "$error" -eq 0 ]; then
			   echo -en "${Cl_r}"
			   ((no_error_count++))
			fi

			# If it takes 30 pings in a row without error, write the end of the error in the log file and modify the value of the error variable to 1(false) and the ping counter without errors to 0.
            if [ "$no_error_count" -eq 30 ]; then
			   echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] [${Cl_bold}\\${color}${mac}${Cl_end}]\t[${Cl_bold}${Cl_r}ERROR END${Cl_end}]" >> "$log_file"
			   error=1
			   no_error_count=0
			fi

			# Show ping
            echo -e "$line${Cl_end}"

        # Failed ping
        else
			# Show ping in red
            echo -e "[\\${color}${Cl_bold}${ip}${Cl_end}] ${Cl_r}$line${Cl_end}"
            no_error_count=0
			# If it was not in error mode, I write in the log file the time of the start of the error and modify the value of the error variable to 0(true), indicating that it is in error mode.
            if [ "$error" -eq 1 ]; then
				echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] [${Cl_bold}\\${color}${mac}${Cl_end}]\t[${Cl_bold}ERROR START${Cl_end}]" >> "$log_file"
				error=0
			fi
        fi

        icmp_last="$icmp"

    done < <(ping -O "$ip")&


	# If you press q or enter, kill the tmux session
	# If you press l, it sends the session to the background and show the log file
    while read -s -n 1 key; do
        [[ "${key,,}" = @("q"|"") ]] && tmux kill-session -t ping-session
        [[ "${key,,}" = "l" ]] && tmux detach-client
    done
}

export -f ping_ip




#=====================================================================================
#
#   CHECK ARGUMENTS
#
#=====================================================================================
# Check if the interface exists
if [ -n "$1" ] && ip a | grep -E "$1:" &>/dev/null; then
	interface="$1"
else
	echo -e "\t[-] Error: the interface doesn't exist"
	exit 2
fi

# Save all the parameters in the array
params=("${@,,}")

# Check if the macs are in valid format
for mac in "${params[@]:1}"; do
    if [[ "$mac" =~ ^(([0-9a-f]){2}:){5}([0-9a-f]){2}$ ]]; then
		macs+=("$mac")
	else
		echo -e "[-] Error: MAC $mac not valid"
		exit 3
	fi
done




#=====================================================================================
#
#	MAIN PROGRAM
#
#=====================================================================================
tput civis
get_ips
tmux new-session -s ping-session -d


# Write the session start dato to the log file
echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] ###################### START PING ############################################" >> "$log_file"

i=0 # counter to select the color of each ip
for id in "${!ips[@]}"; do
    color=${colors[$i]}
    ((i++))
    tmux send-keys "ping_ip ${ips[$id]} ${macs[$id]} $color" C-m
    tmux split-window -h -t ping-session
done
tmux send-keys "exit" C-m

sleep 1
tmux select-layout even-horizontal
tmux attach-session -t ping-session

# In case the tmux session is sent to the background, show the log file
# This loop runs until the tmux session is closed
while tmux list-session | grep ping-session &> /dev/null; do
    less -R +G "$log_file"
    tmux attach-session -t ping-session
done

tput cnorm
# Write the end of the session in the log file
echo -e "####################################################################################################\n\n" >> "$log_file"
