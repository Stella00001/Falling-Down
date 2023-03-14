# Degrader - a shell script that will continuously add battery cycles in the fastest way possible to get it below 80% health
# Updated Mar 13 2023 10:51 PM EST

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
echo $(date): Downloading Smart Plug control SW to desktop from github.com/jkbenaim/hs100 (thank you jkbenaim!)
git clone https://github.com/jkbenaim/hs100.git
cd hs100
echo $(date): Compiling control software
make &> /dev/null
echo $(date): Moving control software to desktop
cp hs100 ../switch
cd ..
echo $(date): Removing extra files
rm -rf hs100

echo $(date): Switching Wi-Fi network to Smart Plugs locally broadcast network
networksetup -setairportnetwork en0 "TP-LINK_Smart Plug_DD75"

echo $(date): running Caffeinate to prevent sleeping
caffeinate -di &
cores=$(sysctl -n hw.ncpu)
health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)

echo $(date): $cores Logical Cores found!
if [ $battery -gt 10 ] && [ $battery -lt 90 ]; then
	echo $(date): Battery is partially charged, starting yes to drain, cutting power
	./switch 192.168.0.1 off
	seq $cores | xargs -I{} -P $cores yes > /dev/null &
	echo $(date): $cores YES instances started!
fi

while (($health > 79)); do
	battery=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
	if (($battery > 90 )); then
		echo $(date): Battery High state detected. Time to cut power!
		while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "Yes" ]]; do
			#osascript -e 'display notification "UNPLUG ME" with title "DEGRADER" sound name "Crystal"'
			./switch 192.168.0.1 off
			sleep 10
		done
		seq $cores | xargs -I{} -P $cores yes > /dev/null &
		echo $(date):  $cores YES instances started!
	elif (($battery < 10)); then
		echo $(date): Battery Low state detected. Killing yes!
		if [[ $(ps -ef | grep -c yes) -ne 1 ]]; then
			echo $(date): Killing all YES processes
			killall yes > /dev/null
		fi
		echo $(date): yes instances killed, time to charge!
		while [[ $(system_profiler SPPowerDataType | awk '/Charging/ {print $2;exit}') == "No" ]]; do
			#osascript -e 'display notification "PLUG ME IN" with title "DEGRADER" sound name "Crystal"'
			./switch 192.168.0.1 on
			sleep 10
		done
	fi

	health=$(ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.0f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}')
	cycle=$(system_profiler SPPowerDataType | awk '/Cycle/{print $3}')
	echo $(date): Battery is at $battery percent with $health health and $cycle cycles. Checking machine in 2 mins!
	sleep 60
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
