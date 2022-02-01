#!/bin/sh
#Replace sudo with opendoas once you've installed an AUR helper, or build it from source.
pacstrap /mnt base linux linux-firmware sudo base-devel vim wget curl screen tmux git neofetch ranger dhcpcd networkmanager
echo "Remember to start NetworkManager.service after reboot. Install an AUR helper. Configuring NetworkManager is hard to remember so here: https://wiki.archlinux.org/title/NetworkManager (use nmcli)."
echo "Not all packages will necessarily be installed. Install as necessary. No X server packages are included, nor any graphical desktop environment or standalone window manager."
