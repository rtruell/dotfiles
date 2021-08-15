#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

grep -v '^    $' "$1" | grep -v '^$' | sed -E -e 's/TV Guide for ([[:alnum:]]+) /\1, /' -e 's/([a|p]).m.([-|\&])/\u\1M\2/g' -e 's/ ([A|P]M[-|\&])/\1/g' -e 's/ends //' -e 's/([[:digit:]]) [[:alnum:]]+\&/\1\&/' -e 's/\&nbsp;\&nbsp;\&nbsp;<br>/ ()\&nbsp;\&nbsp;\&nbsp;<br>/' #| pbcopy
