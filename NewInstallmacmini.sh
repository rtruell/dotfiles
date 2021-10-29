#!/usr/bin/env bash
StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# some of my functions are needed to set things up, so load them
source ./.functions/execute_command.function
source ./.functions/findcommand.function
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

# a banner display in the style as shown in the movie "Matrix"
for z in {1..40}; do
  for i in {1..16}; do
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
  v="";
done

# emphasize that this is a new install :-)
printf "\033[0m\n"
printf " #    # ###### #    #       # #    #  ####  #####   ##   #      #        ### ###\n"
printf " ##   # #      #    #       # ##   # #        #    #  #  #      #        ### ###\n"
printf " # #  # #####  #    #       # # #  #  ####    #   #    # #      #        ### ###\n"
printf " #  # # #      # ## #       # #  # #      #   #   ###### #      #        ### ###\n"
printf " #   ## #      ##  ##       # #   ## #    #   #   #    # #      #               \n"
printf " #    # ###### #    #       # #    #  ####    #   #    # ###### ######   ### ###\n"
printf "\n"
unset colours z i r v

# Check if /usr/bin/sudo and /bin/bash exist. if not, try to find them and
# suggest a symlink, then exit the script
if [[ ! -f /usr/bin/sudo ]]; then
  if findcommand sudo &>/dev/null; then
    message="/usr/bin/sudo not found.  Please run 'sudo ln -s $(findcommand sudo) /usr/bin/sudo'"
  else
    message="/usr/bin/sudo not found, and I couldn't find 'sudo' in '\$PATH'"
  fi
  print_result 1 "${message}" "true"
fi
print_result 0 'Found sudo'
if [[ ! -f /bin/bash ]]; then
  if findcommand bash &>/dev/null; then
    message="/bin/bash not found.  Please run 'sudo ln -s $(findcommand bash) /bin/bash'"
  else
    message="/bin/bash not found, and I couldn't find 'bash' in '\$PATH'"
  fi
  print_result 1 "${message}" "true"
fi
print_result 0 'Found bash'

# symlink the dotfiles into ${HOME}
source ./symlink.sh
print_result $? 'Symlinked dotfiles'

# Copy over the files and directories that are needed but shouldn't be in a
# public repository
declare -a filesdirs=(
  ".credentials"
  ".gitconfig.local"
  ".ssh"
)
file=""
i=""
retcode=""
currdir=$(PWD)
# mount the NAS's data directory.  this will prompt for the user/password, then
# try to create '/Volumes/data' and mount the NAS's data directory there
osascript -e "mount volume \"smb://fileserver/data\"" 1>/dev/null 2>&1
retcode=$?
if [[ "${retcode}" == 0 ]]; then  # if the NAS was mounted
  print_result ${retcode} 'Mounted NAS'
  cd /Volumes/data/OSInstallFiles  # change to the directory containing the files/directories to be copied
  print_result $? 'Changed to the directory containing the sensitive files/directories to be copied'
  for i in ${filesdirs[@]}; do  # loop through the array of files and directories
    if [[ -d "${i}" ]]; then  # if it's a directory
      cp -ra "${i}" ~  # copy it and all its files
      print_result $? 'Copied directory ${i}'
      chmod 700 ~/"${i}"  # set the permissions on the directory itself to read/write/execute for the owner and nothing for others
      print_result $? 'Set permissions for the ${i} directory'
      chmod 600 ~/"${i}"/*  # set the permissions on the files in the directory to read/write for the owner and nothing for others
      print_result $? 'Set permissions for the files in the ${i} directory'
    else  # otherwise it's a file
      cp -a "${i}" ~  # copy it
      print_result $? 'Copied ${i}'
      chmod 600 ~/"${i}"  # set its permissions to read/write for the owner and nothing for others
      print_result $? 'Set permissions for ${i}'
    fi
  done
  diskutil unmount /Volumes/data 1>/dev/null 2>&1  # unmount the NAS.  this also automatically deletes '/Volumes/data'
  print_result $? 'Unmounted NAS'
  cd "${currdir}"  # change back to where we were
else
  print_result ${retcode} 'Mounting NAS failed...sensitive files/directories must be copied manually'
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
  print_result $? 'Install XCode Command Line Tools'

  # Point the `xcode-select` developer directory to the appropriate directory in
  # `Xcode.app`.  see https://github.com/alrra/dotfiles/issues/13
  sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
  print_result $? 'Make "xcode-select" developer directory point to Xcode'

  # Automatically agree to the terms of the Xcode license
  # https://github.com/alrra/dotfiles/issues/10
  sudo xcodebuild -license accept &> /dev/null
  print_result $? 'Agree with the XCode Command Line Tools licence'
fi

# install, update and check Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
print_result $? 'Installed Homebrew'
brew update
print_result $? 'Updated Homebrew'
brew doctor
print_result $? 'Homebrew checked by the doctor'

# create the directory for Homebrew Casks and manually-installed third-party software
mkdir ~/Applications
print_result $? 'Created directory for Homebrew Casks'

# export some environment variables for Homebrew
export HOMEBREW_CASK_OPTS="--appdir=~/Applications"  # keep Casks separate from the programs installed by macOS
export HOMEBREW_EDITOR="${EDITOR}"  # use the system editor to edit Homebrew stuff
export HOMEBREW_CACHE="/Volumes/ExternalHome/rtruell/HomebrewCache"  # get the cache off the SSD
export BREW_PREFIX=$(brew --prefix)  # store Homebrew's installation directory so I don't have to keep issuing the command
print_result 0 'Exported Homebrew environment variables'

# install all the things
echo "About to install the .Brewfile contents...this could take a while!!"
brew bundle --global 2>&1 | tee ~/bundle-install.txt
print_result $? 'Installed desired formula, Casks and MAS apps'

# remove outdated versions from the cellar
brew cleanup
print_result $? 'Cleaned up Homebrew'

# switch to using brew-installed bash as default shell
if [[ -x "${BREW_PREFIX}/bin/bash" ]]; then
  if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then  # if the new bash isn't already in the list of shell programs
    echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells  # add it
    print_result $? 'Updated "/etc/shell" with the just-installed version of bash'
  fi
  chsh -s "${BREW_PREFIX}/bin/bash"  # change the shell to the new bash
  print_result $? 'Changed the shell to the new version of bash: $BASH_VERSION (should be 4+)'  # should be 4+ not the old 3.2.X
else
  print_result 1 'bash not installed properly by Homebrew'
fi

# set up macOS defaults
compname=$(hostname -s)  # get the hostname of the computer, stripping off the domainname if it's there
source ./.macos-${compname}  # set up the defaults specific to the computer being installed
print_result $? 'Set up the macOS defaults specific to this computer'
source ./.macos  # set up the defaults common to all Mac computers
print_result $? 'Set up the macOS defaults common to all Mac computers'

# extra commands to execute
rmdir /Users/rtruell/Downloads  # remove the OS-installed 'Downloads' directory ...
print_result $? 'Removed the OS-installed "Downloads" directory'
symlink_single_file "/Volumes/Downloads/RecentDownloads" "/Users/rtruell/Downloads"  # ... and replace it with a symlink to the external downloads directory, to get it off the SSD
symlink_single_file "/Volumes/ExternalHome/rtruell/SourceCode" "/Users/rtruell/SourceCode"  # make the directory of source code projects easy to get to
if [[ -x /Users/rtruell/Applications/iTerm.app ]]; then
  sudo mv /Applications/Utilities/Terminal.app /Applications/Utilities/Terminal-apple.app  # rename Apple's 'Terminal' program ...
  print_result $? "Renamed Apple's terminal program"
  sudo symlink_single_file "/Users/rtruell/Applications/iTerm.app" "/Applications/Utilities/Terminal.app"  # ... and replace it with a symlink to 'iTerm'
fi
