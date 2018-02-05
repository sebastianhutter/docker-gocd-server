#!/bin/bash

# create a copy of the current config
[ -f "${GOCD_CONFIG}/cruise-config.xml" ] && \
  cp -f "${GOCD_CONFIG}/cruise-config.xml" "${GOCD_CONFIG}/cruise-config.xml.bak"

