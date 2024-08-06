#!/bin/bash

echo "Will generate a user according to the provided info. Pass the root password if prompted"
echo "Type the username:"
read USERNAME
echo "Type First Name:"
read FIRSTNAME
echo "Type Last Name:"
read LASTNAME
FULLNAME=$(echo ${FIRSTNAME}" "${LASTNAME})
echo "Type the pass:"
stty -echo
read PWD
stty echo
if grep --quiet "/homes/${USERNAME}" /etc/auto.home
then
echo "${USERNAME} home directory already available in /etc/auto.home. Remove it and rerun the script."
exit
fi
echo "In which node should the home directory be created?:"
read NODENAME

echo ""
echo "Creating ldap user..."
useradd -p $(echo "${PWD}" | openssl passwd -1 -stdin) ${USERNAME} -G audio,video -c "${FULLNAME}"

ID=$(id -u ${USERNAME})

cat << EOF > new_user.ldif
dn: uid=${USERNAME},ou=people,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: add
memberOf: cn=users,ou=groups,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
memberOf: cn=video,ou=groups,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
objectClass: top
objectClass: person
objectClass: account
objectClass: inetUser
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
objectClass: nsOrgPerson
objectClass: nsAccount
objectClass: nsPerson
uid: $USERNAME
sn: $LASTNAME
givenName:$FIRSTNAME
cn: $USERNAME
userPassword: {crypt}$(echo "${PWD}" | openssl passwd -1 -stdin)
loginShell: /bin/bash
uidNumber: $ID
gidNumber: 100
homeDirectory: /home/${USERNAME}
gecos: $FIRSTNAME $LASTNAME
mail: $USERNAME@YOURDOMAIN.YOURDOMAINSUFFIX
displayName: $FIRSTNAME $LASTNAME

dn: cn=users,ou=groups,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: modify
add:member
member: uid=${USERNAME},ou=people,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX

dn: cn=video,ou=groups,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: modify
add:member
member: uid=${USERNAME},ou=people,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX

EOF

echo ""
echo "Creating SLURM user..."
sacctmgr -i add user ${USERNAME} Account=YOURSERVERNAME

echo ""
echo "Adding export to ds and auto.home..."
NODEIP=$(resolveip -s ${NODENAME})
cat << EOF >> new_user.ldif
dn: cn=${USERNAME},ou=auto.home,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: add
cn: ${USERNAME}
objectClass: top
objectClass: automount
automountInformation: -rw,hard,intr,bg,wsize=8192,rsize=8192 ${NODEIP}:/homes/${USERNAME}

EOF

echo "${USERNAME}          -rw,hard,intr,bg,wsize=8192,rsize=8192  ${NODEIP}:/homes/${USERNAME}" >> /etc/auto.home

echo ""
echo "Adding export to ds and auto.store1..."
cat << EOF >> new_user.ldif
dn: cn=${USERNAME},ou=auto.store1,dc=YOURDOMAIN,dc=YOURDOMAINSUFFIX
changetype: add
cn: ${USERNAME}
objectClass: top
objectClass: automount
automountInformation: -rw,hard,intr,bg,wsize=8192,rsize=8192 YOURSTORENODEIP:/YOURSTOREPATH${USERNAME}

EOF

echo "${USERNAME}          -rw,hard,intr,bg,wsize=8192,rsize=8192  YOURSTORENODEIP:/YOURSTOREPATH${USERNAME}" >> /etc/auto.store1

ldapadd -x -f new_user.ldif -D "cn=Directory Manager" -W

echo ""
echo "Creating home directory in ${NODENAME}"
ssh ${NODENAME} "mkdir /homes/${USERNAME}; chown -R ${USERNAME}:users /homes/${USERNAME}; exportfs -ra; systemctl restart autofs" 

echo ""
echo "Creating store directory in store1"
ssh YOURSTORENODEIP "mkdir /YOURSTOREPATH${USERNAME}; chown -R ${USERNAME}:users /YOURSTOREPATH${USERNAME}; exportfs -ra; systemctl restart autofs"

echo ""
echo "Adding google-authenticator config in YOURENTRYNODE"
ssh YOURENTRYNODE sudo -u ${USERNAME} -E env "PATH=$PATH" google-authenticator -t -d -f -r 3 -R 30 -W


echo ""
echo "Check that /etc/auto.home is correct!"

