#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

origname=${1}
fullpath=`echo ${origname%/*.*}`
fullname=`echo ${origname##/*/}`
ext=`echo ${fullname##*.}`
oldname=`echo ${fullname%%-*}`
char=`echo ${fullname#*-}`
char=`echo ${char%.*}`
datetime=`printf $(date +%F)`
case ${oldname} in
  tvl) name="TVListings - ";;
  tvp) name="TVProgramming - ";;
  yos*) name="Yosemite";;
  eh*) name="ExternalHome";;
  own*) name="Owncloud";;
  dl*) name="Downloads";;
  *) echo -n "Error 206: unknown filename";exit 206;;
esac
case ${oldname} in
  tvl|tvp) newname=${fullpath}/${name}${datetime}${char}.${ext};;
  yos*|eh*|own*|dl*) newname=${fullpath}/${name}.${ext};;
  *) echo -n "Error 207: unknown filename";exit 207;;
esac
mv "${origname}" "${newname}"
