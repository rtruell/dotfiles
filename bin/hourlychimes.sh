#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${DIR}"
#exit  # uncomment this so the chimes don't sound when doing things like streaming video's

# Start user-changeable variables

ChimeHours="no"   # set to yes if you want one tone for each hour (i.e. 11 am/pm gives 11 tones) after the hour chime
Chime00="yes"     # set to yes if you want a chime on the hour
Chime15="yes"     # set to yes if you want a chime at 15 minutes past the hour
Chime30="yes"     # set to yes if you want a chime at 30 minutes past the hour
Chime45="yes"     # set to yes if you want a chime at 45 minutes past the hour

# if you don't want the chimes sounding while certain programs are running, enter them in this list, each surrounded by quotes and separated by a space.
# case doesn't matter.
DontChimeList=("vlc")

# End user-changeable variables

# Don't change anything below here

CurrHour=$(date +"%H")
CurrMin=$(date +"%M")
BaseFilename="${HOME}/binsupportfiles/WestminsterDeep"
Toll="Toll"

for i in "${DontChimeList[@]}"
do
    if ps aux | grep -i "${i}".app | grep -v grep >/dev/null; then exit; fi
done

if [ ${CurrHour} -gt 12 ]; then CurrHour=$((${CurrHour}-12)); fi
if [ ${CurrHour} -eq 0 ]; then CurrHour=12; fi

case ${CurrMin} in
  00)
    if [ "${Chime00}" == "yes" ]; then afplay -v 1 ${BaseFilename}${CurrMin}.wav; fi
    if [ "${ChimeHours}" == "yes" ]; then
      for (( c=1; c<=${CurrHour}; c++ ))
      do
        afplay -v 1 ${BaseFilename}${Toll}.wav
      done
    fi
    ;;
  15)
    if [ "${Chime15}" == "yes" ]; then afplay -v 1 ${BaseFilename}${CurrMin}.wav; fi
    ;;
  30)
    if [ "${Chime30}" == "yes" ]; then afplay -v 1 ${BaseFilename}${CurrMin}.wav; fi
    ;;
  45)
    if [ "${Chime45}" == "yes" ]; then afplay -v 1 ${BaseFilename}${CurrMin}.wav; fi
    ;;
  *) ;;
esac
