#!/bin/sh
#
# Austin Ramsay
# austinramsay@gmail.com
# 2/3/2025
# 
# This script converts a factory Solaris 10 (tested on release 5/09) pam.conf
# file to support LDAP authentication.
#
# It is originally intended to be used during a jumpstart configuration script
# to automate client LDAP configuration during install, so you will need to
# modify the pam paths accordingly if you're using this on an already installed
# OS. Jumpstart installs use the prefix /a for the hard drive installation,
# so you can remove this prefix if you're using this on an already running
# system. This applies to the /usr/xpg4/bin/awk path as well.
#
# TEMP_PAM_CONF_PATH defines a temporary output file for `sed` to write an
# updated pam.conf to, and then moves it to the final pam.conf path defined
# in PAM_CONF_PATH. This is necessary since factory Solaris sed does not offer
# performing substitutions directly in a file. It will only write to stdout.
#

TEMP_PAM_CONF_PATH="/a/etc/pam.temp"	# Recommend /etc/pam.temp
PAM_CONF_PATH="/a/etc/pam.conf"		# Recommend /etc/pam.conf
BACKUP_PATH="/a/etc"			# Recommend /etc

# xpg4 awk path - required to pass through variables
XPG4_AWK_PATH="/a/usr/xpg4/bin/awk"

if [ -z "$TEMP_PAM_CONF_PATH" -o -z "$PAM_CONF_PATH" ]; then
        echo "Please define path names TEMP_PAM_CONF_PATH and PAM_CONF_PATH."
        exit
fi

BACKUP_DATE=`date +%m%d%G-%H%M%S`
BACKUP_FILENAME="${BACKUP_PATH}/pam.conf.${BACKUP_DATE}.bak"
cp $PAM_CONF_PATH $BACKUP_FILENAME

# Verify that the backup was created before proceeding
if [ -f "$BACKUP_FILENAME" ]; then
        echo "Created backup: $BACKUP_FILENAME"
else
        echo "Error: Could not create backup, exiting.."
        echo "Ensure BACKUP_PATH points to a directory with write permissions."
        exit
fi

###########
# Begin modifying pam.conf for LDAP entries
###########

echo "Modifying pam.conf to support LDAP."

# Locate line numbers that need to be modiifed from required to sufficient
REQD_TO_SUF_LINENUMS=
SERVICE_NAMES="login rlogin ppp other"
MODULE_TYPE="auth"

for SERVICE_NAME in ${SERVICE_NAMES}; do
        FOUND_LINENUMS=`awk "/^${SERVICE_NAME}/ && /${MODULE_TYPE}/ && /required/ && /pam_unix_auth.so.1/ {print NR}" $PAM_CONF_PATH | awk '{printf("%s ", $0)}' -`;
        REQD_TO_SUF_LINENUMS="${REQD_TO_SUF_LINENUMS} ${FOUND_LINENUMS}"
done

# Now that we've located the line numbers where the 'required' keyword should be substituted for 'sufficient', let's swap the keyword.

for LINENUM in ${REQD_TO_SUF_LINENUMS}; do
        `sed "${LINENUM}s/required/sufficient/" $PAM_CONF_PATH > $TEMP_PAM_CONF_PATH`;
        mv $TEMP_PAM_CONF_PATH $PAM_CONF_PATH;
done

# We need to find the last line number of each service name in the pam.conf so that we can add the LDAP entry underneath it

# Function insertLdapEntry()
# Arguments:
# $1 = list of service names (login, rlogin, passwd, other, etc.)
# $2 = module type (auth, account, session, password)
insertLdapEntry() {
for SERVICE_NAME in ${1}; do

        # Construct the line to be added
        LDAP_ENTRY=`printf "%s\t%s %s\t\t%s" "$SERVICE_NAME" "$2" "required" "pam_ldap.so.1"`;

        ALL_MATCHING_LINES=`$XPG4_AWK_PATH -v SERVICE_NAME="$SERVICE_NAME" -v MODULE_TYPE="$2" '{if ( (NF<=4) && ($1==SERVICE_NAME) && ($2==MODULE_TYPE) ) print NR}' $PAM_CONF_PATH | awk '{printf("%s ", $0)}'`;

        for LINE in ${ALL_MATCHING_LINES}; do
                FINAL_LINE=${LINE};
        done;

        # We need to insert after the final line
        INSERT_AT_LINE=`expr $FINAL_LINE + 1`;

        sed $INSERT_AT_LINE"i\\
        ${LDAP_ENTRY}" $PAM_CONF_PATH > $TEMP_PAM_CONF_PATH;

        mv $TEMP_PAM_CONF_PATH $PAM_CONF_PATH;
done
}

insertLdapEntry "$SERVICE_NAMES" "$MODULE_TYPE"

# We need to add an entry for other/password not included in the above
insertLdapEntry "other" "password"

# Remove leading whitespace at beginning of lines, not sure why this happens?
sed 's/^ *//' $PAM_CONF_PATH > $TEMP_PAM_CONF_PATH
mv $TEMP_PAM_CONF_PATH $PAM_CONF_PATH

echo "Modification of pam.conf complete."

###########
# End PAM confguration
###########
