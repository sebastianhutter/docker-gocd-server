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
RUN apk add --no-cache gettext

# plugin installation
ARG GOCD_PLUGIN_YAML_CONFIG=0.6.0
ARG GOCD_PLUGIN_SCRIPT_EXECUTOR=0.3
ARG GOCD_PLUGIN_GITHUB_PR_POLLER=1.3.4
ARG GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER=1.4

# install additional plugins
RUN mkdir -p ${GOCD_ADDONS} ${GOCD_ARTIFACTS} ${GOCD_CONFIG} ${GOCD_DB} ${GOCD_LOGS} ${GOCD_PLUGINS} \
  && cd ${GOCD_PLUGINS} \
  && curl -LO https://github.com/tomzo/gocd-yaml-config-plugin/releases/download/${GOCD_PLUGIN_YAML_CONFIG}/yaml-config-plugin-${GOCD_PLUGIN_YAML_CONFIG}.jar \
  && curl -LO https://github.com/gocd-contrib/script-executor-task/releases/download/${GOCD_PLUGIN_SCRIPT_EXECUTOR}/script-executor-${GOCD_PLUGIN_SCRIPT_EXECUTOR}.0.jar \
  && curl -LO https://github.com/ashwanthkumar/gocd-build-github-pull-requests/releases/download/v${GOCD_PLUGIN_GITHUB_PR_POLLER}/github-pr-poller-${GOCD_PLUGIN_GITHUB_PR_POLLER}.jar \
  && curl -LO https://github.com/gocd-contrib/gocd-build-status-notifier/releases/download/${GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER}/github-pr-status-${GOCD_PLUGIN_GITHUB_BUILD_STATUS_NOTIFIER}.jar \
  && chown -R go:go ${GOCD_BASE}

# add cruise config xml and custom entrypoint script
ADD build/ssh.config ${GOCD_HOME}/.ssh/
ADD build/docker-entrypoint.d/* /docker-entrypoint.d/

# set the correct permissions
RUN chmod +x /docker-entrypoint.d/* \
  && chown -R go:go ${GOCD_HOME}/.ssh

