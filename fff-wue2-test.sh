#!/bin/bash

export LANG=C
export LC_ALL=C

while read -r line; do
      line=$(echo "$line" | tr -d '\r\n')

      if echo "$line" | grep -qE '^GET /' # if line starts with "GET /"
      then
        REQUEST=$(echo "$line" | cut -d ' ' -f2) # extract the request
      elif [ -z "$line" ] # empty line / end of request
      then
        # Warten abbrechen ;)
        break
      fi
done

errors="";

load=`cat /proc/loadavg | cut -f2 -d" " | cut -f1 -d"."`
if [ $load -gt 2 ]; then
        errors="${errors}Zu hohe load ($load)!\r\n"
fi

hdd="/dev/sda1"
belegt=`df|grep $hdd|head -n 1|tr -s [:blank:]| cut -f5 -d" " | sed s/%// `
if [ "$belegt" -gt 95 ]; then
        errors="${errors}$hdd ist zu voll ($belegt%)!\r\n"
fi

for port in 25 53 67 80 6696 10004 10007 10008 10009 33123 63332; do
    if [ `netstat -l -p -n 2>/dev/null| grep ":$port " | wc -l` -eq 0 ]; then
        errors="${errors}Port $port ist nicht erreichbar!\r\n"
    fi
done

url="http://fff2.mifritscher.de"
wget -q -O - $url >/dev/null
if [ $? -ne 0 ]; then
        errors="${errors}Url $url ist nicht erreichbar!\r\n"
fi

ifaces="fff-wue1 10.83.128.1 10.83.132.1 10.83.136.1 10.83.228.3"
for iface in $ifaces; do
    ping -c 1 -q -I $iface 8.8.8.8 >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        errors="${errors}Komme nicht von Freifunk ($iface) aus nach draussen!\r\n"
    fi
done

ping -c 1 -q fd43:5602:29bd:ffff::feee >/dev/null 2>&1
if [ ! $? -eq 0 ]; then
    errors="${errors}Komme nicht auf fd43:5602:29bd:ffff::feee (FW-Server von fblaese)!\r\n"
fi

dnsservers="127.0.0.1 10.83.252.7"
for dnsserver in $dnsservers; do
    dig @$dnsserver mifritscher.de >/dev/null 2>&1
    if [ ! $? -eq 0 ]; then
        errors="${errors}DNS Aufloesung klappt nicht (Server $dnsserver)!\r\n"
    fi
done


length=${#errors};

if [ $length -eq 0 ]; then
    echo -e -n "HTTP/1.0 200 OK\r\nConnection: close\r\nContent-Length:15\r\n\r\nServer is OK!\r\n"
else
    httpLength=`expr 21 + $length`
    #Hack, wenn sich Bash verzaehlt...
    echo -e -n "HTTP/1.0 200 OK\r\nConnection: close\r\nContent-Length:$httpLength\r\n\r\nServer is NOT OK!\r\n\r\n$errors                                                         "
fi

