#!/bin/busybox sh

# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/busybox/default.script
echo "DHCP: $1"
case "$1" in
  bound)
    ip addr add "$ip/$mask" dev eth0
    [ "$mask" = "32" ] && onlink="onlink"
    ip route add default via "$router" dev eth0 $onlink
    for s in $dns; do echo "nameserver $s"; done > /etc/resolv.conf
    ;;
  leasefail)  # only support nocloud network-config version1
    mkdir /cloud-init
    mount -r $(findfs LABEL=cidata) /cloud-init
    eval $(cloud-init-networkcfg /cloud-init/network-config)
    ip addr add "$IP/$PREFIX" dev eth0
    ip route add default via $GATEWAY dev eth0 $ONLINK
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    ip addr show eth0
    ip route show
    ;;
esac
