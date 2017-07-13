#!/bin/bash

# first we need to grep the gocd serverid from the cruise-xml config
# we dont want that one to be regenerated every single time we do
# a restart of the docker container


#
# configuration file
#

/cruise-config.py

#
# filesystem permissions
#

for f in "${GOCD_DATA}" "${GOCD_CONFIG}" "${GOCD_LOG}"; do
  chown -R go:go "${f}"
done


#
# SSH host config
# we get the ssh config from the host via bind mount
#
unset OUTPUT
chown go:go ${GOCD_HOME}/.ssh/id_rsa
chmod 0600 ${GOCD_HOME}/.ssh/id_rsa

#
# link the plugins directory
#
if [ ! -d "${GOCD_DATA}/plugins" ]; then
  mkdir "${GOCD_DATA}/plugins"
fi
if [ -e "${GOCD_DATA}/plugins/external" ]; then
    rm -rf "${GOCD_DATA}/plugins/external"
fi
ln -sf "${GOCD_PLUGINS}" "${GOCD_DATA}/plugins/external"
chown -R go:go "${GOCD_DATA}/plugins"

#
# init
#

# now start the server
# we start the server daemonized (see the /etc/defaults/go-server DAEMON flag)
# to keep the container running we tail the go-cd server log files
su - go -c "${GOCD_SCRIPT}/server.sh"
# we sleep 3 seconds to surpress the error message about missing logfiles
sleep 3
su - go -c "tail -qF ${GOCD_LOG}/go-server.out.log ${GOCD_LOG}/go-server.log"
