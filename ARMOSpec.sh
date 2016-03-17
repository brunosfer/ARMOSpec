#!/bin/bash
#title          :ARMOSpec.sh
#description    :Prints Raspberry Pi Info, CPU Info, uSD card Registers.
#author			:Bruno Fernandes {bruno.s.fernandes@gmail.com}
#date           :17-03-2016
#version        :1
#usage			:./ARMOSpec.sh
#notes          :
#==============================================================================

sample="10"							# Sample rate in Seconds
DELIVER_TO_IP=127.0.0.1				# IP or Host where the data should be delivered
DELIVER_TO_PORT=54321				# PORT where the data should be delivered
timestamp=$(date -u "+%F_%H-%M-%S")	# Logfile extension name with timestamp
LOGFILE="$HOME/log_$timestamp.txt"	# Logfile pathname

# Trap Signals
trap close SIGINT SIGTERM

close() {
	shut="shut"
	echo "$0 is shutting down."
}

show_time() {
	num=$1
	min=0
	hour=0
	day=0
	if((num>59));then
		((sec=num%60))
		((num=num/60))
		if((num>59));then
			((min=num%60))
			((num=num/60))
			if((num>23));then
				((hour=num%24))
				((day=num/24))
			else
				((hour=num))
			fi
		else
		((min=num))
		fi
	else
		((sec=num))
	fi
}

convert_to_MHz() {
	let value=$1/1000
	echo "$value"
}

overvoltage() {
	let overvolts=${1#*.}-20
	echo "$overvolts"
}

rpi_revision() {
	local pirev=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed 's/^1000//')
	local pirevpn
	case $pirev in
		0002)			pirevpn="Model B Revision 1.0 256MB RAM" ;;
		0003)			pirevpn="Model B Revision 1.0 + ECN0001 (no fuses, D14 removed) 256MB RAM" ;;
		0004|0005|0006)	pirevpn="Model B Revision 2.0 256MB RAM" ;;
		0007|0008|0009)	pirevpn="Model A 256MB RAM" ;;
		000d|000e|000f)	pirevpn="Model B Revision 2.0 512MB RAM" ;;
		0010)			pirevpn="Model B+ 512MB RAM" ;;
		0011)			pirevpn="Compute Module 512MB RAM" ;;
		0012)			pirevpn="Model A+ 256MB RAM" ;;
		a01041)			pirevpn="Pi 2 Model B 1GB RAM (Sony, UK)" ;;
		a21041)			pirevpn="Pi 2 Model B 1GB RAM (Embest, China)" ;;
		900092)			pirevpn="PiZero 512MB RAM" ;;
		a02082)			pirevpn="Pi 3 Model B 1GB RAM" ;;
		*)				pirevpn="N/A" ;;
	esac
#	pirevpn="N/A"		# DEBUG Purposes
	echo "$pirevpn"
}

cpu_call() {
	pi_cpu_temp=$(vcgencmd measure_temp)
	pi_cpu_temp=${pi_cpu_temp:5:4}
	pi_cpu_volts=$(vcgencmd measure_volts core)
	pi_cpu_volts=${pi_cpu_volts:5:4}
	#[ $pi_cpu_volts != "1.20" ] && { overvolts=$(overvoltage $pi_cpu_volts); }
	pi_cpu_minFreq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)
	pi_cpu_minFreq=$(convert_to_MHz $pi_cpu_minFreq)
	pi_cpu_maxFreq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
	pi_cpu_maxFreq=$(convert_to_MHz $pi_cpu_maxFreq)
	pi_cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
	pi_cpu_freq=$(convert_to_MHz $pi_cpu_freq)
	# Processing the current CPU usage
	pi_cpu_idle=$(vmstat 2 3 | tail -n1 | sed "s/\ \ */\ /g" | cut -d' ' -f 16)
	pi_cpu_usage=$(( 100 - pi_cpu_idle ))
}

rpi_call() {
	pi_rev=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed 's/^1000//')
	pi_rev_prettyname=$(rpi_revision)
	pi_hw=$(cat /proc/cpuinfo | grep 'Hardware' | awk '{print $3}' | sed 's/^1000//')
	pi_sn=$(cat /proc/cpuinfo | grep 'Serial' | awk '{print $3}' | sed 's/^1000//')
	pi_fwver=$(/opt/vc/bin/vcgencmd version)
	pi_fwrpiupdate=$(cat /boot/.firmware_revision)
	pi_kernelver=$(uname -rv)
	pi_osversion=$(cat /etc/os-release | grep 'PRETTY_NAME=' | grep -o '".*"' | sed 's/"//g')

	### DEACTIVATED BY NOW ###
	# The under voltage uses the gpio and requires wiringPi library.
	# This has to be tested before, otherwise it can conflicts with existing libs.
	# Reading undervoltage PIN
	##unvolt=$(sudo raspi-gpio get 35)
	#under_voltage=$(sudo gpio -g read 35)
}

usd_call() {
	# Consider to parse the CID string instead reading registers individualy
	usd_cid=$(cat /sys/block/mmcblk0/device/cid)				# Card Identification Register (HEX)
	usd_cid_manfid=$(cat /sys/block/mmcblk0/device/manfid)		# Manufacturer ID (Binary)
	usd_cid_oemid=$(cat /sys/block/mmcblk0/device/oemid)		# OEM / Application ID (ASCII)
	usd_cid_name=$(cat /sys/block/mmcblk0/device/name)			# Product Name (ASCII)
	usd_cid_hwrev=$(cat /sys/block/mmcblk0/device/hwrev)		# Product Revision (Decimal) Hardware Revision
	usd_cid_fwrev=$(cat /sys/block/mmcblk0/device/fwrev)		# Product Revision (Decimal) Firmware Revision
	usd_cid_serial=$(cat /sys/block/mmcblk0/device/serial)		# Product Serial Number (Decimal)
	usd_cid_date=$(cat /sys/block/mmcblk0/device/date)			# Manufacturing Date (Decimal Format: YYM)

	usd_csd=$(cat /sys/block/mmcblk0/device/csd)				# Card Specific Data Register
	usd_scr=$(cat /sys/block/mmcblk0/device/scr)				# SD CARD Configuration Register

	usd_type=$(cat /sys/block/mmcblk0/device/type)				# Card Type
	usd_size=$(cat /sys/block/mmcblk0/device/block/mmcblk0/size)	# size in blocks of 512. I have to read blocksize to calculate uSD card size.
	usd_part2_size=$(cat /sys/block/mmcblk0/device/block/mmcblk0/mmcblk0p2/size) 	# Should I read the partition folder or the size to know if it exists?
}

print_to_human() {
	[ -n "$pi_rev" ] && echo "Raspberry Pi Revision: $pi_rev"
	[ -n "$pi_rev_prettyname" ] && echo "Raspberry Pi Revision (Human Readable): $pi_rev_prettyname"
	[ -n "$pi_hw" ] && echo "Raspberry Pi Hardware Revision: $pi_hw"
	[ -n "$pi_sn" ] && echo "Raspberry Pi Serial Number: $pi_sn"
	[ -n "$pi_fwver" ] && echo "Raspberry Pi Firmware Version: $pi_fwver"
	[ -n "$pi_fwrpiupdate" ] && echo "Raspberry Pi Firmware Version (rpi-update): $pi_fwrpiupdate"
	[ -n "$pi_kernelver" ] && echo "Raspberry Pi Kernel Version: $pi_kernelver"
	[ -n "$pi_osversion" ] && echo "Raspberry Pi OS Version: $pi_osversion"

	[ -n "$pi_cpu_temp" ] && echo "CPU Temperature: $pi_cpu_temp C"
	[ -n "$pi_cpu_volts" ] && echo "CPU Voltage: $pi_cpu_volts V"
	[ -n "$pi_cpu_minFreq" ] && echo "CPU Min Frequency: $pi_cpu_minFreq MHz"
	[ -n "$pi_cpu_maxFreq" ] && echo "CPU Max Frequency: $pi_cpu_maxFreq MHz"
	[ -n "$pi_cpu_freq" ] && echo "CPU Current Frequency: $pi_cpu_freq MHz"
	[ -n "$pi_cpu_usage" ] && echo "CPU Usage: $pi_cpu_usage%"
	#[ $overvolts ] && echo "CPU (+0.$overvolts overvolt)" || echo -e "\r"

	[ -n "$usd_cid" ] && echo "uSD Card Identification Register: $usd_cid"
	[ -n "$usd_cid_manfid" ] && echo "uSD Card Manufacturer ID: $usd_cid_manfid"
	[ -n "$usd_cid_oemid" ] && echo "uSD Card OEM/Application ID: $usd_cid_oemid"
	[ -n "$usd_cid_name" ] && echo "uSD Card Product Name: $usd_cid_name"
	[ -n "$usd_cid_hwrev" ] && echo "uSD Card Product Hardware Revision: $usd_cid_hwrev"
	[ -n "$usd_cid_fwrev" ] && echo "uSD Card Product Firmware Revision: $usd_cid_fwrev"
	[ -n "$usd_cid_serial" ] && echo "uSD Card Product Serial Number: $usd_cid_serial"
	[ -n "$usd_cid_date" ] && echo "uSD Card Manufacturing Date: $usd_cid_date"

	[ -n "$usd_csd" ] && echo "uSD Card Specific Data Register: $usd_csd"
	[ -n "$usd_scr" ] && echo "uSD Card SD CARD Configuration Register: $usd_scr"
	[ -n "$usd_type" ] && echo "uSD Card Type: $usd_type"
	#[ -n "$usd_size" ] && echo "uSD Card $usd_size"
	#[ -n "$usd_part2_size" ] && echo "uSD Card $usd_part2_size"
}

# http://jsonviewer.stack.hu/
# JSON Format according (RFC 4627)
print_to_json() {
	printf '[ { "Started": "%s", "Finished": "%s", "Endured": "%s" }, { "Raspberry Pi": [ { "Revision": "%s", "Revision (Human Readable)": "%s", "Hardware Revision": "%s", "Serial Number": "%s", "Firmware Version": "%s", "Firmware Version (rpi-update)": "%s", "Kernel Version": "%s", "OS Version": "%s" } ] }, { "CPU": [ { "Temperature": "%s", "Voltage": "%s", "Frequency": [ { "Min": "%s", "Max": "%s", "Current": "%s" } ], "Usage": "%s" } ] }, { "uSD Card": [ { "CID": [ { "CID": "%s", "Manufacturer ID": "%s", "OEM/Application ID": "%s", "Product Name": "%s", "Product Hardware Revision": "%s", "Product Firmware Revision": "%s", "Product Serial Number": "%s", "Manufacturing Date": "%s" } ], "CSD": "%s", "SCR": "%s", "Type": "%s" } ] } ]\n' "$now" "$final_date" "$dif"	"$pi_rev" "$pi_rev_prettyname" "$pi_hw" "$pi_sn" "$pi_fwver" "$pi_fwrpiupdate" "$pi_kernelver" "$pi_osversion" "$pi_cpu_temp" "$pi_cpu_volts" "$pi_cpu_minFreq" "$pi_cpu_maxFreq" "$pi_cpu_freq" "$pi_cpu_usage" "$usd_cid" "$usd_cid_manfid" "$usd_cid_oemid" "$usd_cid_name" "$usd_cid_hwrev" "$usd_cid_fwrev" "$usd_cid_serial" "$usd_cid_date" "$usd_csd" "$usd_scr" "$usd_type"
}

log_to_file() {
	echo "Log File Started - $(date)" >$LOGFILE
	echo "$1" >>$LOGFILE
}

log_to_socket() {
#	echo "$1" > /dev/tcp/127.0.0.1/54321	# Redirect output to localhost port.
	echo "$1" > /dev/tcp/$DELIVER_TO_IP/$DELIVER_TO_PORT	# Redirect output to specific IP ADDR and PORT. TEST in host: nc -k -l 54321
#	echo "$1" > eval 'exec 3<>/dev/tcp/127.0.0.1/54321' 2>
}

################ 			MAIN 			################

# Raspberry Revision Validation
if [ "$(rpi_revision)" == "N/A" ]; then
	echo "Please run this script in a Raspberry Pi!"
	exit 1
else
	now=$(date -u +%s)											# Current time
	start_date=$(date "+%F %H:%M:%S" -ud @date -ud @$now)		# Date in human readable format
	echo "Sarted: $start_date"

	while [ -z "$shut" ]	# Stops while and ends the program when detects a signal (Ctrl C or Shutdown) (Ex. kill -2 <PID>)
	do
		final_date=$(date -u +%s)			# The Final Date is being constantly updated. ( -u for UTC Time )
		dif=$((final_date-now))				# Shows in unixtime (seconds) how long the DCU was active.
		show_time $dif 						# This function translate seconds to days, hours, min, sec.
		sleep $sample 						# This is a timer for sampling rate.
		cpu_call							# This function calls CPU information
		rpi_call							# This function calls Raspberry Pi information
		usd_call							# This function calls SD Card Registers (CID, CSD, SCR, Type)
		print_to_human						# DEBUG Purposes. Shows friendly output on console.
	#	print_to_json						# DEBUG Purposes. Shows JSON format output on console.
		log_to_file "$(print_to_json)"		# Sends output to log file.
	#	log_to_socket "$(print_to_json)"	# Sends output to specific PORT and IP ADDR.
		echo "Finished: $(date "+%F %H:%M:%S" -ud @date -ud @$final_date)"		# Date in human readable format
		echo "Endured:" "$day"d "$hour"h "$min"m "$sec"s
	done
fi
exit $?										# Will exit with status of last command.