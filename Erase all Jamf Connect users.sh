#!/bin/bash

# Nuke all Jamf Connect users
# Clean up any users on a shared device that you want to erase at the end of a term
# This will NOT delete a user if they are an admin with a securetoken 
# macOS doesn't let you delete the last admin user with a securetoken, so this prevents issues.

# The command to actually delete the user is commented out below to prevent accidents.


# MIT License
#
# Copyright (c) 2021 Jamf Software

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#Define location of the Jamf binary
$JAMF_BINARY=$(which jamf)

# For all users who have a password on this machine (eliminates service accounts
# but includes the _mbsetupuser and Jamf management accounts...)
for user in $(/usr/bin/dscl . list /Users Password | /usr/bin/awk '$2 != "*" {print $1}'); do
	# If a user has the attribute "NetworkUser" in their user record, they are a Jamf Connect user.
	MIGRATESTATUS=($(/usr/bin/dscl . -read /Users/$user | grep "NetworkUser: " | /usr/bin/awk {'print $2'}))
	# If we didn't get a result, the variable is empty.  Thus that user is not 
	# a Jamf Connect Login user.
	if [[ -z $MIGRATESTATUS ]]; 
	then
		# user is not a jamf connect user
		echo "$user is Not a Jamf Connect User"
	else
		isUserAdmin=$(/usr/sbin/dseditgroup -m "$user" -o checkmember admin | /usr/bin/awk {'print $1'})
		if [ "$isUserAdmin" = "yes" ]; then
			# Check for securetoken status
			secureTokenStatus=$(/usr/bin/dscl . -read /Users/"$user" AuthenticationAuthority | /usr/bin/grep -o "SecureToken")
			# If the account has a SecureToken, increase the securetoken counter
		fi
		if [ "$secureTokenStatus" = "SecureToken" ]; then
			# We said we weren't going to delete any admin usersusers that have a securetoken.
			echo "User will not be deleted - Admin has securetoken: $user"
		else
		echo "Deleting $user"
		############################################################################
		############################################################################
		### HERE'S WHERE YOU UNCOMMENT STUFF FOR DATA LOSS TO PURPOSELY HAPPEN!! ###
		############################################################################
		############################################################################
		# It's not that I don't trust you.  I don't trust anyone.
		echo "$JAMF_BINARY deleteAccount -username $user -deleteHomeDirectory"
		#$JAMF_BINARY deleteAccount -username "$user" -deleteHomeDirectory
		
		# If we're doing this with soemthing else like another MDM, you'd do something like...
		#/usr/bin/dscl . -delete /Users/{$user}
		#rm -rf /Users{$user}
		# But you do you, my friend.  Do whatever you want to nuke that data.
		fi
	# Reset secureTokenStatus for next loop.
	secureTokenStatus = ""
		
	fi
done

