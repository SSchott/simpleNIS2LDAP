groupmod -g 33 video
sed -i "s/NVreg_DeviceFileGID=.* /NVreg_DeviceFileGID=33 /g" /etc/modprobe.d/50-nvidia-default.conf
find /dev -group $(ls -n /dev/nvidia0 | awk '{print $4}') -exec chgrp -h video {} \;
zypper in -y sssd sssd-ldap
pam-config -a --sss
pam-config -d --unix-nis
systemctl disable ypbind.service
systemctl stop ypbind.service
systemctl disable nscd.service
systemctl stop nscd.service
