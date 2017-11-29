#!/bin/sh
set -e
cd "${0%/*}/.."
set -x
ulimit -n 32768
exec ./astftpd/astftpd \
	/boot/vmlinuz-`uname -r`
