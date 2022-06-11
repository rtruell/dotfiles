#!/usr/bin/env bash

# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#
function valid_ip()
{
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    # original method of getting IP address into an array
    # OIFS=$IFS
    # IFS='.'
    # ip_array=($ip)
    # IFS=$OIFS
    # new method
    IFS='.' ip_array=(${ip[@]})
    # original test line
    # [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    # new test line dealing with possibility of leading zero's in the addresses
    [[ 10#${ip_array[0]} -le 255 && 10#${ip_array[1]} -le 255 && 10#${ip_array[2]} -le 255 && 10#${ip_array[3]} -le 255 ]]
    stat=$?
  fi
  return $stat
}

# If run directly, execute some tests.
if [[ "$(basename $0 .sh)" == 'valid_ip' ]]; then
  ips='
      4.2.2.2
      04.02.02.02
      a.b.c.d
      192.168.1.1
      0.0.0.0
      255.255.255.255
      255.255.255.256
      192.168.0.1
      192.168.0
      1234.123.123.123
      '
  for ip in $ips; do
    if valid_ip $ip; then stat='good'; else stat='bad'; fi
    printf "%-20s: %s\n" "$ip" "$stat"
  done
fi
