# Degrader - a shell script that will continuously add battery cycles in the fastest way possible to get it below 80% health. Everything apart from charging is automated

###################################################
############### defining functions ################
###################################################

function health()  ### pulls the battery health, checks if over 80%, returns true or false. ~3% off from MacOS reported value
{
	local health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
	local cycle=$(system_profiler SPPowerDataType | grep "Cycle Count" | awk '{print $3}')
	echo Battery has $cycle cyeles!
	if (( $health > 80 ))
	then
		return 0
	else
		return 1
	fi
}
function start_yes() ### starts '/yes > /dev/null &' instances based on # of logical cores
{
	seq $cores | xargs -I{} -P $cores yes > /dev/null
	echo $(date)--- $cores X YES started!

}
function chgr_state() ### pulls the "charging? Y/N" state of machine and returns either true or false
{
	if [[ $(system_profiler SPPowerDataType | grep -m 1 'Charging' | awk '{print $2}') == 'Yes' ]]
	then
		return 0 # charger
	else
		return 1 # battery
	fi
}
function batt_perc() ### Pulls the current battery charge % and provides a return code for its state (high, low, middle)
{
	local battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
	if [[ $battery -ge 90 ]]
	then
		return 0 # high
	elif [[ $battery -le 15 ]]
	then
		return 1 # low
	else
		return 2 # med
	fi
}
function kill_yes() ### checks if 'yes' process is running and kills it if it is
{
	if [[ $(ps -ef | grep -c yes) -ne 1 ]]
	then
		echo $(date)--- Killing all YES processes
		killall yes > /dev/null
	fi
}
function notify()
{
	sleep 30
	if [[ $1 == "plug" ]]
	then
		osascript -e 'display notification "PLUG ME IN" with title "DEGRADER" sound name "Submarine"'
	elif [[ $1 == "unplug" ]]
	then
		osascript -e 'display notification "UNPLUG ME" with title "DEGRADER" sound name "Submarine"'
	fi
}

function sunlight()
{
	echo $(date) Setting max brightness
	for x in {1..15};
	do
		osacript -e ‘tell application “System Events”‘ -e ‘key code 145’ -e ‘end’
	done
}

function darkness()
{
	echo $(date) setting low brightness
	for x in {1..10};
	do
		osacript -e ‘tell application “System Events”‘ -e ‘key code 144’ -e ‘end’
	done
}

#############################################	
################ main script ################
#############################################

kill_yes
cores=$(sysctl -n hw.ncpu)
echo $(date)--- $cores Logical Cores found! Starting $cores yes instances.

if [[ batt_perc -eq 0 ]] || [[ batt_perc -eq 2 ]]
then
	echo $(date) Starting initial yes instances! 
	start_yes()
	sunlight()
fi
#loops=0

while health == 0
do	
	#((loops += 1))
	if batt_perc == 0
	then
		while chgr_state == 0
		do
			notify unplug
		done
		kill_yes
		sunlight()
		start_yes		
	elif batt_perc == 1
	then
		kill_yes
		darkness()
		while chgr_state == 1
		do
			notify plug
		done
	fi
	echo $(date)--- Checking machine state in 5 mins!
	sleep 300
done



