#!/bin/bash
#Installs my base packages (yes, including neofetch)
install-arch () { 
read -p "The drive must already be partitioned and mounted to /mnt before you continue. The EFI partition must also be mounted to /efi in the chroot (/mnt/efi); you will have to create this directory. This script will fully configure everything to my standards, minus installing any desktop environment or window manager. Ready to continue? (y/N) " choice
case "$choice" in
	y|Y) pacman --noconfirm -Sy; pacstrap /mnt base linux linux-firmware base-devel vim wget curl tmux git neofetch ranger dhcpcd pipewire pipewire-alsa pipewire-pulse pipewire-jack xorg && ( echo "Base packages successfully installed!" ) || ( echo "Failed to install base packages. Aborting..."; exit 1 );;
	*) echo "Aborting..."; exit;;
esac

genfstab -U /mnt >> /mnt/etc/fstab

#Create the rest of the script in the arch-chroot
cp chroot-scripts/arch-packages-chroot.sh /mnt
chmod +x /mnt/arch-packages-chroot.sh
arch-chroot /mnt ./arch-packages-chroot.sh

if [ -f "/mnt/unchoice" ]; then
#Retrieve unchoice variable from arch-chroot session, then delete the file containing it
	unchoice=$(cat /mnt/unchoice)
	rm /mnt/unchoice
	#Make user password
	while true
	do
		read -p "Enter password for $unchoice: " unchoicepasswd
		read -p "Retype password: " unchoicepasswdcheck
		if [ $unchoicepasswd = $unchoicepasswdcheck ]; then
			break
		else
			echo "Error: passwords do not match."; continue
		fi
	done
	#Put decided password into chpasswd
	echo "$unchoice:$unchoicepasswd" | arch-chroot /mnt chpasswd
	#Install yay
	arch-chroot /mnt ./arch-packages-chroot.sh --yay $unchoice
	cleanup
else
	cleanup
fi
}

cleanup () {
rm /mnt/arch-packages-chroot.sh
echo "Installation successful! You may now reboot into the system."
exit 0
}

#Allow Ctrl+C to escape script
trap <exit 2> SIGINT SIGTERM
#Check if PWD is arch-packages
case "$PWD" in
	*/arch-packages) install-arch;;
	*) cd arch-packages && ( install-arch ) || ( echo "Please execute this script from the arch-packages directory."; exit 1 );;
esac
