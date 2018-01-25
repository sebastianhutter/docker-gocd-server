FROM gocd/gocd-server:v18.1.0

# env vars for easier file access in scripts
ENV GOCD_BASE=/godata
ENV GOCD_ADDONS=${GOCD_BASE}/addons
ENV GOCD_ARTIFACTS=${GOCD_BASE}/artifacts
ENV GOCD_CONFIG=${GOCD_BASE}/config
ENV GOCD_DB=${GOCD_BASE}/db 
ENV GOCD_LOGS=${GOCD_BASE}/logs
ENV GOCD_PLUGINS=${GOCD_BASE}/plugins/external
ENV GOCD_HOME=/home/go

# expose gocd standard ports
EXPOSE 8153
EXPOSE 8154

# install python3 and dependencies for cruise-config.py
RUN apk add --no-cache python3 py3-lxml 

# add cruise config xml and custom entrypoint script
ADD build/cruise-config.xml.template /
ADD build/cruise-config.py /docker-entrypoint.d/
ADD build/set-ssh-permissions.sh  /docker-entrypoint.d/
ADD build/ssh.config ${GOCD_HOME}/.ssh/

# set the correct permissions
RUN chmod +x /docker-entrypoint.d/* \
  && chown -R go:go ${GOCD_HOME}/.ssh

# plugin installation
ARG GOCD_PLUGIN_YAML_CONFIG=0.6.0
ARG GOCD_PLUGIN_SCRIPT_EXECUTOR=0.3
ARG GOCD_PLUGIN_GITHUB_PR_POLLER=1.3.4
ARG GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER=1.4
ARG GOCD_PLUGIN_SLACK_BUILD_NOTIFIER=v1.4.0-RC11

# install additional plugins
RUN mkdir -p ${GOCD_ADDONS} ${GOCD_ARTIFACTS} ${GOCD_CONFIG} ${GOCD_DB} ${GOCD_LOGS} ${GOCD_PLUGINS} \
  && cd ${GOCD_PLUGINS} \
  && curl -LO https://github.com/tomzo/gocd-yaml-config-plugin/releases/download/${GOCD_PLUGIN_YAML_CONFIG}/yaml-config-plugin-${GOCD_PLUGIN_YAML_CONFIG}.jar \
  && curl -LO https://github.com/gocd-contrib/script-executor-task/releases/download/${GOCD_PLUGIN_SCRIPT_EXECUTOR}/script-executor-${GOCD_PLUGIN_SCRIPT_EXECUTOR}.0.jar \
  && curl -LO https://github.com/ashwanthkumar/gocd-build-github-pull-requests/releases/download/v${GOCD_PLUGIN_GITHUB_PR_POLLER}/github-pr-poller-${GOCD_PLUGIN_GITHUB_PR_POLLER}.jar \
  && curl -LO https://github.com/gocd-contrib/gocd-build-status-notifier/releases/download/${GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER}/github-pr-status-${GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER}.jar \
  && curl -LO https://github.com/ashwanthkumar/gocd-slack-build-notifier/releases/download/${GOCD_PLUGIN_SLACK_BUILD_NOTIFIER}/gocd-slack-notifier-${GOCD_PLUGIN_SLACK_BUILD_NOTIFIER}.jar \
  && chown -R go:go ${GOCD_BASE}


# FROM alpine:3.6
# MAINTAINER <mail@sebastian-hutter.ch>


# # build arguments
# ARG GOCD_SERVER_VERSION=17.10.0
# ARG GOCD_SERVER_BUILD=5380
# # plugin versions to install
# ARG GOCD_PLUGIN_YAML_CONFIG=0.6.0
# ARG GOCD_PLUGIN_SCRIPT_EXECUTOR=0.3
# ARG GOCD_PLUGIN_GITHUB_PR_POLLER=1.3.4
# ARG GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER=1.3
# # environment variables used for building and entrypoint
# ENV GOCD_DATA=/var/lib/go-server
# ENV GOCD_PLUGINS=/goplugins

# ENV GOCD_HOME=/var/go
# ENV GOCD_LOG=/var/log/go-server
# ENV GOCD_SCRIPT=/usr/share/go-server
# ENV DEFAULTS=/etc/default/go-server

# # install requirements for the gocd server
# # split installation into multiple commands so we dont have to update big layers
# RUN apk add --no-cache python3 py3-lxml 
# RUN apk add --no-cache openjdk8
# RUN apk add --no-cache curl git ca-certificates zip tini bash openssh-client

# # add go user and group
# RUN addgroup -g 1999 -S go \
#   && adduser -h ${GOCD_HOME} -s /bin/bash -u 1999 -G go -S go

# # prepare go environment
# RUN mkdir -p ${GOCD_DATA} \
#   && mkdir -p ${GOCD_PLUGINS} \
#   && mkdir -p ${GOCD_CONFIG} \
#   && mkdir -p ${GOCD_LOG} \
#   && mkdir -p ${GOCD_SCRIPT} \
#   && mkdir -p $(dirname ${DEFAULTS})

# # download gocd zip
# # extract the zip 
# # move files to correct directories (stay compatible to debian based setup)
# RUN mkdir /tmp/setup \
#   && curl https://download.gocd.org/binaries/${GOCD_SERVER_VERSION}-${GOCD_SERVER_BUILD}/generic/go-server-${GOCD_SERVER_VERSION}-${GOCD_SERVER_BUILD}.zip \
#        -o /tmp/setup/gocd.zip \
#   && unzip /tmp/setup/gocd.zip -d /tmp/setup \
#   && mv /tmp/setup/go-server-${GOCD_SERVER_VERSION}/go.jar ${GOCD_SCRIPT} \
#   && mv /tmp/setup/go-server-${GOCD_SERVER_VERSION}/server.sh ${GOCD_SCRIPT} \
#   && mv /tmp/setup/go-server-${GOCD_SERVER_VERSION}/stop-server.sh ${GOCD_SCRIPT} \
#   && mv /tmp/setup/go-server-${GOCD_SERVER_VERSION}/go-server.default ${DEFAULTS} \
#   && mv /tmp/setup/go-server-${GOCD_SERVER_VERSION}/config/log4j.properties ${GOCD_CONFIG} \
#   && rm -rf /tmp/setup

# # install additional plugins we need
# RUN cd ${GOCD_PLUGINS}\
#   && curl -LO https://github.com/tomzo/gocd-yaml-config-plugin/releases/download/${GOCD_PLUGIN_YAML_CONFIG}/yaml-config-plugin-${GOCD_PLUGIN_YAML_CONFIG}.jar \
#   && curl -LO https://github.com/gocd-contrib/script-executor-task/releases/download/${GOCD_PLUGIN_SCRIPT_EXECUTOR}/script-executor-${GOCD_PLUGIN_SCRIPT_EXECUTOR}.0.jar \
#   && curl -LO https://github.com/ashwanthkumar/gocd-build-github-pull-requests/releases/download/v${GOCD_PLUGIN_GITHUB_PR_POLLER}/github-pr-poller-${GOCD_PLUGIN_GITHUB_PR_POLLER}.jar \
#   && curl -LO https://github.com/gocd-contrib/gocd-build-status-notifier/releases/download/${GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER}/github-pr-status-${GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER}.jar \
#   && chown -R go:go ${GOCD_PLUGINS}

# # add cruise config xml and custom entrypoint script
# #ADD build/cruise-config.xml /cruise-config.xml
# ADD build/cruise-config.xml.template /cruise-config.xml.template
# ADD build/cruise-config.py /cruise-config.py
# ADD build/docker-entrypoint.sh /docker-entrypoint.sh
# ADD build/ssh.config ${GOCD_HOME}/.ssh/config
# # set the correct permissions
# RUN chmod +x /docker-entrypoint.sh /cruise-config.py \
#   && chown -R go:go ${GOCD_HOME}/.ssh

# EXPOSE 8153
# EXPOSE 8154

# ENTRYPOINT ["/sbin/tini", "--"]
# CMD ["/docker-entrypoint.sh"]
