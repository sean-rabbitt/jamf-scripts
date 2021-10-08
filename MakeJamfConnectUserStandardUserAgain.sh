#!/bin/bash

# A script to remove the attributes that Jamf Connect uses to determine if a
# local user account has already been migrated to match up with an identity
# provider.  
#
# If you run this as a policy from Jamf Pro, be sure to change the $1 to
# something like $4 and pass the local user account name to the script.
#
# This script can be useful if someone accidentally migrated the wrong
# user account or in a situation like a name change in your identity provider
# and you want to match it up with a local user again i.e. Roger Elizabeth
# De Bris gets married and changes their last name to Ghia.

localUser="$1"

dscl . delete /Users/"$localUser" dsAttrTypeStandard:NetworkUser
dscl . delete /Users/"$localUser" dsAttrTypeStandard:OIDCProvider
dscl . delete /Users/"$localUser" dsAttrTypeStandard:AzureUser
