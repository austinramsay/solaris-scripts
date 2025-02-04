#!/bin/sh
#
# Austin Ramsay
# austinramsay@gmail.com
# 2/3/2025
# 
# NOTE: This script will create a backup of your original pam.conf as
# pam.conf.(month)(day)(year)-(hour)(minute)(second).bak
# 
# This script converts a Solaris 10 Sun Ray server (tested on Solaris release 
# 5/09 using Sun Ray Server Software release 4.2) pam.conf file to support
# LDAP authentication. THIS IS BASED OFF OF A PAM.CONF THAT HAS NO OTHER 
# MODIFICATIONS other than a fresh Solaris 10 and SRSS 4.2 install.
# This script also supports hotdesking with LDAP authentication.
#
# TEMP_PAM_CONF_PATH defines a temporary output file for `sed` to write an
# updated pam.conf to, and then moves it to the final pam.conf path defined
# in PAM_CONF_PATH. This is necessary since factory Solaris sed does not offer
# performing substitutions directly in a file. It will only write to stdout.
#

TEMP_PAM_CONF_PATH="pam.temp" 	# Recommend /etc/pam.temp
PAM_CONF_PATH="pam.conf"	# Recommend /etc/pam.conf
BACKUP_PATH="."			# Recommend /etc

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

# Function insertLdapEntry()
# Arguments:
# $1 = list of service names (login, rlogin, passwd, other, etc.)
# $2 = module type (auth, account, session, password)
insertLdapEntry() {
for SERVICE_NAME in ${1}; do

        # Construct the line to be added
        LDAP_ENTRY=`printf "%s\t%s %s\t\t%s" "$SERVICE_NAME" "$2" "required" "pam_ldap.so.1"`;

	# Get a list of all line numbers that match this service name and 
	# module type
        ALL_MATCHING_LINES=`/usr/xpg4/bin/awk -v SERVICE_NAME="$SERVICE_NAME" -v MODULE_TYPE="$2" '{if ( (NF<=4) && ($1==SERVICE_NAME) && ($2==MODULE_TYPE) ) print NR}' $PAM_CONF_PATH | awk '{printf("%s ", $0)}'`;

	# Iterate through lines until finding last line number
        for LINE in ${ALL_MATCHING_LINES}; do
                FINAL_LINE=${LINE};
        done;

        # We need to insert after the final line in the stack
        INSERT_AT_LINE=`expr $FINAL_LINE + 1`;

	# Insert the LDAP entry at end of stack
        sed $INSERT_AT_LINE"i\\
        ${LDAP_ENTRY}" $PAM_CONF_PATH > $TEMP_PAM_CONF_PATH;

        mv $TEMP_PAM_CONF_PATH $PAM_CONF_PATH;
done
}

# Function getLineNumsReqToSuf()
# Locate line numbers that need to be modiifed from required to sufficient
# Arguments:
# $1 = list of service names (login, rlogin, dtlogin-SunRay, etc.)
# $2 = list of module types (auth, account, session, password)
# $3 = module path (pam_unix_auth.so.1, pam_unix_account.so.1)
getLineNumsReqToSuf() {

# Reset the variable since we're re-using it
REQD_TO_SUF_LINENUMS=

for SERVICE_NAME in ${1}; do
	for MODULE_TYPE in ${2}; do
		FOUND_LINENUMS=`awk "/^${SERVICE_NAME}/ && /${MODULE_TYPE}/ && /required/ && /${3}/ {print NR}" $PAM_CONF_PATH | awk '{printf("%s ", $0)}' -`;
		REQD_TO_SUF_LINENUMS="${REQD_TO_SUF_LINENUMS} ${FOUND_LINENUMS}"
	done
done
}

# Function replaceControlFlag()
# Given a list of line numbers, replace the control flag keywords with
# the provided argument new keyword.
# $1 = list of line numbers where keyword needs to be substituted
# $2 = original control flag (ex. required)
# $3 = new control flag (ex. sufficient)
replaceControlFlag() {
for LINENUM in ${1}; do
	`sed "${LINENUM}s/${2}/${3}/" $PAM_CONF_PATH > $TEMP_PAM_CONF_PATH`;

	mv $TEMP_PAM_CONF_PATH $PAM_CONF_PATH;
done
}


# For services with "auth" and "pam_unix_auth.so.1"
SERVICE_NAMES="login rlogin ppp other dtlogin-SunRay dtsession-SunRay utnsclogin"

# Get the entry line numbers
getLineNumsReqToSuf "$SERVICE_NAMES" "auth" "pam_unix_auth.so.1" 

# Swap the control flag at these line numbers
replaceControlFlag "$REQD_TO_SUF_LINENUMS" "required" "sufficient"

# And then insert new LDAP entries
insertLdapEntry "$SERVICE_NAMES" "auth"


# For services with "account" and "pam_unix_account.so.1"
SERVICE_NAMES="dtlogin-SunRay dtsession-SunRay utnsclogin"

# Get the entry line numbers
getLineNumsReqToSuf "$SERVICE_NAMES" "account" "pam_unix_account.so.1"

# Swap the control flag at these line numbers
replaceControlFlag "$REQD_TO_SUF_LINENUMS" "required" "sufficient"

# And then insert new LDAP entries
insertLdapEntry "$SERVICE_NAMES" "account"


# We need to add an entry for other/password not included in the above
insertLdapEntry "other" "password"


# Remove leading whitespace at beginning of lines, not sure why this happens?
sed 's/^ *//' $PAM_CONF_PATH > $TEMP_PAM_CONF_PATH
mv $TEMP_PAM_CONF_PATH $PAM_CONF_PATH

echo "Modification of pam.conf complete."

###########
# End PAM confguration
###########
