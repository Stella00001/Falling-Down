# Falling-Down
macOS Battery Degredation Script

Purpose is self-explanatory. It is designed to automate the process of adding battery charge cycles for the purpose of testing degredation. 
At this stage its mostly-automated but I do still consider it Beta, use at your own risk. 

If you want to use it, do yourself a favor and buy a TP-Link HS103 Smart Plug, or any plug from the repo listed below. it will make life way easier.

Script isnt yet made to automatically detect your plugs SSID so just replace that prior to running. The rest should be taken care of, generally. 

TODO:
- Automatic detection of plugs unique SSID
- Better Error-checking on some stages (In-progress)
- ~~Toggle Low Power Mode on/off
- Possible display max/min brightness control to speed up process?
- Ability to toggle between full-auto with smart plug and semi-auto (manual plug/unplug) without smart plug
- Checking if a smart plug is detected, and if not, switch to semi-auto
- TBD?

Thanks to jkbenaim for their hs100 binary, which makes the charging automation steps possible. Refer to their repo for full list of supported devices.
