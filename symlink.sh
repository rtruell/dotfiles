#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# this symlinks the necessary files to ${HOME}.  this is safe to run multiple
# times and will prompt you about anything unclear

# first, a few functions

function answer_is_yes { [[ "${REPLY}" =~ ^[Yy]$ ]] && return 0 || return 1; }

function execute { ${1} &> /dev/null; print_result $? "${2:-$1}"; }

function print_error { printf "\e[0;31m  [✖] ${1} ${2}\e[0m\n"; }  # errors in red

function print_success { printf "\e[1;32m  [✔] ${1}\e[0m\n"; }  # successes in bright green

function print_warn { printf "\e[1;33m  [?] ${1}\e[0m"; }  # warnings in bright yellow

function print_result {
  [[ ${1} -eq 0 ]] && print_success "${2}" || print_error "${2}"
  [[ "${3}" == "true" ]] && [[ ${1} -ne 0 ]] && exit
}

# this was not originally a function, but since the code might have to be run
# more than once, I decided to turn it into a function
function linkthem {
  b=""
  sourceFile=""
  targetFile=""
  for b in ${linkfiles[@]}; do  # loop through all the files/directories to be linked
    sourceFile="$(pwd)/${b}"  # prepend the PWD and a slash to the file/directory so that we have its full pathname
    targetFile="${HOME}/${b}"  # prepend the HOME directory and a slash to the file/directory so that we have a full pathname for the new link
    linker
  done
}

# this used to be part of function 'linkthem' but then found a need to run it
# without an array of files to be linked, so made it into its own function
function linker {
  if [ -e "${targetFile}" ]; then  # if the link already exists
    if [ "$(readlink "${targetFile}")" != "${sourceFile}" ]; then  # and doesn't point to the function
      print_warn "'${targetFile}' already exists, do you want to overwrite it? (y/n) "  # ask if it should be overwritten...which is actually renaming it and then recreating it
      read -n 1
      printf "\n"
      if answer_is_yes; then
        mv -f "${targetFile}" "${targetFile}.old"  # this was originally a 'rm' command, but I decided I wanted to preserve the file and check it later
        execute "ln -fs ${sourceFile} ${targetFile}" "${targetFile} → ${sourceFile}"
      else
        print_error "${targetFile} → ${sourceFile}"
      fi
    else
      print_success "${targetFile} → ${sourceFile}"
    fi
  else
    execute "ln -fs ${sourceFile} ${targetFile}" "${targetFile} → ${sourceFile}"
  fi
}

# finds all files and directories to be symlinked in the current folder.  files
# or directories that shouldn't be symlinked should have their names listed in
# ".dotfiles.ignore", one filename per line
declare -a excludefiles
i=""
linkfiles=()
dotconfig=0
readarray -t -s 3 excludefiles < .dotfiles.ignore  # read the files/directories to be ignored into an array, skipping the first 3 lines (comments) of the file
# with a recent install of Debian 10.10.0 in a VM, found that the '.config'
# directory is created during the installation, in both 'root' and the user
# account created during the install.  since there are files/directories that
# need to be linked into '.config', had to add some code to account for the
# possibility that it already exists.
if [ -d "${HOME}/.config" ]; then  # check to see if the '.config' directory already exists in the HOME directory
  excludefiles+=(".config")  # if it does already exist, add it to the array of filenames/directories to be excluded from being linked
  dotconfig=1  # set a flag so we know we have to deal with linking the files/directories inside '.config' later
  printf "\n\e[0;35m  '.config' already exists...will process separately later.\e[0m\n\n"
fi
excludecount=${#excludefiles[@]}  # get the number of files/directories to be skipped
shopt -s dotglob  # enable filenames starting with a '.' to be included in pathname expansion
shopt -s nullglob  # enable patterns matching no filenames to expand to the null string
filenames=(*)  # get a list of all the files in the current directory into an arry.  filenames are of the format "<filename>"
shopt -u nullglob  # disable expansion to null string
for i in "${filenames[@]}"; do  # loop through all the file/directory names in the directory
  found=0  # clear the 'found' flag
  for j in "${excludefiles[@]}"; do  # loop through all the file/directory names that should be excluded
    if [[ ${i} == ${j} ]]; then found=1; fi  # if the current filename is one that should be excluded, we set the 'found' flag
  done
  if [[ "${found}" == 0 ]]; then  # if the 'found' flag wasn't set ...
    linkfiles+=(${i})  # ... we add the current file/directory name to the array of files/directories to be linked
  else
    print_success "Not linking: ${i}"  # otherwise we print a warning that it isn't being linked
  fi
done
linkthem  # and now we go link the necessary files/directories

# if '.config' does already exist, then we process the files/directories that
# need to be linked into it separately
if [[ "${dotconfig}" == 1 ]]; then
  i=""
  linkfiles=()
  printf "\n\e[0;35m  Now processing '.config'.\e[0m\n\n"
  ((excludecount--))  # decrement the number of files/directories to be skipped by 1
  unset -v 'excludefiles[${excludecount}]'  # then use the new 'excludecount' as an index into 'excludefiles' to remove '.config' from the array of filenames to be excluded, just in case
  shopt -s dotglob  # enable filenames starting with a '.' to be included in pathname expansion
  shopt -s nullglob  # enable patterns matching no filenames to expand to the null string
  filenames=(.config/*)  # get a list of all the files in the '.config' directory into an arry.  filenames are of the format ".config/<filename>"
  shopt -u nullglob  # disable expansion to null string
  for i in "${filenames[@]}"; do  # loop through all the file/directory names in the directory
    found=0  # clear the 'found' flag
    for j in "${excludefiles[@]}"; do  # loop through all the file/directory names that should be excluded
      if [[ ${i} == ${j} ]]; then found=1; fi  # if the current filename is one that should be excluded, we set the 'found' flag
    done
    if [[ "${found}" == 0 ]]; then  # if the 'found' flag wasn't set ...
      linkfiles+=(${i})  # ... we add the current file/directory name to the array of files/directories to be linked
    else
      print_success "Not linking: ${i}"  # otherwise we print a warning that it isn't being linked
    fi
  done
  linkthem  # and now we go link the necessary files/directories
fi

# I've decided to keep separate '.bash_history' files for each computer, so
# included ".bash_history*" in the '.dotfiles.ignore' file so they wouldn't be
# linked with the other dotfiles.  Now I have to figure out which computer I'm
# installing on and link the appropriate '.bash_history-hostname' file
printf "\n\e[0;35m  Now processing '.bash_history'.\e[0m\n\n"
compname=$(hostname -s)  # get the hostname of the computer, stripping off the domainname, if it's there
sourceFile="$(pwd)/.bash_history-${compname}"  # prepend the PWD and "/.bash_history-" to the compname so that we have a full pathname to the ".bash_history" file for this computer
targetFile="${HOME}/.bash_history"  # set the full pathname for the new link
linker

printf "\n\e[0;35m  Finished linking files and directories.\e[0m\n\n"

# remove the variables and functions used from the environment so they're not
# passed to subsequent commands
unset b sourceFile targetFile excludefiles i linkfiles dotconfig excludecount filenames found j linkfiles dotfiles
unset answer_is_yes execute print_error print_success print_warn print_result linkthem compname
