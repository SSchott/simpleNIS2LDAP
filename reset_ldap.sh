dsctl YOURSERVERNAME remove --do-it
dscreate -v from-file YOURSERVERNAME.inf | tee dscreate-output.txt
dsconf YOURSERVERNAME plugin memberof enable
dsconf YOURSERVERNAME plugin referential-integrity enable
dsctl YOURSERVERNAME restart
ldapadd -x -f nis2ldap.ldif -D "cn=Directory Manager" -W
