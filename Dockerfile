FROM gocd/gocd-server:v17.3.0

# plugin versions to install
#ARG PLUGIN_GITHUB_OAUTH_LOGIN=2.3
ARG PLUGIN_YAML_CONFIG_PLUGIN=0.4.0

ENV GO_HOME=/home/go
ENV GO_DATA=/godata

# install gettext and jq for our entrypoint
RUN apk add --no-cache curl jq gettext

# install additional plugins we need
RUN mkdir -p ${GO_DATA}/plugins/external \
  && cd ${GO_DATA}/plugins/external \
#  && curl -LO https://github.com/gocd-contrib/gocd-oauth-login/releases/download/v${PLUGIN_GITHUB_OAUTH_LOGIN}/github-oauth-login-${PLUGIN_GITHUB_OAUTH_LOGIN}.jar \
  && curl -LO https://github.com/tomzo/gocd-yaml-config-plugin/releases/download/${PLUGIN_YAML_CONFIG_PLUGIN}/yaml-config-plugin-${PLUGIN_YAML_CONFIG_PLUGIN}.jar \
  && chown -R go:go ${GO_DATA}/plugins

# add cruise config xml and custom entrypoint script
ADD build/cruise-config.xml /cruise-config-custom.xml
ADD build/docker-entrypoint.sh /docker-entrypoint-custom.sh
ADD build/ssh.config ${GO_HOME}/.ssh/config
RUN chmod +x /docker-entrypoint-custom.sh \
  && chown -R go:go ${GO_HOME}/.ssh

ENTRYPOINT ["/docker-entrypoint-custom.sh"]
