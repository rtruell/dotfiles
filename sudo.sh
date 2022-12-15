#!/usr/bin/env bash

# some functions are needed, so load them
source ./.functions/print_error.function
source ./.functions/print_result.function
source ./.functions/print_success.function
source ./.functions/print_warn.function

# get the username to give 'sudo' permissions to
username=$(logname)
print_result "${?}" "User being given 'sudo' permissions is '${username}'"

# make it so the user can use 'sudo'...without having to type their password
if [[ -d /etc/sudoers.d ]]; then  # check to see if the directory '/etc/sudoers.d' exists
  print_result "${?}" "'/etc/sudoers.d' exists"
  if [[ -e /etc/sudoers.d/${username} ]]; then  # it does, so check to see if the file with the users 'sudo' permissions is already in it
    print_result "${?}" "'/etc/sudoers.d/${username}' exists"
  else
    printf "${username} ALL=(ALL:ALL) ALL  # allow me to use 'sudo'\nDefaults:${username} !authenticate  # without having to type my password\n" >/etc/sudoers.d/${username}  # it isn't, so create the file
    print_result "${?}" "Created '/etc/sudoers.d/${username}'"
    chmod 440 /etc/sudoers.d/${username}  # and change its permissions
    print_result "${?}" "Changed permissions for '/etc/sudoers.d/${username}'"
  fi
else
  mkdir /etc/sudoers.d  # the directory doesn't exist, so create it
  print_result "${?}" "Created '/etc/sudoers.d'"
  chmod 755 /etc/sudoers.d  # and change its permissions
  print_result "${?}" "Changed permissions for '/etc/sudoers.d'"
  printf "${username} ALL=(ALL:ALL) ALL  # allow me to use 'sudo'\nDefaults:${username} !authenticate  # without having to type my password\n" >/etc/sudoers.d/${username}  # create the file with the users 'sudo' permissions
  print_result "${?}" "Created '/etc/sudoers.d/${username}'"
  chmod 440 /etc/sudoers.d/${username}  # and change its permissions
  print_result "${?}" "Changed permissions for '/etc/sudoers.d/${username}'"
  if [[ $(grep -i 'includedir.*sudoers.d' /etc/sudoers) ]]; then  # check to see if '/etc/sudoers.d' already gets included by '/etc/sudoers'
    print_result "${?}" "'/etc/sudoers.d' already included by '/etc/sudoers'"
  else
    printf "\n%s\n" "#includedir /etc/sudoers.d" >>/etc/sudoers  # it doesn't, so add an 'includedir' directive to the end of '/etc/sudoers'
    print_result "${?}" "Added the necessary '#includedir' directive to '/etc/sudoers'"
  fi
fi
