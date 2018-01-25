#!/bin/bash


if [ -f "${GOCD_HOME}/.ssh/id_rsa " ]; then
    echo "INFO: set permissions on '${GOCD_HOME}/.ssh/id_rsa'"
    chown go:go ${GOCD_HOME}/.ssh/id_rsa 
    chmod 0600 ${GOCD_HOME}/.ssh/id_rsa
else
    echo "WARNING: ssh key '${GOCD_HOME}/.ssh/id_rsa' not found" 
fi