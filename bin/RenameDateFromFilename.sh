#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# origname=${1}
# fullpath=`echo ${origname%/*.*}`
# fullname=`echo ${origname##/*/}`
# ext=`echo ${fullname##*.}`
# name=`echo ${fullname%%-*}`
# char=`echo ${fullname#*-}`
# char=`echo ${char%.*}`
# printf -v datetime $(date +%F)

for file in *
do
  if [ "${file}" != "rename.sh" ]; then
    touch -t "${file%%.*}" "${file}"
  fi
done
