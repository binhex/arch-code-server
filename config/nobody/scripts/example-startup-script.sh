#!/bin/bash

# aor packages
###

# Define AOR (Arch Official Repository) packages
pacman_packages=""

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed ${pacman_packages} --noconfirm
fi

# aur packages
###

# Define AUR (Arch User Repository) packages
aur_packages=""

# install compiled packages using helper 'yay'
if [[ ! -z "${aur_packages}" ]]; then
	source '/usr/local/bin/aur.sh'
fi
