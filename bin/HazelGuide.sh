#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# the original one-line command when sed obeyed the global flag and case-conversion operators
# grep -v '^    $' "$1" | grep -v '^$' | sed -E -e 's/TV Guide for ([[:alnum:]]+) /\1, /' -e 's/([a|p]).m.([-|\&])/\u\1M\2/g' -e 's/ ([A|P]M[-|\&])/\1/g' -e 's/ends //' -e 's/([[:digit:]]) [[:alnum:]]+\&/\1\&/' -e 's/\&nbsp;\&nbsp;\&nbsp;<br>/ ()\&nbsp;\&nbsp;\&nbsp;<br>/' | pbcopy

# the new one-line command, doing global changes and case-conversion the long, hard way
grep -v '^    $' "$1" | grep -v '^$' | sed -E -e 's/TV Guide for ([[:alnum:]]+) /\1, /' -e 's/ ([a|p]).m.(-)/\1m\2/' -e 's/ ([a|p]).m.(&)/\1m\2/' -e 's/([[:digit:]]+)am-/\1AM-/' -e 's/([[:digit:]]+)pm-/\1PM-/' -e 's/([[:digit:]]+)am\&/\1AM\&/' -e 's/([[:digit:]]+)pm\&/\1PM\&/' -e 's/ends //' -e 's/([[:digit:]]) [[:alnum:]]+\&/\1\&/' -e 's/\&nbsp;\&nbsp;\&nbsp;<br>/ ()\&nbsp;\&nbsp;\&nbsp;<br>/' | pbcopy

# and now the new one-line command broken into the individual commands, and what they do

# grep -v '^    $' "$1" |                                           # first get rid of lines consisting of only 4 spaces
# grep -v '^$' |                                                    # then get rid of any blank lines
# sed -E                                                            # call 'sed'.  -E has 'sed' use ERE's.  -e adds the following script to execution queue
# -e 's/TV Guide for ([[:alnum:]]+) /\1, /'                         # get rid of the phrase "TV Guide for " and put a ',' after the day of the week
                                                                    # for some reason, 'sed' is ignoring the global flag and case-conversion operators, so we have to do things the hard way :-(
# -e 's/ ([a|p]).m.(-)/\1m\2/'                                      # first we change 'a.m.-' or 'p.m.-' to 'am-' or 'pm-'
# -e 's/ ([a|p]).m.(&)/\1m\2/'                                      # then we do the same thing but with an '&' instead of a '-'
# -e 's/([[:digit:]]+)am-/\1AM-/'                                   # now we translate 'am' to uppercase.  we include digits and '-' in the string so we don't match in the middle of a show name
# -e 's/([[:digit:]]+)pm-/\1PM-/'                                   # now we do the same for 'pm'
# -e 's/([[:digit:]]+)am\&/\1AM\&/'                                 # and now 'am' with an '&' instead of a '-'
# -e 's/([[:digit:]]+)pm\&/\1PM\&/'                                 # and the same for 'pm'
# -e 's/ends //'                                                    # now remove the phrase 'ends '
# -e 's/([[:digit:]]) [[:alnum:]]+\&/\1\&/'                         # now remove the channel name
# -e 's/\&nbsp;\&nbsp;\&nbsp;<br>/ ()\&nbsp;\&nbsp;\&nbsp;<br>/' |  # add '()' after the show name for the season/episode number
# pbcopy                                                            # and lastly put the modified text on the clipboard
