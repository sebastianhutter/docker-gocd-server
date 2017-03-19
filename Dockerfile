FROM gocd/gocd-server

# plugin versions to install
#ARG PLUGIN_GITHUB_OAUTH_LOGIN=2.3
ARG PLUGIN_YAML_CONFIG_PLUGIN=0.4.0

# install gettext and jq for our entrypoint
RUN apt-get update \
  && apt-get install -y gettext jq \
  && rm -rf /var/lib/apt/lists/*

# install additional plugins we need
RUN cd /var/lib/go-server/plugins/external \
#  && curl -LO https://github.com/gocd-contrib/gocd-oauth-login/releases/download/v${PLUGIN_GITHUB_OAUTH_LOGIN}/github-oauth-login-${PLUGIN_GITHUB_OAUTH_LOGIN}.jar \
  && curl -LO https://github.com/tomzo/gocd-yaml-config-plugin/releases/download/${PLUGIN_YAML_CONFIG_PLUGIN}/yaml-config-plugin-${PLUGIN_YAML_CONFIG_PLUGIN}.jar

# add cruise config xml and custom entrypoint script
ADD cruise-config.xml /cruise-config.xml
ADD docker-entrypoint.sh /docker-entrypoint.sh
ADD ssh.config /var/go/.ssh/config
RUN chmod +x /docker-entrypoint.sh \
  && chown -R go:go /var/go/.ssh

ENTRYPOINT ["/docker-entrypoint.sh"]
