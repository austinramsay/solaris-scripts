Solaris scripts to modify pam.conf to support LDAP authentication.
Please note that these scripts were tested with Solaris release 5/09.

Another version was created to modify a pam.conf on a Sun Ray Server to support LDAP authentication.
The script was tested with Solaris 5/09 running Sun Ray Server software version 4.2 with no other modifications.

convert_std_pam_to_ldap.sh: Converts a factory out of box Solaris pam.conf file to support LDAP (originally created to be used as part of a jumpstart finish script to automate configuration of LDAP clients)

convert_sunray_srv_pam_to_ldap.sh: Converts a Sun Ray Server pam.conf file to support LDAP (hotdesking was tested as well).
