<b>pam.conf</b>

Solaris Bourne shell scripts to modify various pam.conf files to support LDAP authentication. Uses standard Solaris versions of sed/awk and does not require GNU tools.

Please note that these scripts were tested with Solaris release 5/09.

</br>

<b>convert_std_pam_to_ldap.sh:</b>

Converts a factory out of box Solaris pam.conf file to support LDAP (originally created to be used as part of a jumpstart finish script to automate configuration of LDAP clients)

</br>

<b>convert_sunray_srv_pam_to_ldap.sh:</b>

Modifies the pam.conf file from a Solaris host running the Sun Ray Server Software to support LDAP (hotdesking was tested as well, the script was tested with Solaris 5/09 running Sun Ray Server software version 4.2 with no other modifications)
