#!/bin/bash
set -ex
if [ "$1" != --do-the-thing ]; then
    exit 1
fi

if [ ! -f /boot/pikvm.txt ]; then
	exit 0
fi
source <(dos2unix < /boot/pikvm.txt)

rw

if [ -n "$FIRSTBOOT" ]; then
	( \
		(umount /etc/machine-id || true) \
		&& echo -n > /etc/machine-id \
		&& systemd-machine-id-setup \
	) || true

	rm -f /etc/ssh/ssh_host_*
	ssh-keygen -v -A

	rm -f /etc/kvmd/nginx/ssl/*
	rm -f /etc/kvmd/vnc/ssl/*
	kvmd-gencert --do-the-thing
	kvmd-gencert --do-the-thing --vnc

	if grep -q 'X-kvmd\.otgmsd' /etc/fstab; then
		umount /dev/mmcblk0p3
		parted /dev/mmcblk0 -a optimal -s resizepart 3 100%
		yes | mkfs.ext4 -F -m 0 /dev/mmcblk0p3
		mount /dev/mmcblk0p3
	fi

	# fc-cache is required for installed X server
	which fc-cache && fc-cache || true
fi

# Set the regulatory domain for wifi, if defined.
if [ -n "$WIFI_REGDOM" ]; then
	sed -i \
			-e 's/^\(WIRELESS_REGDOM=.*\)$/#\1/' \
			-e 's/^#\(WIRELESS_REGDOM="'$WIFI_REGDOM'"\)/\1/' \
		/etc/conf.d/wireless-regdom
fi

# If the WIFI_ESSID is defined, configure wlan0
if [ -n "$WIFI_ESSID" ]; then
	WIFI_IFACE="${WIFI_IFACE:-wlan0}"
	_config="/etc/netctl/$WIFI_IFACE-${WIFI_ESSID/ /_}"
	cat <<end_wifi_config > "$_config"
Description='Generated by Pi-KVM bootconfig service'
Interface='$WIFI_IFACE'
Connection=wireless
Security=wpa
ESSID='$WIFI_ESSID'
IP=dhcp
Key='$WIFI_PASSWD'
end_wifi_config
	systemctl enable "netctl-auto@${WIFI_IFACE}.service" || true
fi

rm -f /boot/pikvm.txt
ro

[ -n "$REBOOT" ] && reboot
