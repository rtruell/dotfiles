#!/bin/bash
# print prompt and get y/n answer
# sample use:
#
# if askyn "Kill process ${pid} <${pname}> with signal ${sig}?"
#   then kill ${sig} ${pid}
# fi
#
function askyn {
  echo -n "$@" '[y/n] ' ; read ans
  case "${ans}" in
    y*|Y*) return 0 ;;
    *) return 1 ;;
  esac
}

# If invoked directly run test code.
if [[ $(basename $0 .sh) == 'askyn' ]]; then
  askyn "Type 'y' or 'n'"
  returncode=$?
  [ "${returncode}" -eq 0 ] && echo Answer was yes
  [ "${returncode}" -ne 0 ] && echo Answer was no
fi
