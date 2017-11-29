#!/bin/bash
ATFTP="${0%/*}/../3rdparty/atftp/atftp"

tftp_server='127.0.0.1'
client_count='300'
tftp_timeout=1
remote_file="/boot/vmlinuz-`uname -r`"
logfile="run-`date +%Y%m%d%H%M`.log"
FAIL=0

while getopts ":s:t:f:c:" opt; do
	case $opt in
		s)
			tftp_server="$OPTARG"
			;;
		c)
			client_count="$OPTARG"
			;;
		t)
			tftp_timeout="$OPTARG"
			;;
		f)
			remote_file="$OPTARG"
			;;
	esac
done

echo "starting $client_count tftp clients"

for i in `seq 1 $client_count`; do
	time $ATFTP --tftp-timeout=${tftp_timeout} \
		--get --local-file /dev/null \
		--remote-file ${remote_file} \
		${tftp_server} &
done > "$logfile" 2>&1

echo "waiting for clients to complete"
for job in `jobs -p`; do wait $job || let "FAIL+=1"; done

if [ "$FAIL" != '0' ]; then
	echo "$FAIL clients failed, see $logfile for details" >&2
	exit 1
fi

