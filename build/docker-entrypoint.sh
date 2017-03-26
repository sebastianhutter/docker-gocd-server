#!/bin/bash

# first we need to grep the gocd serverid from the cruise-xml config
# we dont want that one to be regenerated every single time we do
# a restart of the docker container


# save the currenct serverid if not given as environment variable
[ -z "$GOCD_SERVERID" ] && export GOCD_SERVERID=$(grep -o 'serverId=".*"' ${GOCD_CONFIG}/cruise-config.xml | awk '{ gsub("\"",""); gsub("serverId=",""); print $1 }')

# replace configuration variables in the cruise-config.xml
envsubst < "/cruise-config.xml" > "${GOCD_CONFIG}/cruise-config.xml"
# now if the cruise-config.xml file already exists it is ok to have the serverId field defined.
# if the config file doesnt exist the template will create an empty serverId="" field which
# we need to remove completely or the gocd server won't generate a proper serverid
sed -i 's/serverId=""//' "${GOCD_CONFIG}/cruise-config.xml"
# set correct permissions on the configuration file
chown go:go "${GOCD_CONFIG}/cruise-config.xml"

# next step is to add our repositories which we want to use for the build pipelines
# the idea is to have a build pipeline per repo. the yaml pipeline plugin supports this by
# defining the repos in the cruise-config.xml
# see: https://github.com/tomzo/gocd-yaml-config-plugin#setup
# to achieve an automated config via env variable we accept a list of repos
TMPREPO=$(mktemp)
if [ -n "$GOCD_YAML_REPOSITORIES" ]; then
for r in $GOCD_YAML_REPOSITORIES; do
  # http://stackoverflow.com/questions/22497246/insert-multiple-lines-into-a-file-after-specified-pattern-using-shell-script
  echo -e "<config-repo plugin=\"yaml.config.plugin\">\n  <git url=\"git@github.com:${r}.git\" />\n</config-repo>" >> ${TMPREPO}
done
sed -i "/<!-- CONFIGREPOS -->/r ${TMPREPO}" "${GOCD_CONFIG}/cruise-config.xml"
rm ${TMPREPO}
fi

# now check if ldap is enabled. if so add ldap to the cruise config

if [ "${GOCD_ENABLE_LDAP,,}" == 'true' ]; then
  TMPLDAP=$(mktemp)
  echo "\
  <security allowOnlyKnownUsersToLogin=\"false\">\
    <ldap uri=\"${GOCD_LDAPURI}\" managerDn=\"${GOCD_LDAPMANAGERDN}\" managerPassword=\"${GOCD_LDAPMANAGERPASSWORD}\" searchFilter=\"${GOCD_LDAPSEARCHFILTER}\">\n\
      <bases>\n    <base value=\"${GOCD_LDAPSEARCHBASE}\" />\n</bases>\n\
    </ldap>\n\
    <admins>\n    <user>${GOCD_LDAPADMINUSER}</user>\n</admins>\
  </security>
  " > ${TMPLDAP}
  sed -i "/<!-- CONFIGLDAP -->/r ${TMPLDAP}" "${GOCD_CONFIG}/cruise-config.xml"
  rm ${TMPLDAP}
fi

# and finally we need to get the credentials and git
# we fetch the credentials from our internal vault
# authenticate against the vault
ACCESS_TOKEN=$(curl -X POST \
   -d "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"$VAULT_SECRET_ID\"}" \
   ${VAULT_SERVER}/v1/auth/approle/login | jq -r .auth.client_token)

# write the private key file
curl -X GET -H "X-Vault-Token:${ACCESS_TOKEN}" ${VAULT_SERVER}/v1/${VAULT_SECRET_GITHUB_KEY} | jq -r .data.value > ${GOCD_HOME}/.ssh/id_rsa
unset OUTPUT
chown go:go ${GOCD_HOME}/.ssh/id_rsa
chmod 0600 ${GOCD_HOME}/.ssh/id_rsa

# link the plugins directory
if [ ! -d "${GOCD_DATA}/plugins" ]; then
  mkdir "${GOCD_DATA}/plugins"
fi
if [ -e "${GOCD_DATA}/plugins/external" ]; then
    rm -rf "${GOCD_DATA}/plugins/external"
fi
ln -sf "${GOCD_PLUGINS}" "${GOCD_DATA}/plugins/external"
chown -R go:go "${GOCD_DATA}/plugins"

# now start the server
# we start the server daemonized (see the /etc/defaults/go-server DAEMON flag)
# to keep the container running we tail the go-cd server log files
su - go -c "/usr/share/go-server/server.sh"
# we sleep 3 seconds to surpress the error message about missing logfiles
sleep 3
su - go -c "tail -qF /var/log/go-server/go-server.out.log /var/log/go-server/go-server.log"
