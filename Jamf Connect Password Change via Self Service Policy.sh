#!/bin/bash

# Manged Password Change with DEPNotify and Jamf Connect
#
# April 13 2021 - Sean Rabbitt, Kelli Conlin, Catherine McKay

# USE CASE: Your organization has a URL to change passwords.  Could be the
#	password change on Azure, could be an Okta domain, could be a custom page
#	because you have a funky custom OIDC app tied to Shibboleth through
# 	a nightmare of custom code.
#
#	BUT, you want people to change the password on your domain and change the 
#	password with Jamf Connect NOW and in a pretty way.
#
# HOW TO DEPLOY: Modify this script to add your CHANGEPASSWORDURL
#	below.  Then, upload the script to Jamf Pro and create a policy that will:
#	* Install DEPNotify (version 1.1.7 or higher)
#	* Run the script AFTER DEPNotify has installed
#	* Make the policy available in Jamf Pro Self Service and scope to
#		all machines that have Jamf Connect and set Execution Frequency to 
#		Ongoing.  
#	* Capture the Policy URL found at the bottom of the Self Service tab in
#		the Jamf Pro policy payload
#	* Set the ChangePasswordURL key in com.jamf.connect to the Policy URL like:

# 	<key>IdPSettings</key>
#	<dict>
#		<key>ChangePasswordURL</key>
#		<string>jamfselfservice://content?entity=policy&amp;id=42&amp;action=execute</string>
#	</dict>

#	* Change the user timeout below - set to 30 seconds to change the local 
#		password to match the IDP password.

# HOW IT WORKS: When a user selects "Change Password" from the Jamf Connect
#	menu bar app, the Self Service app opens and executes the policy to
# 	change the password.  Users are informed as to what is going to happen via
# 	a full screen DEPNotify window.  The URL is opened in a webkit view.
#	The user then closes the web view and Jamf Connect opens to authenticate the
#	user.  Because the password doesn't match the local password, user will
# 	be prompted to update the local password to match.  If the user doesn't
#	change the local password by hitting cancel or other things they think is 
#	cute, we'll do a network check every passwordTimeout seconds to pop the
#	Jamf Connect login up again.

# MIT License
#
# Copyright (c) 2020 Jamf Software

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


# PASSWORD CHANGE URL:
# Here's some sample URLs for password changes with the most common IdPs
# 
#CHANGEPASSWORDURL="https://sampledomain.okta.com/enduser/settings"
#CHANGEPASSWORDURL="https://sampledomain.okta.com/signin/forgot-password"
#CHANGEPASSWORDURL="https://myaccount.microsoft.com/?tenantId=your_domain_name"
#CHANGEPASSWORDURL="https://domain.onelogin.com/profile2/password"
#
# Pick your URL and define CHANGEPASSWORDURL by uncommenting from above.
CHANGEPASSWORDURL="https://jamfse.okta.com/enduser/settings"

# PASSWORDTIMEOUT: User has this many seconds to change their local password
#	before Jamf Connect will do a Network Check again and force another login
passwordTimeout=30


#requires depnotify 1.1.7 or higher
DEPNOTIFY_PATH="/Applications/Utilities/DEPNotify.app"

# Get current logged in user's shortname
loggedinUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')	
echo "Logged in user is $loggedinUser"

# Path to the preference with our current user's shortname
jamfConnectStateLocation="/Users/$loggedinUser/Library/Preferences/com.jamf.connect.state.plist"
echo "jamfConnectStateLocation"

# Read the preference key from the .plist with PlistBuddy.  If no preference, LastSignIn will be "No record found"
lastSignIn=$(/usr/libexec/PlistBuddy -c "Print :LastSignIn" "$jamfConnectStateLocation" || echo "No record found")

#Set up our while loop in case a user gets cute on us.
currentSignIn=$lastSignIn	

rm /var/tmp/depnotify.log
rm /var/tmp/com.depnotify.webview.done
rm /var/tmp/com.depnotify.provisioning.done

# Open DEPNotify in full screen mode:
sudo -u $loggedinUser open -a "$DEPNOTIFY_PATH" --args -fullScreen

### TEXT IN THIS AREA CAN BE CHANGED TO SUIT YOUR ORG NEEDS:
echo "Command: Determinate: 3"  >> /var/tmp/depnotify.log
echo "Command: Image: /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Sync.icns" >> /var/tmp/depnotify.log
echo "Command: MainTitle: Change Password" >> /var/tmp/depnotify.log
echo "Command: MainText: Our organization's password change website will now load.  After you change your password, you will be prompted by your Mac to sign in and change your local password to match your new organizational password." >> /var/tmp/depnotify.log
echo "Status: " >> /var/tmp/depnotify.log
sleep 3
echo "Command: SetWebViewURL: $CHANGEPASSWORDURL" >> /var/tmp/depnotify.log
echo "Command: ContinueButtonWeb: Start Password Change" >> /var/tmp/depnotify.log

# Hold the script until the webview is closed by the user.
while [ ! -f "/var/tmp/com.depnotify.webview.done" ]; do
	echo "$(date "+%a %h %d %H:%M:%S"): Waiting for user to finish web."
sleep 1
done

### TEXT IN THIS AREA CAN BE CHANGED TO SUIT YOUR ORG NEEDS:
echo "Command: Image: /Applications/Jamf Connect.app/Contents/Resources/AppIcon.icns" >> /var/tmp/depnotify.log
echo "Command: MainTitle: Local Password Update" >> /var/tmp/depnotify.log
echo "Command: MainText: Jamf Connect will now launch.  You will be prompted to update your local password.\n\nIf you have any questions, contact the Security telephone number on the back of your employee badge." >> /var/tmp/depnotify.log
echo "Status: " >> /var/tmp/depnotify.log
echo "Command: ContinueButton: Change Local Password" >> /var/tmp/depnotify.log

# Hold the script until the webview is closed by the user.
while [ ! -f "/var/tmp/com.depnotify.provisioning.done" ]; do
	echo "$(date "+%a %h %d %H:%M:%S"): Waiting for user to close continue button."
	sleep 1
done

# Force a sign in.  This will both check the password AND set the PasswordCurrent
#	flag to make sure the local password is in sync with the IdP.
open jamfconnect://signin
	
# Check to see if the password is currently in sync with the IDP
passwordCurrent=$(/usr/libexec/PlistBuddy -c "Print :PasswordCurrent" "$jamfConnectStateLocation" || echo "No record found")
echo "PasswordCurrent is set to $passwordCurrent"
while [[ "$passwordCurrent" = FALSE  ]]; do
	echo "Sleeping for $passwordTimeout"
	sleep $passwordTimeout
	open jamfconnect://networkcheck
	passwordCurrent=$(/usr/libexec/PlistBuddy -c "Print :PasswordCurrent" "$jamfConnectStateLocation" || echo "No record found")
	echo "the password is not current: $passwordCurrent"
	# if you want to do something to trigger the script again after x number of attempts here
	# go for it
done
	
	
#Clean up after ourselves
rm /var/tmp/com.depnotify.webview.done
rm /var/tmp/com.depnotify.provisioning.done

exit 0;
