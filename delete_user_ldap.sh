#!/bin/bash

echo "Will delete a user according to the provided info. Pass the root password if prompted"
echo "Type the username:"
read USERNAME

userdel $USERNAME

echo ""
echo "Deleting ldap user..."
cat << EOF > ldap_delete.ldif
dn: uid=${USERNAME},ou=people,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: delete

dn: cn=${USERNAME},ou=auto.home,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: delete

dn: cn=${USERNAME},ou=auto.store1,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: delete

EOF

echo ""
echo "Deleting SLURM user..."
sacctmgr -i delete user ${USERNAME} Account=YOURSERVERNAME

NODEIP=$(grep ${USERNAME} /etc/auto.home | awk '{print $3}' | cut -d: -f1)
sed -i "/^${USERNAME}/d" /etc/auto.home
sed -i "/^${USERNAME}/d" /etc/auto.store1

ldapmodify -x -f ldap_delete.ldif -D "cn=Directory Manager" -W

rm ldap_delete.ldif

echo ""
echo "Deleting home directory in ${NODEIP}"
ssh ${NODEIP} "rm -rf /homes/${USERNAME}; exportfs -ra; systemctl restart autofs" 

echo ""
echo "Deleting store directory in store1"
ssh YOURSTORENODEIP "rm -rf /YOURSTOREPATH${USERNAME}; exportfs -ra; systemctl restart autofs"

