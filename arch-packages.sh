#!/bin/bash
#Installs my base packages (yes, including neofetch)
read -p "The drive must already be partitioned and mounted to /mnt before you continue. The EFI partition must also be mounted to /efi in the chroot (/mnt/efi); you will have to create this directory. This script will fully configure everything to my standards, minus installing any desktop environment or window manager. Ready to continue? (y/N) " choice
case "$choice" in
	y|Y) pacman --noconfirm -Sy; pacstrap /mnt base linux linux-firmware base-devel vim wget curl tmux git neofetch ranger dhcpcd pipewire pipewire-alsa pipewire-pulse pipewire-jack xorg && ( echo "Base packages successfully installed!" ) || ( echo "Failed to install base packages. Aborting..."; exit 1 );;
	*) echo "Aborting..."; exit;;
esac

genfstab -U /mnt >> /mnt/etc/fstab

#Create the rest of the script in the arch-chroot
cat >/mnt/arch-packages-chroot.sh <<'EOF'
#!/bin/bash

#Enable multilib support
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

#Sync pacman
pacman --noconfirm -Sy

#Allow users to choose sudo later
pacman -R sudo

#Set timezone to New York (change as desired)
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

#Set locale to en_US.UTF-8 UTF-8
echo "en_US.UTF8 UTF-8" > /etc/locale.gen && locale-gen && touch /etc/locale.conf && echo "LANG=en_US.UTF-8" > /etc/locale.conf

#Create the hostname file
while :
do
	read -p "Enter the system's hostname: " hostname
	case "$hostname" in
		"") echo "Please type a hostname. Alternatively, press Ctrl+C to exit the script."; continue;;
		*) echo $hostname > /etc/hostname; break;;
	esac
done

#Enable Network
systemctl enable dhcpcd.service
read -p "Do you want to enable Wi-Fi? (Y/n) " networkchoice
case "$networkchoice" in
	n|N) :;;
	*) echo "Enabling NetworkManager..."; pacman --noconfirm -S networkmanager && systemctl enable NetworkManager.service;;
esac

#Enable Bluetooth
read -p "Do you want to enable Bluetooth? (Y/n) " btchoice
case "$btchoice" in
	n|N) :;;
	*) echo "Enabling Bluetooth..."; pacman --noconfirm -S bluez bluez-utils && systemctl enable bluetooth.service;;
esac

#Install GPU drivers
while :
do
	read -p "What type of graphics card are you using? (amd/intel/nvidia/NONE) " graphicschoice
	case "$graphicschoice" in
		amd|AMD|Amd) echo "Installing AMD drivers..."; 
			while :
			do
				read -p "AMDGPU or ATI? (AMDGPU/ATI) " archichoice
				case "$archichoice" in
					amdgpu|AMDGPU) echo "AMDGPU installing..."; pacman --noconfirm -S xf86-video-amdgpu mesa lib32-mesa && ( break ) || ( exit 1 );;
					ati|ATI) echo "ATI installing..."; pacman --noconfirm -S mesa xf86-video-ati lib32-mesa mesa-vdpau lib32-mesa-vdpau && ( break ) || ( exit 1 );;
					*) echo "Please select an option."; continue;;
				esac
			done;;
		intel|INTEL|Intel) echo "Installing Intel drivers..."; pacman --noconfirm -S xf86-video-intel mesa lib32-mesa && ( break ) || ( exit 1 );;
		nvidia|NVIDIA|Nvidia|NVidia) echo "Installing NVidia drivers...";
			while :
			do
				read -p "Open Source or Proprietary (open/proprietary) " nvchoice
				case "$nvchoice" in
					open) pacman --noconfirm -S xf86-video-nouveau mesa lib32-mesa && ( break ) || ( exit 1 );;
					proprietary) echo "Please follow the installation guide upon reboot to install proprietary drivers."; break;;
				esac
			done;;
		none|NONE|None) break;;
		*) continue;;
	esac
done

#Enable microcode updates
while :
do
	read -p "What type of CPU are you using? (amd/intel) " cpuchoice
	case "$cpuchoice" in
		amd|AMD|Amd) echo "Installing AMD Microcode updates..."; pacman --noconfirm -S amd-ucode && break;;
		intel|INTEL|Intel) echo "Installing Intel Microcode updates..."; pacman --noconfirm -S intel-ucode && break;;
		*) echo "Please select an option."; continue;;
	esac
done

#Ask if the user wants to install sudo or doas
while :
do
	read -p "Which would you like to install: sudo or doas? (sudo/doas) " sudochoice
	case "$sudochoice" in
		sudo) pacman --noconfirm -S sudo; visudo; break;;
		doas) pacman --noconfirm -S doas; echo "permit :wheel" > /etc/doas.conf; break;;
		*) echo "Please select either sudo or doas. Alternatively, press Ctrl+C to exit the script."; continue;;
	esac
done

#Set the root password
echo "Set the root password:"
passwd

#Create a new user
read -p "Would you like to create a user? (Y/n) " userchoice
case "$userchoice" in
	n|N) :;;
	*) while :;
		do
			read -p "Enter a username: " unchoice;
			case "$unchoice" in
				"") echo "Entry cannot be blank."; continue;;
				*) useradd -m -G wheel $unchoice && ( passwd $unchoice ) || ( echo "User failed to add."; continue );;
			esac
			break
		done
		cat >/home/$unchoice/yay.sh <<'EOFYAY'
#!/bin/bash
echo "Installing yay..."
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -sri
cd ..
rm -rf yay
exit 0
EOFYAY
		chmod +x /home/$unchoice/yay.sh
		su $unchoice -c /home/$unchoice/yay.sh
		rm /home/$unchoice/yay.sh;;
esac

#Install bootloader
pacman --noconfirm -S grub
while :
do
	read -p "What is the path of your DISK (NOT a partition; e.g. input something like /dev/sdX)? " diskpath
	case "$diskpath" in
		/dev/*) break;;
		*) echo "Field must be in the format: /dev/disktypeX."; continue;;
	esac
done

while :
do
	read -p "Do you have BIOS or UEFI? (bios/uefi) " grubchoice
	case "$grubchoice" in
		bios|BIOS|Bios) grub-install --target=i386-pc $diskpath; break;;
		uefi|UEFI|Uefi) pacman --noconfirm -S efibootmgr && ( grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB && ( break ) || ( exit 1 ) ) || ( exit 1 );;
		*) echo "Please selet an option."; continue;;
	esac
done

echo "Generating grub.cfg..."; grub-mkconfig -o /boot/grub/grub.cfg || exit 1

exit 0
EOF

chmod +x /mnt/arch-packages-chroot.sh
arch-chroot /mnt ./arch-packages-chroot.sh
rm /mnt/arch-packages-chroot.sh
echo "Installation successful! You may now reboot into the system."
exit 0
