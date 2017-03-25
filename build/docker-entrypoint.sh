#!/bin/sh

# first we need to grep the gocd serverid from the cruise-xml config
# we dont want that one to be regenerated every single time we do
# a restart of the docker container

# cruise config
cruise_xml=${GO_DATA}/config/cruise-config.xml

[ -z "$GOCD_SERVERID" ] && export GOCD_SERVERID=$(grep -o 'serverId=".*"' ${cruise_xml} | awk '{ gsub("\"",""); gsub("serverId=",""); print $1 }')

# replace configuration variables in the cruise-config.xml
envsubst < "/cruise-config.xml" > "${cruise_xml}"
chown go:go "${cruise_xml}"

# now if the cruise-config.xml file already exists it is ok to have the serverId field defined.
# if the config file doesnt exist the template will create an empty serverId="" field which
# we need to remove completely or the gocd server won't generate a proper serverid
sed -i 's/serverId=""//' ${cruise_xml}

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
  sed -i "/<!-- CONFIGREPOS -->/r ${TMPREPO}" ${cruise_xml}
  rm ${TMPREPO}
fi

# and finally we need to get the credentials and git
# we fetch the credentials from our internal vault (i am using vault now because my setup is running via rancher and not via swarm so no fancy docker secrets)

# authenticate against the vault
ACCESS_TOKEN=$(curl -X POST \
     -d "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"$VAULT_SECRET_ID\"}" \
     ${VAULT_SERVER}/v1/auth/approle/login | jq -r .auth.client_token)

# write the private key file
curl -X GET -H "X-Vault-Token:${ACCESS_TOKEN}" ${VAULT_SERVER}/v1/${VAULT_SECRET_GITHUB_KEY} | jq -r .data.value > ${GO_HOME}/.ssh/id_rsa
unset OUTPUT
chown go:go ${GO_HOME}/.ssh/id_rsa
chmod 0600 ${GO_HOME}/.ssh/id_rsa

# after configuringt the server execute the original entrypoint
exec /docker-entrypoint.sh
