#!/usr/bin/env bash
StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# macOS-only stuff.  abort if not macOS.
if [[ "$(uname)" != "Darwin" ]]; then printf '%s\n' "This script is to be run only on macOS"; exit 1; fi

# save stdout (1) and stderr (2) in "backup" file descriptors (3 & 4), and then
# redirect them so that the output and any error messages from the script are on
# both the screen and in a file...just in case there are errors that need to be
# referenced later.
exec 3>&1 4>&2  > >(tee -i "${HOME}"/installlog.txt) 2>&1

# some functions are needed to set things up, so load them
source ./.functions/answer_is_y.function
source ./.functions/execute_command.function
source ./.functions/01#findcommand.function
source ./.functions/print_error.function
source ./.functions/print_result.function
source ./.functions/print_success.function
source ./.functions/print_warn.function
source ./.functions/symlink_array_files.function
source ./.functions/symlink_single_file.function

# ANSI sequences for colours to be used in the banner
declare -a colours=(
  "\033[0;30m"
  "\033[1;30m"
  "\033[0;36m"
  "\033[0;34m"
  "\033[0;31m"
  "\033[0;32m"
  "\033[0;35m"
  "\033[0;33m"
  "\033[1;33m"
  "\033[0;37m"
)

# a banner display in the style as shown in the movie "Matrix"...although not
# nearly as good :-)
for z in {1..40}; do
  for i in {1..17}; do
    r="$(($RANDOM % 2))"
    if [[ $(($RANDOM % 5)) == 1 ]]; then
      if [[ $(($RANDOM % 4)) == 1 ]]; then
        v+="${colours[$((1 + $RANDOM % 10))]} ${r}   "
      else
        v+="${colours[$((1 + $RANDOM % 10))]} ${r}   "
      fi
    else
      v+="${colours[$((1 + $RANDOM % 10))]}     "
    fi
  done
  printf "${v}\n"
  sleep .1
  v="";
done

# emphasize that this is a new install :-)
declare -a words=(
  " #    # ###### #    #     #####  #    #  ####  #####    ##   #      #        ### ###"
  " ##   # #      #    #       #    ##   # #        #     #  #  #      #        ### ###"
  " # #  # #####  #    #       #    # #  #  ####    #    #    # #      #        ### ###"
  " #  # # #      # ## #       #    #  # #      #   #    ###### #      #        ### ###"
  " #   ## #      ##  ##       #    #   ## #    #   #    #    # #      #               "
  " #    # ###### #    #     #####  #    #  ####    #    #    # ###### ######   ### ###"
)
printf "\033[0m\n"
for i in "${words[@]}"; do
  printf '%s\n' "${i}"
  sleep .1
done
printf '%s\n' " "
unset colours words z i r v

# get the users login name
username=$(echo ${USER})
print_result $? "User doing the install is '${username}'"

# make it so the user can use 'sudo'.  the code that was in here suddenly
# stopped working, so it was removed and put into its own script file.  it's
# actually better that way...'su -c' can only run "one" command at a time, so
# if doing multiple things is required, either there has to be multiple 'su -c'
# lines and type the password each time, or there has to be one humongous
# command line.  using an external script, the password only has to be typed
# once, but each command can be on its own line, making it easier to follow
# what's being done and to debug problems
su -c 'source ./sudo.sh "${username}"'

# symlink the dotfiles into ${HOME}
source ./symlink.sh
print_result $? "Symlinked dotfiles"

# Copy over the files and directories that are needed but shouldn't be in a
# public repository, as well as software not in 'Homebrew' but that has been
# downloaded
declare -a filesdirs=(
  ".credentials"
  ".gitconfig.local"
  ".ssh"
)
i=""
retcode=0
currdir=${PWD}  # preserve the current directory
# mount the NAS's data directory.  this will prompt for the user/password, then
# try to create '/Volumes/data' and mount the NAS's data directory there
osascript -e 'mount volume "smb://nas/data"' 1>/dev/null 2>&1
retcode=$?
if [[ "${retcode}" == 0 ]]; then  # if the NAS was mounted
  print_result ${retcode} "Mounted NAS"
  cd /Volumes/data/OSInstallFiles  # change to the directory containing the files/directories to be copied
  print_result $? "Changed to the directory containing the sensitive files/directories to be copied"
  for i in ${filesdirs[@]}; do  # loop through the array of files and directories to be copied
    if [[ -d "${i}" ]]; then  # if it's a directory
      cp -ra "${i}" "${HOME}"  # copy it and all its files
      print_result $? "Copied directory ${i}"
      chmod 700 "${HOME}/${i}"  # set the permissions on the directory itself to read/write/execute for the owner and nothing for others
      print_result $? "Set permissions for the ${i} directory"
      chmod 600 "${HOME}/${i}"/*  # set the permissions on the files in the directory to read/write for the owner and nothing for others
      print_result $? "Set permissions for the files in the ${i} directory"
    else  # otherwise it's a file
      cp -a "${i}" "${HOME}"  # copy it
      print_result $? "Copied ${i}"
      chmod 600 "${HOME}/${i}"  # set its permissions to read/write for the owner and nothing for others
      print_result $? "Set permissions for ${i}"
    fi
  done

  # copy config files for Beyond Compare
  cp -a BC4Key.txt "${HOME}"
  print_result $? "Copied the Beyond Compare key file to '${HOME}'"
  chmod 600 "${HOME}"/BC4Key.txt
  print_result $? "Set permissions for the Beyond Compare key file"
  cp -a BCSettings-mac*.bcpkg "${HOME}"
  print_result $? "Copied the Beyond Compare settings file"
  chmod 600 "${HOME}"/BCSettings-mac*.bcpkg
  print_result $? "Set permissions for the Beyond Compare settings file"

  # if necessary, create a directory for Homebrew Casks and third-party software
  if [[ ! -d "${HOME}"/Applications ]]; then  # if '"${HOME}"/Applications' doesn't already exist, create it
    mkdir "${HOME}"/Applications
    print_result $? "Created '${HOME}/Applications'"
  else
    print_result 0 "'${HOME}/Applications' aleady exists"
  fi

  # copy third-party programs that aren't available in 'Homebrew' or that the
  # versions in 'Homebrew' won't run on the version of macOS I'm running.  the
  # programs must be previously downloaded and located in
  # '//nas/data/Downloads/Mac/InUse/Installed/Automated'
  i=""
  programdir="/Volumes/data/Downloads/Mac/InUse/Installed/Automated"  # the directory containing the program files to be copied
  extractdir="/Volumes/Temp/Installers"  # the directory where the program files get copied to so the programs can be extracted
  appdir="${HOME}/Applications"  # the directory where the extracted programs get copied/installed to
  if [[ ! -d "${extractdir}" ]]; then  # if 'extractdir' doesn't already exist, create it
    mkdir "${extractdir}"
    print_result $? "Created '${extractdir}'"
  else
    print_result 0 "'${extractdir}' aleady exists"
  fi
  shopt -s dotglob
  shopt -s nullglob
  programs=("${programdir}"/*)  # get a list of all the programs in 'programdir' into an array.  the filenames are in the format 'programdir/programfilename'
  shopt -u nullglob
  for i in ${programs[@]}; do  # loop through the array of programs to be installed
    ext=$("${HOME}"/bin/fp -e "${i}")  # extract the extension
    case "${ext}" in
      app)
          cp -a "${i}" "${appdir}"  # if it's a '.app', it's an already-extracted program, so copy it to 'appdir'
          print_result $? "Installed ${i}"
          ;;
      xip)
          cp -a "${i}" "${appdir}"  # if it's a '.xip', it's a zipped program, so copy it to 'appdir' for extraction and installation below
          print_result $? "Copied ${i} to ${appdir}"
          xip=1
          ;;
        *)
          cp -a "${i}" "${extractdir}"  # if it's none of the others, then copy it to 'extractdir' to be installed below
          print_result $? "Copied ${i} to ${extractdir}"
          ;;
    esac
  done
  # done with the NAS
  cd "${currdir}"  # change back to where we were
  print_result $? "Changed back to '${currdir}'"
  diskutil unmount /Volumes/data 1>/dev/null 2>&1  # unmount the NAS.  this also automatically deletes '/Volumes/data'
  print_result $? "Unmounted NAS"
else
  print_result ${retcode} "Mounting NAS failed...sensitive files/directories and third-party software must be copied manually"
fi

# of the installers just copied from the NAS, install any that can be
# installed from a script
shopt -s dotglob
shopt -s nullglob
installernames=("${extractdir}"/*)  # get a list of all the installers in 'extractdir' into an array.  the filenames are in the format 'extractdir/installername'
shopt -u nullglob
for i in "${installernames[@]}"; do  # loop through all the installers that were found
  progname=$("${HOME}"/bin/fp -n "${i}")  # extract the program name
  ext=$("${HOME}"/bin/fp -e "${i}")  # extract the extension
  case "${ext}" in
    dmg)
        echo "Y" | hdiutil mount -nobrowse "${i}" -mountpoint "${extractdir}/${progname}" >/dev/null  # mount the installer, which creates the specified mountpoint, accepting any license agreement
        cp -a "${extractdir}/${progname}"/*.app "${appdir}"  # copy any '.app' files to 'appdir'
        print_result $? "Installed ${progname}"
        hdiutil detach "${extractdir}/${progname}" >/dev/null  # unmount the installer, which also deletes the mountpoint
        /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
        print_result $? "Deleted ${i}"
        ;;
    pkg)
        pkginstall "${i}"  # 'pkginstall' installs the program, checking to see if a reboot is needed or not
        print_result $? "Installed ${progname}"
        /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
        print_result $? "Deleted ${i}"
        ;;
    zip)
        unzip "${i}" -d "${extractdir}/${progname}" >/dev/null  # unzip the installer
        cp -a "${extractdir}/${progname}"/*.app "${appdir}"  # copy any '.app' files to 'appdir'
        print_result $? "Installed ${progname}"
        /bin/rm -dfr "${extractdir}/${progname}"  # delete the directory the installer was unzip'd to
        /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
        print_result $? "Deleted ${i}"
        ;;
      *) ;;
  esac
done

# check to see if any '.xip' files need to be installed.  if so, install them
if [[ "${xip}" == 1 ]]; then
  cd "${appdir}"  # 'xip' extracts to the current directory, so change to 'appdir'
  print_result $? "Changed to '${appdir}'"
  shopt -s dotglob
  shopt -s nullglob
  xips=(*.xip)  # get a list of all the *.xip programs into an array.  the filenames are in the format '<filename>.xip'
  shopt -u nullglob
  for i in ${xips[@]}; do  # loop through the array of '.xip' programs to be installed
    xip -x "${i}"  # extract them, thus "installing" the program
    print_result $? "Installed ${i}"
    /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
    print_result $? "Deleted ${i}"
  done
  cd "${currdir}"  # change back to where we were
  print_result $? "Changed back to '${currdir}'"
fi

# XCode Command Line Tools
# https://github.com/alrra/dotfiles/blob/ff123ca9b9b/os/os_x/installs/install_xcode.sh
if ! xcode-select --print-path &> /dev/null; then
  # Prompt user to install the XCode Command Line Tools
  xcode-select --install &> /dev/null

  # Wait until the XCode Command Line Tools are installed
  until xcode-select --print-path &> /dev/null; do
      sleep 5
  done
  print_result $? "Install XCode Command Line Tools"

  # Point the 'xcode-select' developer directory to the appropriate directory in
  # 'Xcode.app'.  see https://github.com/alrra/dotfiles/issues/13
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  print_result $? "Make 'xcode-select' developer directory point to Xcode"

  # Automatically agree to the terms of the Xcode license
  # https://github.com/alrra/dotfiles/issues/10
  sudo xcodebuild -license accept &> /dev/null
  print_result $? "Agree with the XCode Command Line Tools licence"
fi

# Homebrew

# temporarily export some environment variables for Homebrew.  this is done
# permanently in the 'exports' dotfile
export HOMEBREW_CASK_OPTS="--appdir="${HOME}"/Applications"  # keep Casks separate from the programs installed by macOS
export HOMEBREW_EDITOR="${EDITOR}"  # use the system editor to edit Homebrew stuff
export HOMEBREW_CACHE="/Volumes/ExternalHome/rtruell/HomebrewCache"  # get the cache off the SSD
export HOMEBREW_NO_ANALYTICS=1  # turn off Google analytics for Homebrew
print_result 0 "Exported Homebrew environment variables"
printf "\n" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"  # install Homebrew
print_result $? "Installed Homebrew"
# temporarily add its directories to PATH and export the main environment
# variables (this is done permanently in the 'path' dotfile)
eval "$(brew shellenv)"
print_result 0 "Added Homebrew directories to PATH and exported the main environment variables"
# temporarily store Homebrew's installation directory.  this is done permanently
# in the 'exports' dotfile
export BREW_PREFIX=$(brew --prefix)
print_result $? "Exported Homebrew's installation directory"
brew update  # update brew
print_result $? "Updated Homebrew"
brew doctor  # check it
print_result $? "Checked Homebrew"

# install all the things
printf '%s\n' "About to install the .Brewfile contents...this could take a while!!"
brew bundle --global
print_result $? "Installed desired formulas, Casks and MAS apps"

# remove outdated versions from the cellar
brew cleanup
print_result $? "Cleaned up Homebrew"

# switch to using brew-installed bash as default shell
if [[ -x "${BREW_PREFIX}/bin/bash" ]]; then
 if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then  # if the new bash isn't already in the list of shell programs
   sudo printf '%s\n' "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells  # add it
   print_result $? "Updated '/etc/shell' with the just-installed version of bash"
 fi
 chsh -s "${BREW_PREFIX}/bin/bash"  # change the shell to the new bash
 print_result $? "Changed the shell to the new version of bash: ${BASH_VERSION} (should be 4+)"  # should be 4+ not the old 3.2.x
else
 print_result 1 "bash not installed properly by Homebrew"
fi

# set up macOS defaults
compname=$(hostname -s)  # get the hostname of the computer, stripping off the domainname if it's there
source ./.macos  # set up the defaults common to all Mac computers
print_result $? "Set up the macOS defaults common to all Mac computers"
source ./.macos-${compname}  # set up the defaults specific to the computer being installed
print_result $? "Set up the macOS defaults specific to this computer"

# extra commands to execute
rmdir /Users/rtruell/Downloads  # remove the OS-installed 'Downloads' directory ...
print_result $? "Removed the OS-installed 'Downloads' directory"
symlink_single_file "/Volumes/Downloads/RecentDownloads" "/Users/rtruell/Downloads"  # ... and replace it with a symlink to the external downloads directory, to get it off the SSD
symlink_single_file "/Volumes/ExternalHome/rtruell/SourceCode" "/Users/rtruell/SourceCode"  # make the directory of source code projects easy to get to
# remove the default install location of the 'Moneydance' data files ...
rmdir /Users/rtruell/Library/Containers/com.infinitekind.MoneydanceOSX/Data/Documents
print_result $? "removed the default install location of the 'Moneydance' data files"
# ...and replace it with a symlink to the external data files to get them off the SSD
symlink_single_file "/Volumes/ExternalHome/rtruell/MoneydanceData" "/Users/rtruell/Library/Containers/com.infinitekind.MoneydanceOSX/Data/Documents"
if [[ -x "${HOME}"/Applications/iTerm.app ]]; then
  sudo mv /Applications/Utilities/Terminal.app /Applications/Utilities/Terminal-apple.app  # rename Apple's 'Terminal' program ...
  print_result $? "Renamed Apple's 'Terminal' program"
  sudo symlink_single_file "${HOME}/Applications/iTerm.app" "/Applications/Utilities/Terminal.app"  # ... and replace it with a symlink to 'iTerm'
fi

exec 1>&3 2>&4 3>&- 4>&-  # restore stdout (1) and stderr (2) and close the "backup" file descriptors (3 & 4)
