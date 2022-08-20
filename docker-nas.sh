#!/usr/bin/env bash

# install 'docker' on 'nas' or 'nasbackup'
printf "\n\e[0;35m  Installing 'docker'.\e[0m\n\n"
declare -a docker=(
  "docker-ce"
  "docker-ce-cli"
  "containerd.io"
  "docker-compose-plugin"
)
for i in ${docker[@]}; do
  apt_package_installer "${i}"
done

# copy over the files needed for running the desired web apps under 'docker'.
# 'apt-cacher-ng' is the only one that's really needed right now, but since one
# is being loaded, might as well load the others as well
declare -a webapps=(
  "apt-cacher-ng"
  "mariadb"
  "owncloud"
  "redis"
  "shaarli"
)
i=""
for i in ${webapps[@]}; do  # loop through the array of webapps to be installed ...
  cp -a "/nas/data/Downloads/Linux/InUse/Installed/Automated/Docker/nas/${i}.docker" "${HOME}"  # ... and copy their image files to the user's HOME directory
  print_result $? "Copied ${i}"
done
cp -a /nas/data/Downloads/Linux/InUse/Installed/Automated/Docker/nas/docker-compose.yaml "${HOME}"  # copy the Docker Compose .yaml file to the user's HOME directory...
print_result $? "Copied 'docker-compose.yaml'"
chmod 600 "${HOME}"/docker-compose.yaml  # ... and set its permissions
print_result $? "Set permissions for 'docker-compose.yaml'"

# create the symlink to move Docker's storage off of the SSD
sudo ln -s /nas/docker /var/lib/docker
print_result $? "Created the symlink to get Docker storage off of the SSD"

# load the images for the web apps to be run
for i in "${webapps[@]}"; do  # loop through the array of webapps to be installed ...
  sudo docker load -i "${HOME}/${i}.docker"  # ... and install them
  print_result $? "Installed ${i}"
  rm "${HOME}/${i}.docker"  # don't need this copy of the image file anymore, so delete it
  print_result $? "Deleted ${i} image file"
done

# add the user to the 'docker' group so they don't have to use 'sudo'.
# unfortunately, this doesn't take effect until the user logs out and back in,
# which won't be until after the install is finished...so until then, 'sudo'
# still needs to be used to run 'docker' commands during the install
sudo usermod -aG docker "${username}"
print_result $? "Added '${username}' to the 'docker' group"

# start the web apps
sudo docker compose up -d
print_result $? "Web apps started"
