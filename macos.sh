#!/usr/bin/env bash

# of the installers just copied from the NAS, install any that can be
# installed from a script
shopt -s dotglob
shopt -s nullglob
installernames=("${extractdir}/*")  # get a list of all the installers in 'extractdir' into an array.  the filenames are in the format 'extractdir/installername'
shopt -u nullglob
for i in "${installernames[@]}"; do  # loop through all the installers that were found
  progname=$("${HOME}"/bin/fp -n "${i}")  # extract the program name
  ext=$("${HOME}"/bin/fp -e "${i}")  # extract the extension
  print_info "\nInstalling '${progname}'\n\n"
  case "${ext}" in
    dmg )
      echo "Y" | hdiutil mount -nobrowse "${i}" -mountpoint "${extractdir}/${progname}" >/dev/null  # mount the installer, which creates the specified mountpoint, accepting any license agreement
      cp -a "${extractdir}/${progname}"/*.app "${appdir}"  # copy any '.app' files to 'appdir'
      print_result "${?}" "Installed ${progname}"
      hdiutil detach "${extractdir}/${progname}" >/dev/null  # unmount the installer, which also deletes the mountpoint
      /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
      print_result "${?}" "Deleted ${i}"
      ;;
    pkg )
      "${HOME}"/bin/pkginstall "${i}"  # 'pkginstall' installs the program, checking to see if a reboot is needed or not
      print_result "${?}" "Installed ${progname}"
      /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
      print_result "${?}" "Deleted ${i}"
      ;;
    zip )
      unzip "${i}" -d "${extractdir}/${progname}" >/dev/null  # unzip the installer
      case "${progname}" in
        dmidecode* )
          cp -a "${extractdir}/${progname}"/dmidecode /usr/local/sbin  # copy 'dmidecode' to '/usr/local/sbin'
          retcode="${?}"
          ;;
        * )
          cp -a "${extractdir}/${progname}"/*.app "${appdir}"  # copy any '.app' files to 'appdir'
          retcode="${?}"
          ;;
      esac
      print_result "${retcode}" "Installed ${progname}"
      /bin/rm -dfr "${extractdir}/${progname}"  # delete the directory the installer was unzip'd to
      /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
      print_result "${?}" "Deleted ${i}"
      ;;
    gz )
      mkdir "${extractdir}/${progname}"
      tar -xp -f "${i}" -C "${extractdir}/${progname}" >/dev/null  # un-gzip the installer
      case "${progname}" in
        onefetch* )
          cp -a "${extractdir}/${progname}"/onefetch /usr/local/sbin  # copy 'onefetch' to '/usr/local/sbin'
          retcode="${?}"
          ;;
        * )
          ;;
      esac
      print_result "${retcode}" "Installed ${progname}"
      /bin/rm -dfr "${extractdir}/${progname}"  # delete the directory the installer was un-gzip'd to
      /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
      print_result "${?}" "Deleted ${i}"
      ;;
    * ) ;;
  esac
done

# check to see if any '.xip' files need to be installed.  if so, install them
if [[ "${xip}" == 1 ]]; then
  currdir=${PWD}  # preserve the current directory
  cd "${appdir}"  # 'xip' extracts to the current directory, so change to 'appdir'
  print_result "${?}" "Changed to '${appdir}'"
  shopt -s dotglob
  shopt -s nullglob
  xips=(*.xip)  # get a list of all the *.xip programs into an array.  the filenames are in the format '<filename>.xip'
  shopt -u nullglob
  for i in ${xips[@]}; do  # loop through the array of '.xip' programs to be installed
    progname=$("${HOME}"/bin/fp -n "${i}")  # extract the program name
    print_info "\nInstalling '${progname}'\n\n"
    xip -x "${i}"  # extract them, thus "installing" the program
    print_result "${?}" "Installed ${i}"
    /bin/rm -d "${i}"  # we don't need this copy of the installer anymore, so delete it
    print_result "${?}" "Deleted ${i}"
  done
  cd "${currdir}"  # change back to where we were
  print_result "${?}" "Changed back to '${currdir}'"
fi

# now that XCode is installed, point the 'xcode-select' developer directory to
# the proper directory in Xcode.
# https://github.com/alrra/dotfiles/issues/13
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
print_result "${?}" "Made 'xcode-select' developer directory point to Xcode"

# Automatically agree to the terms of the Xcode license
# https://github.com/alrra/dotfiles/issues/10
sudo xcodebuild -license accept &> /dev/null
print_result "${?}" "Agreed to the XCode licence"

# # minimal macOS installation requirements for 'Homebrew' keep changing, so check
# # to see if this system can run it...if so, install it.
# if [[ "${SYSTEM_VERSION%%.*}" -ge "11" ]]; then
#   print_result "${?}" "This version of macOS can run Homebrew...installing"
#   # temporarily export some environment variables for Homebrew.  this is done
#   # permanently in the 'exports' dotfile
#   export HOMEBREW_CASK_OPTS="--appdir="${HOME}"/Applications"  # keep Casks separate from the programs installed by macOS
#   export HOMEBREW_EDITOR="${EDITOR}"  # use the system editor to edit Homebrew stuff
#   export HOMEBREW_CACHE="/Volumes/ExternalHome/rtruell/HomebrewCache"  # get the cache off the SSD
#   export HOMEBREW_NO_ANALYTICS=1  # turn off Google analytics for Homebrew
#   print_result "${?}" "Exported Homebrew environment variables"
#   printf "\n" | eval $(trim -l "$(curl -Ls brew.sh | grep -i "install.sh" | sed 's|<[^>]*>||g')")  # get the current Homebrew install command and run it
#   print_result "${?}" "Installed Homebrew"
#   # temporarily add its directories to PATH and export the main environment
#   # variables (this is done permanently in the 'path' dotfile)
#   eval "$(brew shellenv)"
#   print_result "${?}" "Added Homebrew directories to PATH and exported the main environment variables"
#   # temporarily store Homebrew's installation directory.  this is done permanently
#   # in the 'exports' dotfile
#   export BREW_PREFIX=$(brew --prefix)
#   print_result "${?}" "Exported Homebrew's installation directory"
#   brew update  # update brew
#   print_result "${?}" "Updated Homebrew"
#   brew doctor  # check it
#   print_result "${?}" "Checked Homebrew"

#   # install all the things
#   print_info "About to install the .Brewfile contents...this could take a while!!\n"
#   brew bundle --global
#   print_result "${?}" "Installed desired formulas, Casks and MAS apps"

#   # remove outdated versions from the cellar
#   brew cleanup
#   print_result "${?}" "Cleaned up Homebrew"

#   # switch to using the brew-installed bash as default shell
#   if [[ -x "${BREW_PREFIX}/bin/bash" ]]; then
#     if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then  # if the new bash isn't already in the list of shell programs
#       printf '%s\n' "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells >/dev/null  # add it
#       print_result "${?}" "Updated '/etc/shell' with the just-installed version of bash"
#     fi
#     chsh -s "${BREW_PREFIX}/bin/bash"  # change the shell to the new bash
#     print_result "${?}" "Changed the shell to the new version of bash: ${BASH_VERSION} (should be 4+)"  # should be 4+ not the old 3.2.x
#   else
#     print_result "${?}" "bash not installed properly by Homebrew"
#   fi
# else
#   print_result "${?}" "This version of macOS is too old to run Homebrew...skipping"
# fi

# set up the default system settings
source ./.macos-systemsettings
print_result "${?}" "Set up the macOS default system settings"

# the Sublime Text 'User' directory is being shared between machines for a
# consistent usage environment, so symlink it
if [[ -d "${HOME}/Library/Application Support/Sublime Text/Packages/User" ]]; then  # if the 'User' directory already exists
  print_warn "The 'User' directory for 'sublime text' already exists\n"  # say so
  mv "${HOME}/Library/Application Support/Sublime Text/Packages/User" "${HOME}/Library/Application Support/Sublime Text/Packages/User.old"  # and back it up for later comparison
  print_result "${?}" "Backed it up for later comparison"
fi
symlink_single_file "${HOME}/dotfiles/SublimeText/User" "${HOME}/Library/Application Support/Sublime Text/Packages/User"  # symlink the 'User' directory

# extra commands to execute
rmdir /Users/rtruell/Downloads  # remove the OS-installed 'Downloads' directory ...
print_result "${?}" "Removed the OS-installed 'Downloads' directory"
symlink_single_file "/Volumes/Downloads/RecentDownloads" "/Users/rtruell/Downloads"  # ... and replace it with a symlink to the external downloads directory, to get it off the SSD
symlink_single_file "/Volumes/ExternalHome/rtruell/SourceCode" "/Users/rtruell/SourceCode"  # make the directory of source code projects easy to get to
# remove the default install location of the 'Moneydance' data files ...
rmdir /Users/rtruell/Library/Containers/com.infinitekind.MoneydanceOSX/Data/Documents
print_result "${?}" "removed the default install location of the 'Moneydance' data files"
# ...and replace it with a symlink to the external data files to get them off the SSD
symlink_single_file "/Volumes/ExternalHome/rtruell/MoneydanceData" "/Users/rtruell/Library/Containers/com.infinitekind.MoneydanceOSX/Data/Documents"
# attempt to replace Apple's 'Terminal' program with 'iTerm'
if [[ -x "${HOME}"/Applications/iTerm.app ]]; then
  sudo mv /Applications/Utilities/Terminal.app /Applications/Utilities/Terminal-apple.app  # rename Apple's 'Terminal' program ...
  print_result "${?}" "Renamed Apple's 'Terminal' program"
  sudo symlink_single_file "${HOME}/Applications/iTerm.app" "/Applications/Utilities/Terminal.app"  # ... and replace it with a symlink to 'iTerm'
fi
