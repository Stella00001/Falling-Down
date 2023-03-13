# Degrader - a shell script that will continuously add battery cycles in the fastest way possible to get it below 80% health. Everything apart from charging is automated

caffeinate -di &
cores=$(sysctl -n hw.ncpu)
health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
echo $(date)--- $cores Logical Cores found!
if [ $battery -gt 10 ] && [ $battery -lt 90 ]; then
	echo $(date)--- Battery charge Mid, starting yes to drain
	seq $cores | xargs -I{} -P $cores yes > /dev/null &
	echo $(date)--- $cores X YES started!
fi
while (($health > 79)); do
	battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
	if (($battery > 90 )); then
		echo $(date)--- Battery High state detected. Unplug Charger!
		while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "Yes" ]]; do
			osascript -e 'display notification "UNPLUG ME" with title "DEGRADER" sound name "Crystal"'
			sleep 20
		done
		seq $cores | xargs -I{} -P $cores yes > /dev/null &
		echo $(date)--- $cores X YES started!
	elif (($battery < 10)); then
		echo $(date)--- Battery Low state detected. Killing yes
		if [[ $(ps -ef | grep -c yes) -ne 1 ]]; then
			echo $(date)--- Killing all YES processes
			killall yes > /dev/null
		fi
		echo $(date)--- yes instances killed, plug in charger!
		while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "No" ]]; do
			osascript -e 'display notification "PLUG ME IN" with title "DEGRADER" sound name "Crystal"'
			sleep 20
		done
	fi
	health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
	cycle=$(system_profiler SPPowerDataType | awk '/Cycle/{print $3}')
	echo $(date)--- Battery is at $battery percent with $health health and $cycle cycle
	echo $(date)--- Checking machine state in 2 mins!
	sleep 120
done
killall caffeinate
killall yes
exit 0

# github.com/jkbenaim/hs100 script for controlling kasa smarthome shit with CLI. Setup TPlink HS103 later
