#!/usr/bin/env bash

# some functions to save duplicating (or worse) code
function add_webmin {
  # add the repository for Webmin to 'apt'
  sudo "${HOME}"/bin/add-apt-key --acng https://download.webmin.com/jcameron-key.asc webmin "deb https://download.webmin.com/download/repository sarge contrib"
  print_result $? "Added the Webmin repository to 'apt'"
}

function add_sublime {
  # add the repository for Sublime Text/Merge to 'apt'
  sudo "${HOME}"/bin/add-apt-key --acng https://download.sublimetext.com/sublimehq-pub.gpg sublimehq "deb https://download.sublimetext.com/ apt/stable/"
  print_result $? "Added the Sublime Text/Merge repository to 'apt'"
}

function add_bcompare {
  # add the repository for Beyond Compare to 'apt'
  sudo "${HOME}"/bin/add-apt-key --acng https://www.scootersoftware.com/RPM-GPG-KEY-scootersoftware bcompare "deb https://www.scootersoftware.com/ bcompare4 non-free"
  print_result $? "Added the Beyond Compare repository to 'apt'"
}

function add_docker {
  # add the repository for Docker to 'apt'
  sudo "${HOME}"/bin/add-apt-key --acng https://download.docker.com/linux/debian/gpg docker "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
  print_result $? "Added the Docker repository to 'apt'"
}

function create_proxy_file {
  printf "Acquire::http { Proxy \"http://nas:3142\"; };\n" | sudo tee /etc/apt/apt.conf.d/00proxy >/dev/null  # create the 'apt' proxy config file
  print_result $? "Created '/etc/apt/apt.conf.d/00proxy'"
  sudo chmod 644 /etc/apt/apt.conf.d/00proxy  # and set its permissions
  print_result $? "Changed permissions for '/etc/apt/apt.conf.d/00proxy'"
}

# if installing to 'nas', the web apps running in 'docker' are temporarily shut
# down while 1) repositories are added to 'apt' and 2) 'apt' is configured to
# use 'apt-cacher-ng' as a proxy
if [[ "${computername}" == "nas" ]]; then
  sudo docker compose down
fi

# discovered when installing from the Debian 11.2.0 DVD that the installer
# didn't comment out all of the installation media lines in
# '/etc/apt/sources.list', causing a problem when doing an 'apt update', so the
# media lines are commented out here, even if they're already commented
# out...more "#"'s don't hurt, but less do :-)  as well, I want access to the
# packages in the 'contrib' and 'non-free' repositories, so I add them to the
# repository lines here as well
sudo mv /etc/apt/sources.list /etc/apt/sources.list.orig  # back up 'sources.list', just in case
print_result $? "Backed up '/etc/apt/sources.list'"
while read -r repoline; do  # read in /etc/apt/sources.list.orig one line at a time
  if [[ ${repoline} == *"cdrom:"* ]]; then  # if it's a line for the installation media, comment it out, even if it's already commented out
    repoline="#"${repoline}
  fi
  if [[ ${repoline} == "deb"* ]]; then  # if it's a line for one of the repositories
    if [[ ${repoline} != *"contrib"* ]]; then  # if 'contrib' isn't there, add it
      repoline+=" contrib"
    fi
    if [[ ${repoline} != *"non-free"* ]]; then  # if 'non-free' isn't there, add it
      repoline+=" non-free"
    fi
  fi
  printf '%s\n' "${repoline}" | sudo tee -a /etc/apt/sources.list >/dev/null  # print the (possibly updated) line to a new '/etc/apt/sources.list'
done < /etc/apt/sources.list.orig
print_result 0 "Updated '/etc/apt/sources.list' with the 'contrib' and 'non-free' repositories, and commented out the installation media lines"

# add software repositories to 'apt' based on the computer name
case "${computername,,}" in
  nas | nasbackup) add_webmin; add_sublime; add_bcompare; add_docker ;;
  rpi*) add_webmin; add_sublime ;;
  *) add_webmin; add_sublime; add_bcompare ;;
esac

# add a file to '/etc/apt/apt.conf.d' so that this machine will proxy 'apt'
# requests through 'apt-cacher-ng'.  first, check to see if that directory
# exists.  this is actually a paranoia check...it should have been created
# during the base OS installation.  if it wasn't, it will be created here, but
# there will probably be problems during the operation of the OS, since files
# that should have been installed weren't :-(  then check for the existence of
# the proxy config file and create it if necessary

if [[ -d /etc/apt/apt.conf.d ]]; then
  print_result $? "'/etc/apt/apt.conf.d' exists"
  if [[ -e /etc/apt/apt.conf.d/00proxy ]]; then  # the directory exists, so check to see if the proxy config file is already in it
    print_result $? "'/etc/apt/apt.conf.d/00proxy' exists"
    if [[ $(grep -i 'nas:3142' /etc/apt/apt.conf.d/00proxy) ]]; then  # it is, so check to see if the proxy config is in it
      print_result $? "and already contains the proxy config"
    else
      grep_result=$?  # it isn't, so print some warning messages, back up the current file and create the new one
      print_warn ${grep_result} "but doesn't contain the proxy config"
      print_warn ${grep_result} "backing it up for later comparison"
      print_warn ${grep_result} "and creating a new one"
      sudo mv /etc/apt/apt.conf.d/00proxy /etc/apt/apt.conf.d/00proxy-old
      print_result $? "backed up '/etc/apt/apt.conf.d/00proxy'"
      create_proxy_file
    fi
  else
    create_proxy_file  # it isn't, so create the file
  fi
else
  sudo mkdir /etc/apt/apt.conf.d  # the directory doesn't exist, so create it
  print_result $? "Created '/etc/apt/apt.conf.d'"
  sudo chmod 755 /etc/apt/apt.conf.d  # change its' permissions
  print_result $? "Changed permissions for '/etc/apt/apt.conf.d'"
  create_proxy_file  # create the file with the proxy config
fi

# done adding repositories and configuring 'apt', so if installing to 'nas',
# time to start the web apps again
if [[ "${computername}" == "nas" ]]; then
  sudo docker compose up -d
fi

# update apt to pick up the new repositories, and then do an upgrade, just in
# case.  one of the times this script was run caused a problem I've never had
# before...a program prevented 'apt' from locking a directory, which
# prevented 'apt' from updating the source file lists, which would have caused
# this script to fail when trying to install programs from the just-added
# repositories.  so, had to implement a check to make sure 'apt' could update
# itself before continuing on.  and while I was at it, figured I'd better put in
# a check for the 'apt upgrade' as well
retcode=1  # set the return code to 'failed' to start trying to update 'apt'
while [[ "${retcode}" != 0 ]]; do  # keep trying as long as the last try failed
  sudo apt update  # try to update
  retcode=$?  # preserve the return code
  if [[ "${retcode}" != 0 ]]; then sleep 5; fi  # if the update failed, wait 5 seconds before trying again
done
print_result "${retcode}" "apt updated"  # finally...a successful update!!
retcode=1  # now do the same thing trying to upgrade the packages
while [[ "${retcode}" != 0 ]]; do
  sudo apt upgrade
  retcode=$?
  if [[ "${retcode}" != 0 ]]; then sleep 5; fi
done
print_result "${retcode}" "apt upgraded"
