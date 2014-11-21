#!/bin/bash
# This script constructs the list of DHCP Host Name and their IP Address list.
# Tested server OS : Ubuntu 12.04
# Tested client OS : Ubuntu 12.04, CentOS 6.5, Windows 7
# 
# The dhcp client has to send "Hostname option" to make this system work, 
#    Ubuntu 12.04 LTS add this option automatically, Windows OSes also,
#    But CentOS 6.5 didn't add this option unless I did following setup:
#      open /etc/sysconfig/network-scripts/ifcfg-[interface name], then add a line with 
# DHCP_HOSTNAME=your_host_name(you may copy from /etc/sysconfig/network)
#      .
#    In my situation, My CentOS VM guest had an old ifcfg-eth0 script accidentally, in such case, 
#    NetworkManager does not save its own settings under /etc/sysconfig/network-scripts directory.
#    After I deleted old ifcfg-eth0 script, I found the ifcfg-Auto_eth1 script emerged under 
#    /etc/sysconfig/network-scripts directory(believe me, that was not a day dream).
#    
DBNAME=dhcpdata.db
TABLENAME=maclist
NETWORKDEVICE=eth0
 
sqlite3 $DBNAME "create table if not exists $TABLENAME (hwaddr primary key, hostname, ipaddr, updtime)"
 
tcpdump -i $NETWORKDEVICE -n port 67 and port 68 -v -l | (
    while true;
    do
        read aline
        if echo $aline | egrep -e '^[0-9]' > /dev/null 2>&1 ;then
# delimiter found
                DHCPMSGOPT=
                IPADDR=
                ETHADDR=
                HOSTNAME=
        else
                if [ "$DHCPMSGOPT" == "" ];then
                    DHCPMSGOPT=`echo $aline | grep 'DHCP-Message Option' | sed -e 's/[  ]*DHCP-Message Option.*: //'`
                fi
                if [ "$IPADDR" == "" ];then
                     IPADDR=`echo $aline | grep 'Your-IP' | sed -e 's/[     ]*Your-IP[  ]*//'`
                fi
                if [ "$IPADDR" == "" ];then
                     IPADDR=`echo $aline | grep 'Requested-IP' | sed -e 's/[    ]*Requested-IP[^:]*: //'`
                fi
                if [ "$IPADDR" == "" ];then
                    IPADDR=`echo $aline | grep 'Client-IP ' | sed -e 's/[   ]*Client-IP //'`
                fi
                if [ "$ETHADDR" == "" ];then
                    ETHADDR=`echo $aline | grep 'Client-Ethernet-Address' | sed -e 's/^[       ]*//' | cut -f 2 -d' ' | sed -e 's/://g' | awk '{print toupper($1)}'`
                fi
                if [ "$HOSTNAME" == "" ];then
                    HOSTNAME=`echo $aline | grep 'Hostname Option' | sed -e 's/^[       ]*//' | cut -f 6 -d' ' | sed -e 's/"//g'`
                fi
                if [ "$ETHADDR" != "" -a "$HOSTNAME" != "" ];then
                    sqlite3 $DBNAME "insert or replace into  $TABLENAME (hostname, hwaddr) values (\"$HOSTNAME\", \"$ETHADDR\")"
                    echo $DHCPMSGOPT : $ETHADDR : $HOSTNAME
                fi
                if [ "$ETHADDR" != "" -a "$IPADDR" != "" ];then
                    now=`date`
                    sqlite3 $DBNAME "update  $TABLENAME set ipaddr = \"$IPADDR\", updtime = \"$now\" where hwaddr = \"$ETHADDR\""
                    echo $DHCPMSGOPT : $ETHADDR : $IPADDR
                fi
        fi
    done
)