#!/bin/sh
set -e
cd "${0%/*}/.."
set -x
exec $onload ./3rdparty/atftp/atftpd \
	--logfile - \
	--verbose=0 \
	-m 2000 \
        --user `whoami`.`whoami` \
	--daemon \
	--no-fork \
	--no-multicast \
	/boot

