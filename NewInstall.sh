#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# save stdout (1) and stderr (2) in "backup" file descriptors (3 & 4), and then
# redirect them so that the output and any error messages from the script are on
# both the screen and in a file...just in case there are errors that need to be
# referenced later.
exec 3>&1 4>&2  > >(tee -i "${HOME}"/installlog.txt) 2>&1

# some functions are needed to set things up, so load them
source ./.functions/01#findcommand.function
source ./.functions/answer_is_y.function
source ./.functions/apt_package_installer.function
source ./.functions/execute_command.function
source ./.functions/print_error.function
source ./.functions/print_info.function
source ./.functions/print_result.function
source ./.functions/print_success.function
source ./.functions/print_warn.function
source ./.functions/symlink_array_files.function
source ./.functions/symlink_single_file.function
source ./.functions/trim.function

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

# set a flag to count the number of errors that occur
numberoferrors=0

# get the users login name
username=$(logname)

# get info about the OS that was just installed
source ./.systeminfo

# get the computer's host name, stripping off the domain name if it's there
computername=$(hostname -s)

# determine if installing in a Virtual Machine (VM) and, if so, set the computer
# name to indicate this.  the new computer name is based on the OS being
# installed in (macOS, Debian, etc.) and the release name (Mojave, Bullseye,
# etc.), plus a suffix of '-VM'
installinvm=0
case "${SYSTEM_TYPE}" in
  macOS )
    if [[ $(ioreg -l | grep -e Manufacturer -e 'Vendor Name' | grep -i -e virtualbox -e oracle) ]]; then  # check if in a VM
      installinvm=1  # in a VM, so set the flag
      computername="macOS"  # macOS doesn't have a "distro" name, so 'macOS' is used for the first part of the new 'computername'
    fi
    ;;
  raspiOS )
    # since all of my current machines are either i386 or x86_64 based, raspiOS
    # can't be installed in a VM on them...so if that's what is being installed
    # on, do nothing here
    ;;
  * )
    if [[ $(grep -i -e virtualbox -e oracle /sys/devices/virtual/dmi/id/bios_version) ]]; then  # check if in a VM
      installinvm=1  # in a VM, so set the flag
      computername="${DISTRO_NAME}"  # set the first part of the new 'computername' to the disto being used
    fi
    ;;
esac
if [[ "${installinvm}" == 1 ]]; then  # if the VM flag has been set
  computername="${computername}-${RELEASE_NAME}-VM"  # add the release name and '-VM' to the new 'computername'
  computername="${computername// /}"  # remove any spaces in 'computername'
fi

printf '%s\n' "  The following information has been automatically detected.  If any of it is"
printf '%s\n\n' "  wrong, or missing, reply 'n' to the prompt to exit the installation."
printf '\t%s\n' "User: ${username}"
printf '\t%s\n' "OS: ${SYSTEM_TYPE}"
printf '\t%s\n' "Computer: ${computername}"
if [[ "${installinvm}" == 1 ]]; then printf '\t%s\n' "Installing in a VM"; fi
printf "\n"
print_warn "Is this correct? (y/n) "
read -n 1
printf "\n"
answer_is_y "${REPLY}"
retcode="${?}"
if [[ "${retcode}" == 0 ]]; then
  print_result "${retcode}" "Information correct...continuing."

  # make it so the user can use 'sudo', and without having to type a password
  if [[ "${SYSTEM_TYPE}" == "macOS" ]]; then
    sudo -s source ./sudo.sh
    retcode="${?}"
  else
    su -c 'source ./sudo.sh'
    retcode="${?}"
  fi
  if [[ "${retcode}" == 0 ]]; then
    print_result "${retcode}" "Configured 'sudo'"

    # now that the user can use 'sudo', check to see if the computer name was
    # changed and if so, make the change permanent.
    if [[ "${computername}" != "$(hostname -s)" ]]; then
      sudo hostname "${computername}"
      case "$SYSTEM_TYPE" in
        macOS )
          sudo scutil --set HostName "${computername}"
          ;;
        * )
          hostname | sudo tee /ect/hostname >/dev/null
          ;;
      esac
      print_result "${?}" "New hostname set"
    fi

    # symlink the dotfiles into ${HOME}
    source ./symlink.sh

    # mount the NAS' 'data' directory to access files and programs to be copied or
    # installed.  if installing on 'nas' or 'nasbackup', the files and programs
    # are directly available and nothing needs to be mounted.  however, even on
    # those machines, a variable has to be set with a directory path
    retcode=0  # holds the return code from commands
    currdir=${PWD}  # preserve the current directory
    message=""  # holds a status message to be printed
    osinstallfilesdir=""  # holds the directory where the files and program are located
    case "${SYSTEM_TYPE}" in
      macOS)
             # this will prompt for the user/password, then try to create
             # mountpoint '/Volumes/data' and mount the NAS' data directory there
             osascript -e 'mount volume "smb://nas/data"' 1>/dev/null 2>&1
             retcode="${?}"
             if [[ "${retcode}" == 0 ]]; then
               message="NAS mounted"
               osinstallfilesdir="/Volumes/data/OSInstallFiles"
             else
               message="NAS mounting failed...sensitive files/directories and third-party software must be copied manually"
             fi
             ;;
          *)
             # in Linux, the 'cifs-utils' package is needed in order to mount SMB
             # shares, so install it if necessary
             apt_package_installer "cifs-utils"
             case "${computername}" in
               nas*)
                     # if installing on 'NAS' or 'NASbackup'
                     [[ -d /nas/data/OSInstallFiles ]]  # check to see if the NAS files are available
                     retcode="${?}"
                     if [[ "${retcode}" == 0 ]]; then
                       message="NAS files are available"
                       osinstallfilesdir="/nas/data/OSInstallFiles"
                     else
                       message="The NAS files aren't available...sensitive files/directories and non-apt programs must be copied manually"
                     fi
                     ;;
                  *)
                     # any other machine not running macOS
                     mkdir "${HOME}"/mountpoint  # create a mount point for the NAS' data directory
                     print_result "${?}" "Created mount point"
                     # mount it.  don't forget to change the user name as
                     # necessary.  note that this will ask for the password for
                     # that user on NAS
                     sudo mount -t cifs -o user=rtruell //nas/data "${HOME}"/mountpoint
                     retcode="${?}"
                     if [[ "${retcode}" == 0 ]]; then
                       message="NAS mounted"
                       osinstallfilesdir="${HOME}/mountpoint/OSInstallFiles"
                     else
                       message="NAS mounting failed...sensitive files/directories and non-apt programs must be copied manually"
                     fi
                     ;;
             esac
             ;;
    esac
    print_result "${retcode}" "${message}"
    cd "${osinstallfilesdir}"  # change to the directory containing the files/directories to be copied
    print_result "${?}" "Changed to the directory containing the sensitive files/directories to be copied"

    # Copy over files and directories that are needed but shouldn't be in a public
    # repository,
    declare -a filesdirs=(
      ".credentials"
      ".gitconfig.local"
      ".ssh"
    )
    i=""
    for i in ${filesdirs[@]}; do  # loop through the array of files and directories to be copied
      if [[ -d "${i}" ]]; then  # if it's a directory
        cp -a "${i}" "${HOME}"  # copy it and all its files
        print_result "${?}" "Copied directory ${i}"
        chmod 700 "${HOME}/${i}"  # set the permissions on the directory itself to read/write/execute for the owner and nothing for others
        print_result "${?}" "Set permissions for the ${i} directory"
        chmod 600 "${HOME}/${i}"/*  # set the permissions on the files in the directory to read/write for the owner and nothing for others
        print_result "${?}" "Set permissions for the files in the ${i} directory"
      else  # otherwise it's a file
        cp -a "${i}" "${HOME}"  # copy it
        print_result "${?}" "Copied ${i}"
        chmod 600 "${HOME}/${i}"  # set its permissions to read/write for the owner and nothing for others
        print_result "${?}" "Set permissions for ${i}"
      fi
    done

    # if not installing on a Raspberry Pi, copy config files for Beyond Compare
    if [[ "${computername}" != "rpi"* ]]; then
      if [[ "${SYSTEM_TYPE}" == "macOS" ]]; then
        sudo cp -a BC4Key.txt /etc
        print_result "${?}" "Copied the Beyond Compare key file to '/etc'"
        sudo chmod 644 /etc/BC4Key.txt
        print_result "${?}" "Set permissions for the Beyond Compare key file"
        cp -a BCSettings-mac*.bcpkg "${HOME}"
        print_result "${?}" "Copied the Beyond Compare settings file"
        chmod 600 "${HOME}"/BCSettings-mac*.bcpkg
        print_result "${?}" "Set permissions for the Beyond Compare settings file"
      else
        [[ -d "${HOME}"/.config/bcompare ]]  # check to see if '.config/bcompare' exists
        retcode="${?}"
        if [[ "${retcode}" == 0 ]]; then  # it does
          print_result ${retcode} "'.config/bcompare' already exists"
        else
          mkdir -p "${HOME}"/.config/bcompare  # it doesn't, so create it
          print_result "${?}" "Created '.config/bcompare'"
          chmod 755 "${HOME}"/.config/bcompare  # and set its permissions
          print_result "${?}" "Set permissions for '.config/bcompare'"
        fi
        cp -a BC4Key.txt "${HOME}"/.config/bcompare
        print_result "${?}" "Copied the Beyond Compare key file to '"${HOME}"/.config/bcompare'"
        chmod 600 "${HOME}"/.config/bcompare/BC4Key.txt
        print_result "${?}" "Set permissions for the Beyond Compare key file"
        cp -a BCSettings-lin*.bcpkg "${HOME}"
        print_result "${?}" "Copied the Beyond Compare settings file"
        chmod 600 "${HOME}"/BCSettings-lin*.bcpkg
        print_result "${?}" "Set permissions for the Beyond Compare settings file"
      fi
    fi

    # if not installing on macOS, copy the samba config file to $HOME...it'll be
    # put where it belongs after 'samba' is installed
    if [[ "${SYSTEM_TYPE}" != "macOS" ]]; then
      case "${computername}" in
              nas) smbconffile="smb.conf-nas" ;;
        nasbackup) smbconffile="smb.conf-nasbackup" ;;
                *) smbconffile="smb.conf" ;;
      esac
      cp -a "${smbconffile}" "${HOME}"/smb.conf
      print_result "${?}" "Copied the samba config file"
    fi

    # if installing on 'nas' or 'nasbackup', copy the ddclient config file to
    # $HOME...it'll be put where it belongs after 'ddclient' is installed
    if [[ "${computername}" == "nas"* ]]; then
      cp -a ddclient.conf "${HOME}"
      print_result "${?}" "Copied the 'ddclient' config file"
    fi

    # if not installing on 'nas', 'nasbackup' or a Raspberry Pi, copy the
    # updated 'freeguide' .jar file...it'll be put where it belongs after
    # 'freeguide' is installed
    if [[ "${computername}" != "nas"* && "${computername}" != "rpi"* ]]; then
      cp -a FreeGuide.jar "${HOME}"
      print_result "${?}" "Copied the updated 'freeguide' .jar file"
    fi

    # if not installing on macOS, copy KDE configuration files
    if [[ "${SYSTEM_TYPE}" != "macOS" ]]; then
      # configure the lock screen
      lock_screen_clock="/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents/components/Clock.qml"
      if [[ -f "${lock_screen_clock}" ]]; then  # if the lock screen clock display exists (which it should)
        print_warn "The lock screen clock display already exists\n"  # say so
        sudo mv "${lock_screen_clock}" "${lock_screen_clock}".orig  # and back it up for later comparison
        print_result "${?}" "Backed it up for later comparison"
      fi
      sudo cp -a Clock-lock.qml "${lock_screen_clock}"  # copy the new lock screen display
      print_result "${?}" "Copied the new lock screen display"
      sudo chown root: "${lock_screen_clock}"  # change its ownership
      print_result "${?}" "Changed its ownership"
      sudo chmod 644 "${lock_screen_clock}"  # and change its permissions
      print_result "${?}" "Changed its permissions"

      # configure the login screen
      login_screen_clock="/usr/lib/x86_64-linux-gnu/qt5/qml/SddmComponents/Clock.qml"
      if [[ -f "${login_screen_clock}" ]]; then  # if the login screen clock display exists (which it should)
        print_warn "The login screen clock display already exists\n"  # say so
        sudo mv "${login_screen_clock}" "${login_screen_clock}".orig  # and back it up for later comparison
        print_result "${?}" "Backed it up for later comparison"
      fi
      sudo cp -a Clock-login.qml "${login_screen_clock}"  # copy the new login screen display
      print_result "${?}" "Copied the new login screen display"
      sudo chown root: "${login_screen_clock}"  # change its ownership
      print_result "${?}" "Changed its ownership"
      sudo chmod 644 "${login_screen_clock}"  # and change its permissions
      print_result "${?}" "Changed its permissions"

      # change to the '.config' directory and copy files
      cd .config  # change to the directory where the KDE configuration files are
      shopt -s dotglob
      shopt -s nullglob
      configfiles=(*)  # get a list of all the files in '.config' into an array.  the filenames are in the format 'filename'
      shopt -u nullglob
      for i in ${configfiles[@]}; do  # loop through the array of files to be copied
        configfilename="${HOME}/.config/${i}"
        if [[ -f "${configfilename}" ]]; then  # if the file already exists
          print_warn "${i} already exists\n"  # say so
          mv "${configfilename}" "${configfilename}".orig  # and back it up for later comparison
          print_result "${?}" "Backed it up for later comparison"
        fi
        cp -a "${i}" "${configfilename}"  # copy the updated file
        print_result "${?}" "Copied ${i}"
        chmod 600 "${configfilename}"  # and change its permissions
        print_result "${?}" "Changed permissions for ${i}"
      done
      cd ..  # change back to previous directory

      # configure the 'dolphin' view properties
      dolphin_view_prop_dir="${HOME}/.local/share/dolphin/view_properties/global"
      if [[ -f "${dolphin_view_prop_dir}/.directory" ]]; then  # if the file already exists
        print_warn "'${dolphin_view_prop_dir}/.directory' already exists\n"  # say so
        mv "${dolphin_view_prop_dir}/.directory" "${dolphin_view_prop_dir}/.directory.orig"  # and back it up for later comparison
        print_result "${?}" "Backed it up for later comparison"
      else
        if [[ -d "${dolphin_view_prop_dir}" ]]; then  # if the directory the file goes in already exists
          print_result ${retcode} "'${dolphin_view_prop_dir}' already exists"  # say so
        else
          mkdir -p "${dolphin_view_prop_dir}"  # otherwise, create it (and its parent directories as needed)
          print_result ${retcode} "Created '${dolphin_view_prop_dir}'"  # say so
        fi
      fi
      cp -a .directory "${dolphin_view_prop_dir}"  # copy the updated file
      print_result "${?}" "Copied ${dolphin_view_prop_dir}/.directory"
      chmod 600 "${dolphin_view_prop_dir}/.directory"  # and change its permissions
      print_result "${?}" "Changed permissions for ${dolphin_view_prop_dir}/.directory"
    fi

    # copy third-party programs to a temporary location, to be installed later
    if [[ "${SYSTEM_TYPE}" == "macOS" ]]; then
      # if necessary, create a directory for Homebrew Casks and third-party
      # software
      [[ -d "${HOME}"/Applications ]]  # check to see if '"${HOME}"/Applications' exists
      retcode="${?}"
      if [[ "${retcode}" == 0 ]]; then
        print_result "${retcode}" "'${HOME}/Applications' aleady exists"  # it does
      else
        mkdir "${HOME}"/Applications  # it doesn't, so create it
        print_result "${?}" "Created '${HOME}/Applications'"
      fi
      # copy third-party programs that aren't available in 'Homebrew' or that
      # the versions in 'Homebrew' won't run on the version of macOS I'm
      # running.  the programs must have been previously downloaded and located
      # on the NAS, with 'programdir' set to the directory they're located in
      i=""
      programdir="/Volumes/data/Downloads/Mac/InUse/Installed/Automated"  # the directory containing the program files to be copied
      extractdir="/tmp/Installers"  # the directory the program files get copied to so the programs can be extracted
      appdir="${HOME}/Applications"  # the directory the extracted programs get copied/installed to
      [[ -d "${extractdir}" ]]  # check to see if 'extractdir' exists
      retcode="${?}"
      if [[ "${retcode}" == 0 ]]; then
        print_result "${retcode}" "'${extractdir}' aleady exists"  # it does
      else
        mkdir "${extractdir}"  # it doesn't, so create it
        print_result "${?}" "Created '${extractdir}'"
      fi
      shopt -s dotglob
      shopt -s nullglob
      programs=("${programdir}/*")  # get a list of all the programs in 'programdir' into an array.  the filenames are in the format 'programdir/programfilename'
      shopt -u nullglob
      for i in ${programs[@]}; do  # loop through the array of programs to be installed
        ext=$("${HOME}"/bin/fp -e "${i}")  # extract the extension
        case "${ext}" in
          app)
               cp -a "${i}" "${appdir}"  # if it's a '.app', it's an already-extracted program, so copy it to 'appdir'
               print_result "${?}" "Installed ${i}"
               ;;
          xip)
               cp -a "${i}" "${appdir}"  # if it's a '.xip', it's a zipped program, so copy it to 'appdir' for extraction and installation later
               print_result "${?}" "Copied ${i} to ${appdir}"
               xip=1
               ;;
            *)
               cp -a "${i}" "${extractdir}"  # if it's none of the others, then copy it to 'extractdir' to be installed later
               print_result "${?}" "Copied ${i} to ${extractdir}"
               ;;
        esac
      done
    else
      # copy third-party programs that aren't available via 'apt'.  the programs
      # must have been previously downloaded and located on the NAS, with
      # 'programdir' set to the directory they're located in
      case "${computername}" in
        nas*)
              # all programs to be installed on 'nas' and 'nasback' are
              # available via 'apt'.  however, if there were some, this is the
              # directory they'd be located in
              #programdir="/nas/data/Downloads/Linux/InUse/Installed/Automated"
              ;;
        rpi*)
              # all programs to be installed on Raspberry Pi machines are
              # available via 'apt'.  however, if there were some, this is the
              # directory they'd be located in
              #programdir="${HOME}/mountpoint/Downloads/Linux/InUse/Installed/Automated"
              ;;
           *)
              declare -a programs=(
                "first"
                "freequide"
                "google-earth"
                "imager"
                "usbimager"
              )  # the programs array, each element of which is a program to be installed
              programdir="${HOME}/mountpoint/Downloads/Linux/InUse/Installed/Automated"  # the directory containing the programs to be copied
              ;;
      esac
      i=""
      programtmp="/tmp/programs"  # temporary location to hold programs until installed
      [[ -d "${programtmp}" ]]  # check to see if the temporary location exists
      retcode="${?}"
      if [[ "${retcode}" == 0 ]]; then
        print_result "${retcode}" "'${programtmp}' exists"  # it does
      else
        mkdir "${programtmp}"  # it doesn't, so create it
        print_result "${?}" "Created '${programtmp}'"
      fi
      for i in ${programs[@]}; do  # loop through the array of programs to be installed ...
        cp -a "${programdir}/${i}"* "${programtmp}"  # ... copying them to '/tmp/programs'
        print_result "${?}" "Copied ${i} to '${programtmp}'"
      done

      # the Terabyte programs live in their own directory, and the path to their
      # directory depends on the machine being installed on.  so, set
      # 'iflprogramdir' appropriately and copy the IFL files...unless installing
      # on a Raspberry Pi
      if [[ "${computername}" != "rpi"* ]]; then
        declare -a iflconfigfiles=(
          "BOOTITBM.INI"
          "config.txt"
          "ifl.ini"
        )
        if [[ "${computername}" == "nas"* ]]; then
          iflprogramdir="/nas/data/Downloads/TeraByte/InUse/Installed"
        else
          iflprogramdir="/mountpoint/Downloads/TeraByte/InUse/Installed"
        fi
        cp -a "${iflprogramdir}"/ifl_en_cui_x64* "${programtmp}"
        print_result "${?}" "Copied IFL to '${programtmp}'"
        for i in ${iflconfigfiles[@]}; do
          cp -a "${iflprogramdir}/ConfigFiles/${i}" "${HOME}"
          print_result "${?}" "Copied '${i}' to '${HOME}'"
        done
        cp -a "${iflprogramdir}/ConfigFiles/daily-backup" "${HOME}"
        print_result "${?}" "Copied 'daily-backup' script to '${HOME}'"
      fi

      # if installing on 'nas' or 'nasbackup', copy the 'shaarli' .zip file to
      # $HOME to be installed later
      if [[ "${computername}" == "nas"* ]]; then
        cp -a /nas/data/Downloads/Linux/InUse/Installed/shaarli* "${HOME}"/shaarli-full.zip
        print_result "${?}" "Copied the 'shaarli' .zip file to '${HOME}'"
      fi
    fi

    # done with the NAS
    cd "${currdir}"  # change back to where we were
    print_result "${?}" "Changed back to '${currdir}'"
    if [[ "${SYSTEM_TYPE}" == "macOS" ]]; then
      diskutil unmount /Volumes/data 1>/dev/null 2>&1  # unmount the NAS.  this also automatically deletes mountpoint '/Volumes/data'
      print_result "${?}" "Unmounted NAS"
    else
      if [[ "${computername}" != "nas"* ]]; then
        sudo "${HOME}"/bin/unmount "${HOME}"/mountpoint  # unmount the NAS
        print_result "${?}" "Unmounted NAS"
        rmdir "${HOME}"/mountpoint  # delete the mountpoint
        print_result "${?}" "Deleted mount point"
      fi
    fi

    # up until now, everything that's been installed has been installed on both
    # macOS and Linux systems, with the only variances being the commands used,
    # the locations of the files/programs, and that some Linux machines don't get
    # things that others do.  but from this point on, nothing that gets installed
    # on a macOS system gets installed on a Linux system, and vice versa.  so,
    # now OS-dependent scripts get sourced to finish things off
    case "${SYSTEM_TYPE}" in
      macOS) source ./macos.sh ;;
          *) source ./linux.sh ;;
    esac
    retcode="${numberoferrors}"
    if [[ "${retcode}" == 0 ]]; then
      message="All done...software installed and initial configuration done."
    else
      message="All done, but ${numberoferrors} errors occurred during software installation and initial configuration...check ${HOME}/installlog.txt."
    fi
  else
    message="'sudo' didn't get configured properly...exiting."
  fi
else
  message="Information incorrect...exiting."
fi

# print installation status message, then restore stdout (1) and stderr (2) and
# close the "backup" file descriptors (3 & 4)
print_result "${retcode}" "${message}"
exec 1>&3 2>&4 3>&- 4>&-
