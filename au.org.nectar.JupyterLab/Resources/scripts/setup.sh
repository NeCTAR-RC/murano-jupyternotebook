#!/bin/bash -xe

USERNAME="$1"
ORIGUSER="ubuntu"

# Assume last disk is our attached storage,
# except /dev/vda which is our root disk
DISK=$(ls /dev/vd[b-z] | tail -n1)

# Check if the disk is mounted (e.g. if ephemeral)
MOUNTPOINT=$(lsblk -n $DISK -o MOUNTPOINT)

# If we have a disk, but it's not mounted, then it's probably
# our external volume for home
if [ ! -z $DISK ] && [ -z $MOUNTPOINT ]; then

	# Have external mount for /home
	MOUNT="/homevol"

	# Partition label
	if [ "$(lsblk -n -o PARTTYPE $DISK)" == "" ]; then
		parted $DISK mklabel msdos
	fi

	# Partition
	if ! lsblk -n $DISK | grep -q " part "; then
		parted -a opt $DISK mkpart primary ext4 0% 100%
	fi

	# Filesystem
	if [ "$(lsblk -n -o FSTYPE ${DISK}1)" == "" ]; then
		mkfs.ext4 ${DISK}1
	fi

	# Mount volume
	if ! mount | grep -q $MOUNT; then
		mkdir -p $MOUNT
		echo "${DISK}1 $MOUNT ext4 defaults 0 2" >> /etc/fstab
		mount $MOUNT
	fi
else
	# Use regular /home if no volume is found
	MOUNT="/home"
fi

if [ "$USERNAME" != "$ORIGUSER" ]; then

	# If orig user doesn't exist, assume this has been done already
	if id "$ORIGUSER"; then

		# Stop any running notebook before renaming user
		su - $ORIGUSER -c "$SHELL -x" <<-EOF
			export XDG_RUNTIME_DIR="/run/user/\$(id -u $ORIGUSER)"
			systemctl --user stop jupyter-lab.service
			systemctl --user disable jupyter-lab.service
	EOF

		sleep 5
		killall -u $ORIGUSER || true
		sleep 5
		killall -9 -u $ORIGUSER || true

		# Rename the user
		usermod --login $USERNAME $ORIGUSER
		if [ -d $MOUNT/$USERNAME ]; then
			# Set home dir to existing volume, and make 'users' the primary group
			usermod --home $MOUNT/$USERNAME --gid users --comment $USERNAME $USERNAME
			# Append cloud-init ssh key to authorized_keys file in existing home
			cat /home/$ORIGUSER/.ssh/authorized_keys >> $MOUNT/$USERNAME/.ssh/authorized_keys
			# cloud-init home dir not needed so remove it
			rm -rf /home/$ORIGUSER
		else
			# Set and move home dir to new location, and make 'users' the primary group
			usermod --home $MOUNT/$USERNAME --move-home --gid users --comment $USERNAME $USERNAME
		fi

		# Replace cloud user in cloud-init
		sed -i -e "s/name: $ORIGUSER/name: $USERNAME/g" -e "s/gecos: .*/gecos: $USERNAME/g" /etc/cloud/cloud.cfg
		sed -i "s/$ORIGUSER/$USERNAME/g" /etc/sudoers.d/90-cloud-init-users
	fi
fi

set +x
# Set password for user (and don't log it)
PASSWORD="$2"
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Nuke the password from the murano log file
#sed -i "s/$PASSWORD/******/g" /var/log/murano-agent.log
set -x

# Set up Jupyter Notebook with the same password
su - $USERNAME -c "$SHELL +x" << EOF
	mkdir -p ~/.jupyter
	PASSWORD='$PASSWORD'  # Fix for bash string handling
	python3 -c 'from notebook.auth.security import set_password; set_password(password="'\$PASSWORD'")'
EOF

loginctl enable-linger $USERNAME

USERID=$(id -u $USERNAME)
systemctl start user@$USERID.service

# Run as our new user
su - $USERNAME -c "$SHELL -x" <<-EOF
	mkdir -p ~/Notebooks
	export XDG_RUNTIME_DIR="/run/user/$USERID"
	systemctl --user enable jupyter-lab.service
	systemctl --user restart jupyter-lab.service
EOF

# vim: ts=2 sw=2 :
