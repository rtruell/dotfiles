#!/usr/bin/env bash

StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# save stdout (1) and stderr (2) in "backup" file descriptors (3 & 4), and then
# redirect them so that the output and any error messages from the script are on
# both the screen and in a file...just in case there are errors that need to be
# referenced later.
exec 3>&1 4>&2  > >(tee -i "${HOME}"/installlog.txt) 2>&1

# some functions are needed to set things up, so load them
source ./.functions/answer_is_y.function
source ./.functions/apt_package_installer.function
source ./.functions/execute_command.function
source ./.functions/01#findcommand.function
source ./.functions/print_error.function
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

# get the users login name
username=$(logname)

# get the computer's host name, stripping off the domain name if it's there
computername=$(hostname -s)

# get the os type
if [[ -n ${OSTYPE} ]]; then
  case "${OSTYPE}" in
     darwin*) SYSTEM_TYPE="macOS" ;;
    solaris*) SYSTEM_TYPE="Solaris" ;;
      linux*) SYSTEM_TYPE="Linux" ;;
        bsd*) SYSTEM_TYPE="BSD" ;;
       msys*) SYSTEM_TYPE="MinGW" ;;
     cygwin*) SYSTEM_TYPE="Cygwin" ;;
           *) SYSTEM_TYPE="Unknown" ;;
  esac
else
  PLATFORM="$(uname)"
  case "${PLATFORM,,}" in
     darwin*) SYSTEM_TYPE="macOS" ;;
      sunos*) SYSTEM_TYPE="Solaris" ;;
      linux*) SYSTEM_TYPE="Linux" ;;
    freebsd*) SYSTEM_TYPE="FreeBSD" ;;
     netbsd*) SYSTEM_TYPE="Net_BSD" ;;
    openbsd*) SYSTEM_TYPE="Open_BSD" ;;
       msys*) SYSTEM_TYPE="MinGW" ;;
      mingw*) SYSTEM_TYPE="MinGW" ;;
     cygwin*) SYSTEM_TYPE="Cygwin" ;;
           *) SYSTEM_TYPE="Unknown" ;;
  esac
fi
if [[ -s /proc/version ]]; then
  if [[ -n "$(cat /proc/version | grep '(Microsoft@Microsoft.com)')" ]]; then SYSTEM_TYPE="Win10_Linux"; fi
fi

printf '%s\n' "  The following information has been automatically detected.  If any of it is"
printf '%s\n\n' "  wrong, or missing, reply 'n' to the prompt to abort the installation."
printf '\t%s\n' "User: ${username}"
printf '\t%s\n' "Computer: ${computername}"
printf '\t%s\n' "OS: ${SYSTEM_TYPE}"
printf "\n"
print_warn "Is this correct? (y/n) "
read -n 1
printf "\n"
answer_is_y "${REPLY}"
retcode=$?
if [[ "${retcode}" == 0 ]]; then
  # make it so the user can use 'sudo', and without having to type a password
  if [[ "${SYSTEM_TYPE}" == "macOS" ]]; then
    sudo source ./sudo.sh
    retcode=$?
  else
    su -c 'source ./sudo.sh'
    retcode=$?
  fi
  print_result "${retcode}" "Configured 'sudo'" "true"

  # symlink the dotfiles into ${HOME}
  source ./symlink.sh
  print_result $? "Symlinked dotfiles"

  if [[ "${SYSTEM_TYPE,,}" != "macos" ]]; then  # if not installing on macOS
    # add third-party software repositories to 'apt'
    source ./addrepos.sh
    print_result $? "Software repositories added"
    # if installing onto 'nas' or 'nasbackup', docker gets installed
    if [[ "${computername}" == "nas"* ]]; then source ./docker-nas.sh; print_result $? "Docker installed"; fi
    # install some packages, if necessary, so everything in the rest of this
    # script can be done
    declare -a packages=(
      "build-essential"
      "cifs-utils"
      "curl"
      "dmidecode"
      "file"
      "gnupg"
      "inxi"
      "linux-headers-amd64"
      "locate"
      "make"
      "openssh-server"
      "procps"
      "systemd"
    )
    for i in ${packages[@]}; do  # loop through the array of packages ...
      apt_package_installer "${i}"  # ... installing them if necessary
    done
  fi

  # mount the NAS' 'data' directory to access files and programs to be copied or
  # installed.  if installing on 'nas' or 'nasbackup', the files and programs
  # are directly available and nothing needs to be mounted.  however, even on
  # those machines, a variable has to be set with a directory path
  retcode=0  # holds the return code from commands
  currdir=${PWD}  # preserve the current directory
  message=""  # holds a status message to be printed
  osinstallfilesdir=""  # holds the directory where the files and program are located
  case "${SYSTEM_TYPE,,}" in
    macos)
           # this will prompt for the user/password, then try to create
           # mountpoint '/Volumes/data' and mount the NAS' data directory there
           osascript -e 'mount volume "smb://nas/data"' 1>/dev/null 2>&1
           retcode=$?
           if [[ "${retcode}" == 0 ]]; then
             message="NAS mounted"
             osinstallfilesdir="/Volumes/data/OSInstallFiles"
           else
             message="NAS mounting failed...sensitive files/directories and third-party software must be copied manually"
           fi
           ;;
        *)
           case "${computername}" in
             nas*)
                   # if installing on 'NAS' or 'NASbackup'
                   [[ -d /nas/data/OSInstallFiles ]]  # check to see if the NAS files are available
                   retcode=$?
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
                   print_result $? "Created mount point"
                   # mount it.  don't forget to change the user name as
                   # necessary.  note that this will ask for the password for
                   # that user on NAS
                   sudo mount -t cifs -o user=rtruell //nas/data "${HOME}"/mountpoint
                   retcode=$?
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
  print_result $? "Changed to the directory containing the sensitive files/directories to be copied"

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

  # if not installing on a Raspberry Pi, copy config files for Beyond Compare
  if [[ "${computername}" != "rpi"* ]]; then
    if [[ "${SYSTEM_TYPE,,}" == "macos" ]]; then
      sudo cp -a BC4Key.txt /etc
      print_result $? "Copied the Beyond Compare key file to '/etc'"
      sudo chmod 644 /etc/BC4Key.txt
      print_result $? "Set permissions for the Beyond Compare key file"
      cp -a BCSettings-mac*.bcpkg "${HOME}"
      print_result $? "Copied the Beyond Compare settings file"
      chmod 600 "${HOME}"/BCSettings-mac*.bcpkg
      print_result $? "Set permissions for the Beyond Compare settings file"
    else
      [[ -d "${HOME}"/.config/bcompare ]]  # check to see if '.config/bcompare' exists
      retcode=$?
      if [[ "${retcode}" == 0 ]]; then  # it does
        print_result ${retcode} "'.config/bcompare' already exists"
      else
        mkdir "${HOME}"/.config/bcompare  # it doesn't, so create it
        print_result $? "Created '.config/bcompare'"
        chmod 755 "${HOME}"/.config/bcompare  # and set its permissions
        print_result $? "Set permissions for '.config/bcompare'"
      fi
      cp -a BC4Key.txt "${HOME}"/.config/bcompare
      print_result $? "Copied the Beyond Compare key file to '"${HOME}"/.config/bcompare'"
      chmod 600 "${HOME}"/.config/bcompare/BC4Key.txt
      print_result $? "Set permissions for the Beyond Compare key file"
      cp -a BCSettings-lin*.bcpkg "${HOME}"
      print_result $? "Copied the Beyond Compare settings file"
      chmod 600 "${HOME}"/BCSettings-lin*.bcpkg
      print_result $? "Set permissions for the Beyond Compare settings file"
    fi
  fi

  # if not installing on macOS, copy the samba config file to $HOME...it'll be
  # put where it belongs after 'samba' is installed
  if [[ "${SYSTEM_TYPE,,}" != "macos" ]]; then
    case "${computername}" in
            nas) smbconffile="smb.conf-nas" ;;
      nasbackup) smbconffile="smb.conf-nasbackup" ;;
              *) smbconffile="smb.conf" ;;
    esac
    cp -a "${smbconffile}" "${HOME}"/smb.conf
    print_result $? "Copied the samba config file"
  fi

  # if installing on 'nas' or 'nasbackup', copy the ddclient config file to
  # $HOME...it'll be put where it belongs after 'ddclient' is installed
  if [[ "${computername}" == "nas"* ]]; then
    cp -a ddclient.conf "${HOME}"
    print_result $? "Copied the ddclient config file"
  fi

  # copy third-party programs to a temporary location, to be installed later
  if [[ "${SYSTEM_TYPE,,}" == "macos" ]]; then
    # if necessary, create a directory for Homebrew Casks and third-party
    # software
    [[ -d "${HOME}"/Applications ]]  # check to see if '"${HOME}"/Applications' exists
    retcode=$?
    if [[ "${retcode}" == 0 ]]; then
      print_result "${retcode}" "'${HOME}/Applications' aleady exists"  # it does
    else
      mkdir "${HOME}"/Applications  # it doesn't, so create it
      print_result $? "Created '${HOME}/Applications'"
    fi
    # copy third-party programs that aren't available in 'Homebrew' or that the
    # versions in 'Homebrew' won't run on the version of macOS I'm running.  the
    # programs must have been previously downloaded and located on the NAS,
    # with 'programdir' set to the directory they're located in
    i=""
    programdir="/Volumes/data/Downloads/Mac/InUse/Installed/Automated"  # the directory containing the program files to be copied
    extractdir="/Volumes/Temp/Installers"  # the directory the program files get copied to so the programs can be extracted
    appdir="${HOME}/Applications"  # the directory the extracted programs get copied/installed to
    [[ -d "${extractdir}" ]]  # check to see if 'extractdir' exists
    retcode=$?
    if [[ "${retcode}" == 0 ]]; then
      print_result "${retcode}" "'${extractdir}' aleady exists"  # it does
    else
      mkdir "${extractdir}"  # it doesn't, so create it
      print_result $? "Created '${extractdir}'"
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
             cp -a "${i}" "${extractdir}"  # if it's none of the others, then copy it to 'extractdir' to be installed later
             print_result $? "Copied ${i} to ${extractdir}"
             ;;
      esac
    done
  else
    # copy third-party programs that aren't available via 'apt'.  the programs
    # must have been previously downloaded and located on the NAS, with
    # 'programdir' set to the directory they're located in
    case "${computername}" in
      nas*)
            declare -a programs=(
              "archey"
            )  # the programs array, each element of which is a program to be installed
            programdir="/nas/data/Downloads/Linux/InUse/Installed/Automated"  # the directory containing the programs to be copied
            ;;
      rpi*)
            declare -a programs=(
              "archey"
            )
            programdir="${HOME}/mountpoint/Downloads/Linux/InUse/Installed/Automated"
            ;;
         *)
            declare -a programs=(
              "archey"
              "first"
              "freequide"
              "google-earth"
              "imager"
              "usbimager"
            )
            programdir="${HOME}/mountpoint/Downloads/Linux/InUse/Installed/Automated"
            ;;
    esac
    i=""
    programtmp="/tmp/programs"  # temporary location to hold programs until installed
    [[ -d "${programtmp}" ]]  # check to see if the temporary location exists
    retcode=$?
    if [[ "${retcode}" == 0 ]]; then
      print_result "${retcode}" "'${programtmp}' exists"  # it does
    else
      mkdir "${programtmp}"  # it doesn't, so create it
      print_result $? "Created '${programtmp}'"
    fi
    for i in ${programs[@]}; do  # loop through the array of programs to be installed ...
      cp -a "${programdir}/${i}"* "${programtmp}"  # ... copying them to '/tmp/programs'
      print_result $? "Copied ${i}"
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
      print_result $? "Copied IFL to '${programtmp}'"
      for i in ${iflconfigfiles[@]}; do
        cp -a "${iflprogramdir}/ConfigFiles/${i}" "${HOME}"
        print_result $? "Copied '${i}' to '${HOME}'"
      done
      cp -a "${iflprogramdir}/ConfigFiles/daily-backup" "${HOME}"
    fi
  fi

  # done with the NAS
  cd "${currdir}"  # change back to where we were
  print_result $? "Changed back to '${currdir}'"
  if [[ "${SYSTEM_TYPE,,}" == "macos" ]]; then
    diskutil unmount /Volumes/data 1>/dev/null 2>&1  # unmount the NAS.  this also automatically deletes mountpoint '/Volumes/data'
    print_result $? "Unmounted NAS"
  else
    if [[ "${computername}" != "nas"* ]]; then
      sudo "${HOME}"/bin/unmount "${HOME}"/mountpoint  # unmount the NAS
      print_result $? "Unmounted NAS"
      rmdir "${HOME}"/mountpoint  # delete the mountpoint
      print_result $? "Deleted mount point"
    fi
  fi

  # up until now, everything that's been installed has been installed on both
  # macOS and Linux systems, with the only variances being the commands used,
  # the locations of the files/programs, and that some Linux machines don't get
  # things that others do.  but from this point on, nothing that gets installed
  # on a macOS system gets installed on a Linux system, and vice versa.  so,
  # now OS-dependent scripts get sourced to finish things off
  case "${SYSTEM_TYPE,,}" in
    macos) source ./macos.sh ;;
        *) source ./linux.sh ;;
  esac
  retcode=0
fi

# restore stdout (1) and stderr (2) and close the "backup" file descriptors (3 &
# 4)
exec 1>&3 2>&4 3>&- 4>&-
exit "${retcode}"
