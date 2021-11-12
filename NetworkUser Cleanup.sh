#!/bin/bash

# Clean up all NetworkUser: Unknown issues.

# REQUIRED VARIABLES
# Put the name of the management account created for Jamf in a prestage enrollment here
jamfManagementAccount=jamfManagement

# Get a list of all users on the machine who have a password.  For each user check to see if 
# the user is named after the Jamf Management Account or the _mbsetupuser

####NOTE: That second thing may not be required; my setup of Parallels might have given the
# 	_mbsetupuser a password when it really didn't need one...
####NOTE: You may want to modify this to add any additional programatically created
#	local admin accounts you create in your environment.

for user in $(dscl . list /Users Password | awk '$2 != "*" {print $1}');do
	if [[ ("$user" != "$jamfManagementAccount") && ("$user" != "_mbsetupuser") ]]; then
		# Look in the dscl record for the user and see if there is an entry for NetworkUser
		# Jamf Connect will add that to the user record when it is migrated or created
		MIGRATESTATUS=($(dscl . -read /Users/$user | grep "NetworkUser: " | awk {'print $2'}))
		# If the result is "Unknown" then there was an issue with the migration in the past.  Clean it up.
		if [ $MIGRATESTATUS == "Unknown" ]; then
			dscl . delete /Users/"$user" dsAttrTypeStandard:NetworkUser
		fi
	fi
done