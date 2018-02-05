#!/bin/bash

# save the currenct serverid if not given as environment variable
if [ -z "$GOCD_SERVERID" ]; then
    export serverid=$(grep -o 'serverId=".*"' ${GOCD_CONFIG}/cruise-config.xml | awk '{ gsub("\"",""); gsub("serverId=",""); print $1 }')
else
    export serverid=${GOCD_SERVERID}
fi

# retrieve other information from docker secrets store
export siteurl=$(cat /run/secrets/siteurl)
export securesiteurl=$(cat /run/secrets/securesiteurl)
export autoregister=$(cat /run/secrets/autoregister)

envsubst < "/run/secrets/cruise-config.xml" > "${GOCD_CONFIG}/cruise-config.xml"

unset serverid
unset siteurl
unset securesiteurl
unset autoregister