#!/bin/bash

# now check if ldap is enabled. if so add ldap to the cruise config
if [ "${GOCD_ENABLE_LDAP,,}" == 'true' ]; then
  # read credentials from docker secrets store
  ldapuri=$(cat /run/secrets/ldap-uri)
  ldapdn=$(cat /run/secrets/ldap-dn)
  ldappass=$(cat /run/secrets/ldap-pass)
  ldapfilter=$(cat /run/secrets/ldap-filter)
  ldapbase=$(cat /run/secrets/ldap-base)

  # make sure all variables are set
  if [ -z "${ldapuri}" ]    || \
     [ -z "${ldapdn}" ]     || \
     [ -z "${ldappass}" ]   || \
     [ -z "${ldapfilter}" ] || \
     [ -z "${ldapbase}" ]; then
    echo "invalid ldap configuration. aborting."
    exit 1
  fi

  # write ldap config
  TMPLDAP=$(mktemp)
  echo -e "\
  <security allowOnlyKnownUsersToLogin=\"false\">\
    <ldap uri=\"${GOCD_LDAPURI}\" managerDn=\"${GOCD_LDAPMANAGERDN}\" managerPassword=\"${GOCD_LDAPMANAGERPASSWORD}\" searchFilter=\"${GOCD_LDAPSEARCHFILTER}\">\n\
      <bases>\n    <base value=\"${GOCD_LDAPSEARCHBASE}\" />\n</bases>\n\
    </ldap>\n\
  </security>
  " > ${TMPLDAP}
  sed -i "/<!-- CONFIGLDAP -->/r ${TMPLDAP}" "${GOCD_CONFIG}/cruise-config.xml"
  rm ${TMPLDAP}
fi