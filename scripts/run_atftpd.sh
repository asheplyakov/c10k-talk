#!/bin/sh
set -e
cd "${0%/*}/.."
set -x
exec ./3rdparty/atftp/atftpd \
	--logfile - \
	-m 500 \
	--daemon \
	--no-fork \
	--no-multicast \
	/boot

