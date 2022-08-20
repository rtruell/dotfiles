#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

shopt -s extglob  # turn on so that extended pattern matching operators are enabled for pattern matching
shopt -s globasciiranges  # turn on so that range expressions used in pattern matching bracket expressions work as expected

# arrays to hold the renaming information for shows.  each show has 3 elements:
#
# - the name of the show as it appears in the TV listings
#
# - the new name for the show.  can be the show's name unchanged (which means
#   it's being recorded for both of us or just for Gordon and thus needs
#   colouring), the first letter in each word of the show's name (because when
#   combined with other shows being recorded back-to-back, the resulting line
#   wouldn't display on one line without the name being shortened), or a lower
#   case letter capitalized (because some idiot couldn't be bothered to do so
#   when entering the data for the show)
#
# - a letter determining how/if the show's name will be coloured: 'b' for both
#   of us (chartreuse letters on a red background), 'g' for just Gordon
#   (chartreuse letters on a dark orange background) or 'm' for just me
#   (no colouring needed, but the show is in the file because the name needs to
#   be changed in some way)
declare -a ProgramOldName=() ProgramNewName=() ProgramColouring=()

# arrays to hold the information of shows to be recorded this day.  after
# processing, each listing has 4 elements:
#
# - start time
#
# - end time
#
# - channel number, left-zero-padded to 3 digits
#
# - show name
declare -a ShowStart=() ShowEnd=() ShowChannel=() ShowName=()

InputFile="${1}" # original listings output from **FreeGuide** passed from **Hazel**
ShowRenameFile="${HOME}/binsupportfiles/ShowRenameFile.txt"  # file containing the show renaming information

StartDayHeader="                    <h1><font face='helvetica, helv, arial, sans serif' size=4>"  # display settings start for the day header
EndDayHeader="</font></h1>"  # display settings end for the day header
StartListingFont="                    <font face='courier, helvetica, helv, arial, sans serif' size=2>"  # display settings start for the listings
EndListingFont="                    </font>"  # display settings end for the listings
HeaderIndent="                    "  # indent level for the header/font lines so everything lines up
ShowIndent="                        "  # indent level for each line of shows so everything lines up
ShowElementSpacer="&nbsp;&nbsp;&nbsp;"  # provides spaces between elements of the show listing
ShowLineEnd="&nbsp;&nbsp;&nbsp;<br>"  # string to be added to the end of each show listing
StartGordonColouring="<span class='orange'>"  # start colouring a show that's just for Gordon
StartBothColouring="<span class='red'>"  # start colouring a show that's for both of us.  a show that's just for me doesn't get any colouring
EndColouring="</span>"  # end colouring for all shows
NumberOfRenames=0  # number of shows with renaming information
NumberOfShows=0  # number of shows to record today
JoinedShows=0  # number of back-to-back shows joined together
DayHeader=""  # date the shows are for
ListingString=""  # string containing the final listing to be written to the clipboard for pasting into 'AllListings.html'
ProgramPrior=2  # the number of minutes prior to the starting time that the recording starts.  used for creating the rename command for the recorded file

a="" b="" c="" d="" i=0 j=0 early=0 late=0 start=0 end=0  # random temporary variables

# each line of the show rename file has the following format:
#
# How I Met Your Mother,HIMYM,m
# |                   | |   | |
# --------------------- ----- --- the colouring indicator
#           |             |
#           |             --- the new name for the show
#           |
#           --- the name of the show as it appears in the TV listings
#
# if a show doesn't have an entry in this file, then I'm the only one that wants
# to watch it and the show's name doesn't need to be modified in any way...no
# colouring is the default action in that case.  however, if the show's name
# needs to be modified somehow, then the colouring indicator has to be there as
# well, even if I'm the only one that wants to watch the show

# read and process the show rename file
while IFS=, read -r a b c; do  # split the rename info into the 3 separate parts
  # no other special processing is needed, so just add the parts to the
  # appropriate arrays
  ProgramOldName+=("${a}")
  ProgramNewName+=("${b}")
  ProgramColouring+=("${c}")
  ((NumberOfRenames++))  # increment the number-of-renames counter
done < ${ShowRenameFile}

# the listings output from 'FreeGuide' has the following format:
#
#                    <h1><font face='helvetica, helv, arial, sans serif' size=4>TV Guide for Thursday May 19, 2022</font></h1>
#                    <font face='courier, helvetica, helv, arial, sans serif' size=2>
#<4 spaces>
#                        06:00 p.m.-ends 06:30 p.m.&nbsp;&nbsp;&nbsp;270 WGBHDT&nbsp;&nbsp;&nbsp;This Old House&nbsp;&nbsp;&nbsp;<br>
#<4 spaces>
#                        06:30 p.m.-ends 07:00 p.m.&nbsp;&nbsp;&nbsp;270 WGBHDT&nbsp;&nbsp;&nbsp;Ask This Old House&nbsp;&nbsp;&nbsp;<br>
#<4 spaces>
#                        06:31 p.m.-ends 07:01 p.m.&nbsp;&nbsp;&nbsp;255 WBZDT&nbsp;&nbsp;&nbsp;United States of Al&nbsp;&nbsp;&nbsp;<br>
#<4 spaces>
#                        11:01 p.m.-ends 12:00 a.m.&nbsp;&nbsp;&nbsp;131 KOMODT&nbsp;&nbsp;&nbsp;Big Sky&nbsp;&nbsp;&nbsp;<br>
#<4 spaces>
#                        12:00 a.m.-ends 01:00 a.m.&nbsp;&nbsp;&nbsp;392 SCIFI&nbsp;&nbsp;&nbsp;Star Trek: Strange New Worlds&nbsp;&nbsp;&nbsp;<br>
#<4 spaces>
#                    </font>

# read and process the show listings file
while read -r line; do  # read each line of the input file one by one, stripping off leading/trailing spaces
  ColouringIndicator=""  # colouring indicator for the current show.  has to be reset for each loop
  # see if the line is one of the ones we want to keep
  case "${line}" in
    *"${EndDayHeader}"*)  # if the line contains the date
                          line=${line/"${EndDayHeader}"/}  # strip off the end HTML code
                          line=${line#*for }  # extract the date
                          line=${line/" "/", "}  # add a comma after the day of the week
                          DayHeader="${line}"  # save the new date
                          ;;
     *"${ShowLineEnd}"*)  # if the line contains show info
                          line=${line/"${ShowLineEnd}"/}  # strip off the end HTML code
                          line=${line/"-ends "/","}  # strip "-ends " from the end time
                          line=${line//"${ShowElementSpacer}"/","}  # strip out the remaining HTML code
                          line=${line//" a.m."/"AM"}  # remove the space between the time and the a.m. indicator, remove the dots in the a.m. indicator and capitalize am
                          line=${line//" p.m."/"PM"}  # remove the space between the time and the p.m. indicator, remove the dots in the p.m. indicator and capitalize pm
                          line=${line/ +([A-Z0-9])}  # strip out the unneeded channel name and the space preceeding it
                          while IFS=, read -r a b c d; do  # split the show info into the 4 separate parts
                            while [[ "${#c}" < 3 ]]; do
                              c="0${c}"  # pad the channel number to 3 digits if necessary, so that everything lines up all the time
                            done
                            for ((i=0; i<"${NumberOfRenames}"; i++)); do
                              if [[ "${d}" == "${ProgramOldName[i]}" ]]; then  # loop through the 'ProgramOldName' rename array looking for the current show's name
                                d="${ProgramNewName[i]}"  # if it's there, replace it with the corresponding "new name"
                                ColouringIndicator="${ProgramColouring[i]}"  # save the colouring indicator for the show
                              fi
                            done
                            d="${d} ()"  # add a space and brackets (' ()') to the show name to contain the episode's name or sequence number (301, season 3 episode 1)
                            case "${ColouringIndicator}" in  # check the colouring indicator for this show
                              g)  # the show is for Gordon only, so insert the
                                  # colouring HTML code for him before the show
                                  # name, and add the stop-colouring HTML code
                                  # after the show name
                                  d="${StartGordonColouring}${d}${EndColouring}";;
                              b)  # the show is for both of us, so insert the
                                  # colouring HTML code for both of us before
                                  # the show name, and add the stop-colouring
                                  # HTML code after the show name
                                  d="${StartBothColouring}${d}${EndColouring}";;
                              *)  # the show is for me only, so don't add
                                  # anything to its name
                                  ;;
                            esac
                            # add the show parts to the appropriate arrays
                            ShowStart+=("${a}")
                            ShowEnd+=("${b}")
                            ShowChannel+=("${c}")
                            ShowName+=("${d}")
                          done <<< ${line}
                          ((NumberOfShows++))  # increment the number-of-shows counter
                          ;;
                      *)  continue ;;  # everything else gets thrown away
  esac
done < ${InputFile}

# now create the "groomed" listing data
ListingString+="${StartDayHeader}${DayHeader}${EndDayHeader}\n"  # rebuild the 'dayheader' line and add it
ListingString+="${StartListingFont}\n"  #  add the start listing font line
for ((i=0; i<"${NumberOfShows}"; i++)); do
  # loop through the show arrays, building the line for each show, and add it
  ListingString+="${ShowIndent}${ShowStart["${i}"]}-${ShowEnd["${i}"]}$ShowElementSpacer${ShowChannel["${i}"]}${ShowElementSpacer}${ShowName["${i}"]}${ShowLineEnd}\n"
done
ListingString+="${EndListingFont}\n"  # add the end listing font line

# print the "groomed" listing data to the clipboard so it can then be pasted into 'AllListings.html'
printf "${ListingString}" | pbcopy
