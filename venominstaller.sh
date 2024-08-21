#!/bin/bash

# Created by isaachhk02 
#
#  1.0.0
#

cat << EOF
 _     _____ _      ____  _      _  _      ____  _____  ____  _     _     _____ ____ 
/ \ |\/  __// \  /|/  _ \/ \__/|/ \/ \  /|/ ___\/__ __\/  _ \/ \   / \   /  __//  __
| | //|  \  | |\ ||| / \|| |\/||| || |\ |||    \  / \  | / \|| |   | |   |  \  |  \/|
| \// |  /_ | | \||| \_/|| |  ||| || | \||\___ |  | |  | |-||| |_/\| |_/\|  /_ |    /
\__/  \____\_/  \|\____/\_/  \|\_/\_/  \|\____/  \_/  \_/ \|\____/\____/\_____/\_/  L
                                                                                     
 _  ____  ____  ____  ____  _     _     _  __ ____  ____                             
/ \/ ___\/  _ \/  _ \/   _\/ \ /|/ \ /|/ |/ //  _ \/_   \                            
| ||    \| / \|| / \||  /  | |_||| |_|||   / | / \| /   /                            
| |\___ || |-||| |-|||  \_ | | ||| | |||   \ | \_/|/   /_                            
\_/\____/\_/ \|\_/ \|\____/\_/ \|\_/ \|\_|\_\____/\____/
EOF
export USER="$2"
export DEV="$1"

export IS_NVME=0

question=""

Install() {
	echo "Wiping $DEV"
	wipefs -a "$DEV"
	echo "Done!"
	# Check if its a NVMe
	if [[ $DEV == "/dev/nvme0*" ]]; then
		echo "NVMe detected!"
		IS_NVME=1
	fi
	echo "Creating GPT Table for ${DEV}"
	parted -s "${DEV}" mklabel gpt
	echo "Done!"

	echo "Creating EFI partition on $DEV"
	parted -s "${DEV}" mkpart primary fat32 1% 1024MiB
	echo "Setting as EFI!"
	parted -s "${DEV}" set 1 esp on
 	
	echo "Done!"
	echo "Creating root partition on $DEV"
	parted -s "${DEV}" mkpart primary ext4 1024MiB 100%
 	
	echo "Done!"

	mkdir -p /mnt/venom/boot
	echo "Mounting partitions to /mnt/venom!"
	if [[ "$IS_NVME" -eq 1 ]]; then
 		mkfs.vfat -F 32 "$DEV"p1
   		mkfs.ext4 "$DEV"p2
		mount "$DEV"p1 /mnt/venom/boot
		mount "$DEV"p2 /mnt/venom
	else
 		mkfs.vfat -F 32 "$DEV"1
   		mkfs.ext4 "$DEV"2
		mount "$DEV"1 /mnt/venom/boot
		mount "$DEV"2 /mnt/venom
	fi
	echo "Installing Venom Linux"
	unsquashfs -v -f -d /mnt/venom /run/initramfs/medium/rootfs/filesystem.sfs
	echo "Done!"
	git clone https://github.com/archlinux/arch-install-scripts.git
	cd "arch-install-scripts" || return
	make
 	cp -v genfstab arch-chroot /bin
	if [[ "$IS_NVME" -eq 1 ]]; then
		arch-chroot /mnt/venom mount "$DEV"p1 /boot
	else
		arch-chroot /mnt/venom mount "$DEV"1 /boot
	fi
 	arch-chroot /mnt/venom grub-install --target=x86_64-efi --efi-directory=/boot
  	arch-chroot /mnt/venom grub-mkconfig -o /boot/grub/grub.cfg
	genfstab -U /mnt/venom > /mnt/venom/etc/fstab
	echo "Creating user: $USER"
	arch-chroot /mnt/venom useradd -m "$USER"
	arch-chroot /mnt/venom passwd "$USER"
	echo "Created successfully!"

	arch-chroot /mnt/venom usermod -aG wheel "$USER"
	echo "Added to wheel group"
	arch-chroot /mnt/venom usermod -aG sudo "$USER"
	umount -l -f "$DEV"

	echo "Write reboot to reboot your computer and cross your fingers!"
}



if [[ $EUID -eq 0 ]]; then
	if [[ -z $1 || -z $2 ]]; then
		echo "Syntax: venominstaller [device] [user]"
		echo "ERROR: No arguments passed!"
	else

		echo "Selected device: $DEV"
		echo "Selected user: $USER"
		read -r -p "Are you sure to proceed? THIS ERASE YOUR DISK ENTIRELY AND ERASE THE DATA! (y/n) " "question"
		if [ "${question}" == "" ]; then
			echo "Aborted!"
			exit
		elif [ "${question}" == "y" ]; then
			clear
			echo "Starting installer"
			Install
		else
			echo "Aborted"
			exit
		fi
	fi
	if [[ $1 == "--help" || $1 == "-h" ]]; then
		echo "Syntax: venominstaller [device] [user]"
	fi
else
	echo "ERROR: Run as root!"
fi
