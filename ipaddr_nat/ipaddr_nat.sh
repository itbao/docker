#!/bin/bash
#
#
#

#sysctl -w net.ipv4.ip_forward=1
#iptables -t nat -I PREROUTING -d 192.168.77.39 -j DNAT --to-destination 172.17.0.100

CONF=docker_net.conf
BRIDGE=docker0

init(){
    (ip link set $BRIDGE up) && echo "Up the $BRIDGE Bridge"
    sysctl -w net.ipv4.ip_forward=1
}

config(){
    if [ -n "$1" ]
    then
        NAME=$1
        INTERNAL=`egrep "^$NAME\b" $CONF|awk '{print $2}'`
        INTERNAL_IP=`echo $INTERNAL|cut -d'/' -f1`

        EXTERNAL=`egrep "^$NAME\b" $CONF|awk '{print $3}'`
        NIC=`egrep "^$NAME\b" $CONF|awk '{print $4}'`

        echo "1. Start" `docker start $NAME`

        echo -e "\n2. Set container internal network: $INTERNAL"
        pipework $BRIDGE $NAME $INTERNAL
        (ip link set $NIC up)

        echo -e "\n3. Set netfiler "
        iptables-save |egrep -q "PREROUTING -d $EXTERNAL/32 -j DNAT" && {
        echo "Destination external IP $EXTERNAL has been used! "
        } || {
            iptables -t nat -I PREROUTING -d $EXTERNAL -j DNAT \
            --to-destination $INTERNAL_IP
        }
        iptables-save |egrep -q "POSTROUTING -s $INTERNAL_IP/32 -j SNAT" && {
        echo "Source external IP $EXTERNAL has been used! "
        } || {
            iptables -t nat -I POSTROUTING -s $INTERNAL_IP -j SNAT \
            --to-source $EXTERNAL
        }

        echo -e "\n4. Set NIC external IP: ${EXTERNAL}"
        ip addr add ${EXTERNAL}/32 dev $NIC


    else
        echo "Usage: $0 config CONTAINER_NAME"
    fi
}


case "$1" in
    config)
        config $2
        ;;
    init)
	init
        ;;
    delete|drop)
	:
	;;
  *)
        echo $"Usage: $0 {config|relace}"
        exit 2
esac
