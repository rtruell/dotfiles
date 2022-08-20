#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# this symlinks the necessary files to ${HOME}.  this is safe to run multiple
# times and will prompt you about anything unclear

declare -a excludefiles
dotconfig=0

# read into an array the list of files and directories that shouldn't be
# symlinked, which are in the file ".dotfiles.ignore", one filename/directory
# per line
while read -r line; do  # read a line
  [[ "${line}" = \#* ]] || [[ -z "${line}" ]] && continue  # if the line starts with '#' (thus a comment) or is empty, skip it
  excludefiles+=("$line")  # otherwise, add it to the array to be excluded
done < .dotfiles.ignore  # read from the file ".dotfiles.ignore"
[[ $line ]] && excludefiles+=("$line")

# with an install of Debian 10.10.0 in a VM, I found that the '.config'
# directory is created during the installation, in both 'root' and the user
# account created during the install.  since there are files/directories that
# need to be linked into '.config', I had to add some code to account for the
# possibility that it already exists.
if [ -d "${HOME}/.config" ]; then  # check to see if the '.config' directory already exists in the HOME directory
  excludefiles+=(".config")  # if it does already exist, add it to the array of filenames/directories to be excluded from being linked
  dotconfig=1  # set a flag so we know we have to deal with linking the files/directories inside '.config' later
  printf "\n\e[0;35m  '.config' already exists...will process separately later.\e[0m\n\n"
fi
excludecount=${#excludefiles[@]}  # get the number of files/directories to be skipped

# finds all files and directories in the current directory to be symlinked.
shopt -s dotglob  # enable filenames starting with a '.' to be included in pathname expansion
shopt -s nullglob  # enable patterns matching no filenames to expand to the null string
filenames=(*)  # get a list of all the files in the current directory into an array.  filenames are of the format "<filename>"
shopt -u nullglob  # disable expansion to null string
# and call the function to figure out which files/directories need to be symlinked
symlink_array_files "${PWD}" "${HOME}" <( (( ${#filenames[@]} )) && printf '%s\0' "${filenames[@]}") <( (( ${#excludefiles[@]} )) && printf '%s\0' "${excludefiles[@]}")

# if '.config' does already exist, then we process the files/directories that
# need to be linked into it separately
if [[ "${dotconfig}" == 1 ]]; then
  printf "\n\e[0;35m  Now processing '.config'.\e[0m\n\n"
  ((excludecount--))  # decrement the number of files/directories to be skipped by 1
  unset -v 'excludefiles[${excludecount}]'  # then use the new 'excludecount' as an index into 'excludefiles' to remove '.config' from the array of filenames to be excluded, just in case
  shopt -s dotglob  # enable filenames starting with a '.' to be included in pathname expansion
  shopt -s nullglob  # enable patterns matching no filenames to expand to the null string
  filenames=(.config/*)  # get a list of all the files in the '.config' directory into an array.  filenames are of the format ".config/<filename>"
  shopt -u nullglob  # disable expansion to null string
  # and call the function to figure out which files/directories need to be symlinked
  symlink_array_files "${PWD}" "${HOME}" <( (( ${#filenames[@]} )) && printf '%s\0' "${filenames[@]}") <( (( ${#excludefiles[@]} )) && printf '%s\0' "${excludefiles[@]}")
fi

# I've decided to keep separate '.bash_history' files for each computer, so I
# included ".bash_history*" in the '.dotfiles.ignore' file so they wouldn't be
# linked with the other dotfiles.  Now I have to figure out which computer I'm
# installing on and link the appropriate '.bash_history-<hostname>' file
printf "\n\e[0;35m  Now processing '.bash_history'.\e[0m\n\n"
sourceFile="${PWD}/.bash_history-${computername}"  # prepend the PWD and "/.bash_history-" to the compname so that we have a full pathname to the ".bash_history" file for this computer
targetFile="${HOME}/.bash_history"  # set the full pathname for the new link
symlink_single_file "${sourceFile}" "${targetFile}"  # and call the function to symlink it

# macmini gets a special 'bash_logout' that pushs its 'bash_history' to the
# dotfiles repository, so '.bash_logout*' was added to the '.dotfiles.ignore'
# file so they wouldn't be linked with the other dotfiles.  now we check to see
# what machine is being installing to, and link the appropriate '.bash_logout'
# file
printf "\n\e[0;35m  Now processing '.bash_logout'.\e[0m\n\n"
if [[ "${computername}" == "macmini" ]]; then
  sourceFile="${PWD}/.bash_logout-${computername}"  # it's macmini, so we use the special '.bash_logout', prepending the PWD to get a full pathname
else
  sourceFile="${PWD}/.bash_logout"  # it's not macmini, so we use just the regular '.bash_logout', prepending the PWD to get a full pathname
fi
targetFile="${HOME}/.bash_logout"  # set the full pathname for the new link
symlink_single_file "${sourceFile}" "${targetFile}"  # and call the function to symlink it

printf "\n\e[0;35m  Finished linking files and directories.\e[0m\n\n"

# remove the variables and functions used from the environment so they're not
# passed to subsequent commands
unset excludefiles dotconfig line excludecount filenames compname sourceFile targetFile

# switch back to where we started
cd "${StartDir}"
