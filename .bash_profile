# found that when just starting iTerm normally, everything worked just fine.
# however, when right-clicking a directory in Path Finder and selecting
# "services/Open In iTerm", a number of errors occurred and none of the
# functions were loaded...but the aliases were.  turns out that's because when
# iTerm starts under that condition, it first changes to the selected directory
# and then processes the startup files...and because parts of the startup files
# look for files that don't exist anywhere but in the home directory, those
# parts fail.  so, the solution is to preserve the selected directory using
# 'pwd', change to the home directory, process all the startup fifles, and then
# change back to the selected directory.
selecteddir=`pwd`
cd "${HOME}"

# this loads all my functions.  see "README.md" in the ".functions" directory
# for why they're in individual files in a directory rather than all in one file
# as is usual.
i=""
functionfiles=()
shopt -s dotglob
shopt -s nullglob
filenames=(.functions/*)  # get a list of all the files in the '.functions' directory into an array.  filenames are of the format ".functions/<function-name>"
shopt -u nullglob
for i in "${filenames[@]}"; do  # loop through all the filenames in the directory
  skip=0  # clear the 'skip' flag
  if [[ `"${HOME}/bin/fp" -e "${i}"` != "function" ]]; then skip=1; fi  # if the current filename doesn't have an extension of 'function', it isn't a function, so we set the 'skip' flag
  if [[ "${skip}" == 0 ]]; then  # if the 'skip' flag wasn't set ...
    functionfiles+=(${i})  # ... we add the current filename to the array of functions
  fi
done
i=""
file=""
for i in ${functionfiles[@]}; do  # loop through all the functions that were found
  file="${HOME}/${i}"  # pre-pend the HOME directory and a slash to the function pathname so that we have the full path to the function
  if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then  # if the file is readable and a regular file
    source "${file}"  # we 'source' it to load the function contained within into memory
    file=`printf "${file}" | sed -E 's?(.*)[[:digit:]][[:digit:]]#(.*)?\1\2?'`  #  then strip off the filename prefix used to ensure certain functions are processed before others
    file=`"${HOME}/bin/fp" -n "${file}"`  # then extract the name of the function
    # some of the functions check to see if a command exists and, if it does,
    # don't actually create a function.  so now we check to see if the function
    # was actually created and, if so, export the function to the environment so
    # that it's available for use in script files.
    if [[ `type -t "${file}"` == "function" ]]; then export -f "${file}"; fi
  fi
done
unset i functionfiles filenames skip file

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want in the repository.
declare -a dotfiles=(
  "path"
  "colors"
  "exports"
  "aliases"
  "bash_prompt"
  "load"
  "icons"
  "bash_complete"
  "extra"
  "dotfilecheck"
)
file=""
i=""
for i in ${dotfiles[@]}; do  # loop through the array of dotfiles
  file="${HOME}/.${i}"  # pre-pend the HOME directory, a slash and a dot to the file name so that we have the full path to the dotfile
  if [[ -r "${file}" ]] && [[ -f "${file}" ]]; then  # if the file is readable and a regular file
    source "${file}"  # we 'source' it to configure the environment in some way
  fi
done
unset dotfiles file i

# commented out because I don't program in Perl these days.  kept in file in case
# set up perl's @INC so that perl can find my own subroutines.
#eval `perl -I /Volumes/ExternalHome/rtruell/perl5/lib/perl5 -Mlocal::lib=/Volumes/ExternalHome/rtruell/perl5`

echo
date
echo
if [ "${SYSTEM_TYPE}" == "macOS" ]; then
  if [ -x /usr/local/bin/fortune ]; then
    /usr/local/bin/fortune -a  # Makes our day a bit more fun.... :-)
  fi
else
  if [ -x /usr/games/fortune ]; then
    /usr/games/fortune -a  # Makes our day a bit more fun.... :-)
  fi
fi
echo

# and now switch back to the directory selected in Path Finder, if that's how
# iTerm was started
cd "${selecteddir}"
