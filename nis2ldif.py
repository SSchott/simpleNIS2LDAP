

import os, sys
import glob

def parse_users(passwd="/etc/passwd", shadow="/etc/shadow"):
    print(f"Parsing users from {passwd} and {shadow}")
    users = {}
    with open(passwd, "r") as f:
        for entry in f.readlines():
            v = entry.strip().split(":")
            users[v[0]] = {"passwd":v[1],"uid":v[2],"gid":v[3],"gecos":v[4],"home":v[5],"shell":v[6]}

    with open(shadow, "r") as f:
        for entry in f.readlines():
            if entry.startswith("#"):
                continue
            v = entry.split(":")
            if v[0] in users:
                users[v[0]].update({"passwd_crypt":v[1],"last_update":v[2],"min":v[3],"max":v[4],"warn":v[5],"inactive":v[6],"expire":v[7]})
    return users

def parse_mountmaps(automount_base="/etc/auto."):
    map_files = glob.glob(automount_base+"*")
    master = {}
    maps = {}
    for _map in map_files:
        if os.path.basename(_map) in ["auto.smb","auto.net"] or os.path.isdir(_map):
            continue
        with open(_map, "r") as f:
            if os.path.basename(_map) == "auto.master":
                for line in f.readlines():
                    if line.startswith("#") or line.startswith("+"):
                        continue
                    v = line.split()
                    master[v[0]] = {"mapname":v[1],"options":v[2:]}
            else:
                maps[os.path.basename(_map)] = {}
                for line in f.readlines():
                    if line.startswith("#") or line.startswith("+"):
                        continue
                    #user       -rw,hard,intr,bg,wsize=8192,rsize=8192  IP:/homes/user
                    v = line.split()
                    try:
                        maps[os.path.basename(_map)][v[0]] = {"options":v[1],"location":v[2]}
                    except:
                        pass

    return(master, maps)

users = parse_users()
master, fsmaps = parse_mountmaps()
domain = "YOURDOMAIN"
suffix = "YOURDOMAINSUFFIX"
ldif = ""
ldif_users = ""
ldif_video = ""

ldif_users += f"""dn: cn=users,ou=groups,dc={domain},dc={suffix}
objectClass: posixGroup
objectClass: top
objectClass: groupOfNames
objectClass: nsMemberOf
cn: users
gidNumber: 100
"""

ldif_video = f"""
dn: cn=video,ou=groups,dc={domain},dc={suffix}
objectClass: posixGroup
objectClass: top
objectClass: groupOfNames
objectClass: nsMemberOf
cn: video
gidNumber: 33
"""

for user in users:
    data = users[user]
    if "home" not in data["home"] or user == "flatpak":
        continue
    ldif_users += f"""member: uid={user},ou=people,dc={domain},dc={suffix}\n"""
    ldif_video += f"""member: uid={user},ou=people,dc={domain},dc={suffix}\n"""
    ldif += f"""dn: uid={user},ou=people,dc={domain},dc={suffix}
memberOf: cn=users,ou=groups,dc={domain},dc={suffix}
memberOf: cn=video,ou=groups,dc={domain},dc={suffix}
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
uid: {user}
sn: {" ".join(data["gecos"].split()[1:])}
givenName: {data["gecos"].split()[0]}
cn: {user}
userPassword: {"{crypt}" if data["passwd"] == "x" else ""}{data["passwd_crypt"] if data["passwd"] == "x" else data["passwd"]}
loginShell: {data["shell"]}
uidNumber: {data["uid"]}
gidNumber: {data["gid"]}
homeDirectory: {data["home"]}
gecos: {data["gecos"]}
mail: {user}@{domain}.{suffix}
displayName: {data["gecos"]}

"""

ldif += f"""dn: ou=auto.master,dc={domain},dc={suffix}
ou: auto.master
objectClass: top
objectClass: automountMap
objectClass: organizationalUnit
aci: (targetattr="objectClass || automountInformation || cn ")(targetfilter="(objectClass=*)")(version 3.0; acl "Enable anyone user read"; allow (read, search, compare)(userdn="ldap:///anyone");)

"""

for _map in master:
    data=master[_map]
    ldif += f"""dn: cn={_map},ou=auto.master,dc={domain},dc={suffix}
cn: {_map}
objectClass: top
objectClass: automount
objectClass: groupOfNames
objectClass: nsMemberOf
objectClass: organizationalRole
automountInformation: {data["mapname"]} {" ".join(data["options"])}

dn: ou={data["mapname"]},dc={domain},dc={suffix}
ou: {data["mapname"]}
objectClass: top
objectClass: automountMap
objectClass: organizationalUnit
aci: (targetattr="objectClass || automountInformation || cn ")(targetfilter="(objectClass=*)")(version 3.0; acl "Enable anyone user read"; allow (read, search, compare)(userdn="ldap:///anyone");)

"""
    for entry in fsmaps[data["mapname"]]:
        data2 = fsmaps[data["mapname"]][entry]
        ldif += f"""dn: cn={entry},ou={data["mapname"]},dc={domain},dc={suffix}
cn: {entry}
objectClass: top
objectClass: automount
automountInformation: {data2["options"]} {data2["location"]}

"""

print("Writing output file")

open("nis2ldap.ldif","w").write(ldif+ldif_users+ldif_video)
