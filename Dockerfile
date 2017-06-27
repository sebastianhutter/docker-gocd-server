FROM debian:jessie
MAINTAINER <mail@sebastian-hutter.ch>


# build arguments
ARG GOCD_SERVER_VERSION=17.6.0
# plugin versions to install
ARG GOCD_PLUGIN_YAML_CONFIG=0.4.0
ARG GOCD_PLUGIN_SCRIPT_EXECUTOR=0.3
ARG GOCD_PLUGIN_GITHUB_PR_POLLER=1.3.3
# environment variables used for building and entrypoint
ENV GOCD_DATA=/var/lib/go-server
ENV GOCD_PLUGINS=/goplugins
ENV GOCD_CONFIG=/etc/go
ENV GOCD_HOME=/var/go
ENV GOCD_LOG=/var/log/go-server
ENV GOCD_SCRIPT=/usr/share/go-server
ENV DEFAULTS=/etc/default/go-server

# install requirements for the gocd server
RUN echo "deb http://ftp.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/backports.list \
 && apt-get update \
 && apt-get install -y curl jq gettext apt-transport-https git \
 && apt-get install -y -t jessie-backports ca-certificates-java openjdk-8-jre-headless \
 && rm -rf /var/lib/apt/lists/*

# create go user with fixed uid/gid
RUN groupadd --gid 1999 go && \
    useradd --create-home --home-dir /var/go --uid 1999 --gid 1999 --system go

# install the gocd server
# the apt-cache command tries to get the correct debian package version form the
# specfiied gocd_server_version variable
RUN echo "deb https://download.gocd.io /" > /etc/apt/sources.list.d/gocd.list \
  && curl https://download.gocd.io/GOCD-GPG-KEY.asc | apt-key add - \
  && apt-get update \
  && apt-get install -y go-server=$(apt-cache show go-server | grep "Version: ${GOCD_SERVER_VERSION}.*" | head -n 1 | awk '{print $2}') \
  && rm -rf /var/lib/apt/lists/*

# install additional plugins we need
RUN mkdir ${GOCD_PLUGINS} \
  && cd ${GOCD_PLUGINS}\
  && curl -LO https://github.com/tomzo/gocd-yaml-config-plugin/releases/download/${GOCD_PLUGIN_YAML_CONFIG}/yaml-config-plugin-${GOCD_PLUGIN_YAML_CONFIG}.jar \
  && curl -LO https://github.com/gocd-contrib/script-executor-task/releases/download/${GOCD_PLUGIN_SCRIPT_EXECUTOR}/script-executor-${GOCD_PLUGIN_SCRIPT_EXECUTOR}.0.jar \
  && curl -LO https://github.com/ashwanthkumar/gocd-build-github-pull-requests/releases/download/v${GOCD_PLUGIN_GITHUB_PR_POLLER}/github-pr-poller-${GOCD_PLUGIN_GITHUB_PR_POLLER}.jar \
  && chown -R go:go ${GOCD_PLUGINS}

# add cruise config xml and custom entrypoint script
ADD build/cruise-config.xml /cruise-config.xml
ADD build/docker-entrypoint.sh /docker-entrypoint.sh
ADD build/ssh.config ${GOCD_HOME}/.ssh/config
# set the correct permissions
RUN chmod +x /docker-entrypoint.sh \
  && chown -R go:go ${GOCD_HOME}/.ssh

EXPOSE 8153
EXPOSE 8154

ENTRYPOINT ["/docker-entrypoint.sh"]
