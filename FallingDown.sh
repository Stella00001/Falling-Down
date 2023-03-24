# Degrader - a shell script that will continuously add battery cycles in the fastest way possible to get it below 80% health
# Updated Mar 24 2023 10:51 PM EST

if [ $(id -u) -ne 0 ]; then
	echo SCRIPT NOT RUN WITH ROOT
	echo PLEASE RUN USING
	echo "----> sudo ./Degrader.sh"
	exit
fi

echo $(date): Checking for Xcode CLI tools. Needed for later steps.
xcode-select -p &> /dev/null
if [ $? -ne 0 ]; then
	xcodecli=1
        echo $(date): Did not find Xcode CLI. Installing.
        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
        PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
	echo "Prod: ${PROD}"
        softwareupdate -i "$PROD" --verbose;
else
	xcodecli=0
        echo $(date): Xcode CLI tools detected. Skipping install process for it.
fi

cd ~/Desktop
if [ -f "switch" ]; then
	echo $(date): Smart Plug control software detected on Desktop, skipping download and compile steps.
else
	echo $(date): 'Downloading Smart Plug control SW to desktop from github.com/jkbenaim/hs100 (thank you jkbenaim!)'
	git clone https://github.com/jkbenaim/hs100.git
	cd hs100
	echo $(date): Compiling control software
	make &> /dev/null
	echo $(date): Moving control software to desktop
	cp hs100 ../switch
	cd ..
	echo $(date): Removing extra files
	rm -rf hs100
fi

echo $(date): Switching Wi-Fi network to Smart Plugs locally broadcast network
networksetup -setairportnetwork en0 "TP-LINK_Smart Plug_DD75"

echo $(date): running Caffeinate to prevent sleeping
caffeinate -di &
cores=$(sysctl -n hw.ncpu)
health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)

echo $(date): $cores Logical Cores found! This will dictate how many YES instances start.
if [ $battery -gt 5 ] && [ $(ps -ef | grep -c yes) -eq 1 ]; then
	echo $(date): Battery is partially charged, starting yes to drain, cutting power
	if [[ $(./switch 192.168.0.1 off > /dev/null) -eq 0 ]]; then
		echo $(date): Smart Plug Relay state set to OFF
	else
		echo $(date): Error switching Relay State. Exit code $?
		exit
	fi
	pmset -a lowpowermode 0
	echo $(date): Low Power Mode Disabled!
	for i in $(seq $cores);do 
		(yes > /dev/null &) 
	done
	echo $(date): Starter YES instances started!
	delay=300
fi

while (($health > 75)); do
	battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
	if (($battery > 90 )); then
		echo $(date): Battery High state detected. Time to cut power!
		if [[ $(./switch 192.168.0.1 off > /dev/null) -eq 0 ]]; then
			echo $(date): Smart Plug Relay state set to OFF
		else
			echo $(date): Error switching Relay State. Exit code $?
			exit
		fi
		pmset -a lowpowermode 0
		echo $(date): Low Power Mode Disabled!
		while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "Yes" ]]; do
			echo $(date): Waiting for System to update its Charger status
			sleep 20
		done
		if [ $(ps -ef | grep -c yes) -eq 1 ]; then
			for i in $(seq $cores);do 
				(yes > /dev/null &) 
			done
			echo $(date): YES instances started!
		else
			echo $(date): Found some YES instances already running, skipping adding more.
		fi
		delay=600
	elif (($battery < 10)); then
		echo $(date): Battery Low state detected.
		if [[ $(ps -ef | grep -c yes) -ne 1 ]]; then
			echo $(date): Killing all YES processes
			sudo killall yes &> /dev/null
			echo $(date): YES instances killed, time to charge!
		fi
		pmset -a lowpowermode 1
		echo $(date): Low Power Mode enabled!
		if [[ $(./switch 192.168.0.1 on > /dev/null) -eq 0 ]]; then
			echo $(date): Smart Plug Relay state set to ON
		else
			echo $(date): Error switching Relay State. Exit code $?
			exit
		fi
		while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "No" ]]; do
			echo $(date): Waiting for System to update its Charger status
			sleep 20
		done
		delay=600
	else
		if [[ $(ps -ef | grep -c yes) -eq 1 ]]; then
			while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "No" ]]; do
				echo $(date): Machine should be CHARGING! Why is it unplugged? Plug it in to continue.
				sleep 30
			done
		fi
	fi

	health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
	cycle=$(system_profiler SPPowerDataType | awk '/Cycle/{print $3}')
	echo $(date): Battery is at $battery percent, $health health, and $cycle cycles. Checking again in $(($delay / 60)) mins!
	sleep $delay
done

echo $(date): Degrading complete! Performing cleanup.
killall caffeinate
killall yes
echo $(date): all Yes and Caffeinate instances killed.
if [ $xcodecli -eq 0 ]; then
	sudo rm -rf /Library/Developer/CommandLineTools
	echo $(date): Our downloaded Xcode-CLI is now removed
fi
networksetup -setnetworkserviceenabled Wi-Fi off && sleep 15 && networksetup -setnetworkserviceenabled Wi-Fi on
echo $(date): Smart Plugs Wi-Fi network disconnected. 
 
exit 0
###Save for later
#osascript -e 'display notification "UNPLUG ME" with title "DEGRADER" sound name "Crystal"'
