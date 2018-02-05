#!/bin/bash

if [ -n "$GOCD_YAML_REPOSITORIES_URL" ]; then
  TMPREPO=$(mktemp)
  echo "retrieving repository list from url ${GOCD_YAML_REPOSITORIES_URL}"
  REPO_FILE="${GOCD_HOME}/gocd.repositories"
  curl "$GOCD_YAML_REPOSITORIES_URL" -o "${REPO_FILE}"

  # now loop trough the file and add a line to tmprepo for each entry
  while read r; do
    # http://stackoverflow.com/questions/22497246/insert-multiple-lines-into-a-file-after-specified-pattern-using-shell-script
    echo -e "<config-repo plugin=\"yaml.config.plugin\">\n  <git url=\"git@github.com:${r}.git\" />\n</config-repo>" >> ${TMPREPO}
  done <"${REPO_FILE}"
  sed -i "/<!-- CONFIGREPOS -->/r ${TMPREPO}" "${GOCD_CONFIG}/cruise-config.xml"
  echo "added the following tmprepo list"
  cat  ${TMPREPO}
  rm ${TMPREPO}
fi