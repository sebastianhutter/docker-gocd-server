#!/usr/bin/env python3

"""
  python script to parse the cruise-config.xml file
"""

from lxml import etree
import os
import shutil
from io import StringIO, BytesIO
import logging
import traceback
from distutils.util import strtobool

# configure logger
# http://docs.python-guide.org/en/latest/writing/logging/
logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s %(name)-12s %(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
loglevel = os.getenv("LOGLEVEL", "info")
if loglevel.lower() == "debug":
  logger.setLevel(logging.DEBUG)
else:
  logger.setLevel(logging.INFO)

# copied from https://github.com/ProjectThor/search-faktli/blob/60e9214f51dbd5e95bcbd84695fb92fef91d4b91/app/config.py#L31
def _as_bool(obj):
    """
    :param obj:
    :return:
    """
    return bool(strtobool(str(obj)))

class CruiseConfig:
  """
    cruise-config xml representation and config values
  """

  def __init__(self):
    """
      initialize configuration values
    """

    self.xmlfile = os.getenv("GOCD_CONFIG") + "/cruise-config.xml"
    self.templatefile = "/cruise-config.xml.template"
    
    # ownerhsip for config file
    self.owner = "go"
    self.group = "go"

    # create a list of environments (defined via env)
    self.environments = os.getenv("GOCD_YAML_ENVIRONMENTS")
    if self.environments:
      self.environments = self.environments.split(" ")
    else:
      self.environments = []
    self.source_repositories = os.getenv("GOCD_YAML_REPOSITORIES")
    if self.source_repositories:
      self.source_repositories = self.source_repositories.split(" ")
    else:
      self.source_repositories = []

    # get other configuration values
    self.siteurl = os.getenv("GOCD_SITEURL",False)
    self.securesiteurl = os.getenv("GOCD_SECURESITEURL",False)
    self.agentautoregisterkey = os.getenv("GOCD_AGENTAUTOREGISTERKEY",False)
    self.serverid = os.getenv("GOCD_SERVERID",False)
    # defaults. currently not changed by us
    self.webhooksecret = os.getenv("GOCD_WEBHOOK_SECRET",False)
    self.artifactsdir = os.getenv("GOCD_ARTIFACTSDIR","artifacts")
    self.commandrepositorylocation = os.getenv("GOCD_COMMANDREPOSITORYLOCATION","default")
    self.schemaversion = os.getenv("GOCD_SCHEMAVERSION","95")
    # ldap configuration
    self.ldapenabled = _as_bool(os.getenv('GOCD_LDAP_ENABLE', False))
    self.ldapid = os.getenv("GOCD_LDAP_ID", "ldap")
    self.ldapconfiguration = {
      'Url': os.getenv("GOCD_LDAP_URL", "ldaps://ldap-read.siroop.work:636"),
      'ManagerDN': os.getenv("GOCD_LDAP_BINDDN", "uid=sys.gocd,ou=System Accounts,ou=Accounts,dc=siroop,dc=work"),
      'Password': os.getenv("GOCD_LDAP_BINDPASS", None),
      'SearchBases': os.getenv("GOCD_LDAP_SEARCHBASES", "dc=siroop,dc=work").split(";"),
      'UserLoginFilter': os.getenv("GOCD_LDAP_USERLOGINFILTER", "(|(uid={0})(mail={0}))"),
      'UserSearchFilter': os.getenv("GOCD_LDAP_USERFILTERSEARCHFILTER", "(|(uid=*{0}*)(mail={0}*)(otherMailbox=*{0}*))")
    }
    # load the xml configuration
    if os.path.isfile(self.xmlfile):
      logger.info("Load xml configuration {}".format(self.xmlfile))
      self.cruise = etree.parse(self.xmlfile)
    else:
      logger.info("No configuration file found. Load template {}".format(self.templatefile))
      self.cruise = etree.parse(self.templatefile)

    # get the root of the xml document
    self.cruise_root = self.cruise.getroot()

  def updateServerAttribute(self,attribute,value):
    """
      update server element attributes
    """
    server = self.getServerConfiguration()

    if server is None:
      raise BaseException("No server configuration found. Config is invalid")

    # if given value is not empty
    if value:
      server.attrib.update({attribute:value})

    # check if attribute is empty. if empty remove it
    if server.attrib.has_key(attribute):
      if not server.attrib.get(attribute):
        server.attrib.pop(attribute)

  def setSchemaVersion(self):
    """
      set the schemaversion attribute
    """
    if not self.cruise_root.attrib.get("schemaVersion"):
      self.cruise_root.attrib.update({"schemaVersion":self.schemaversion})

  def getServerConfiguration(self):
    """ 
      returns the server configuration.
      raises exception if doesnt find it
    """
    server = self.cruise_root.find("server")
    if server is None:
      raise BaseException("No server configuration found. Config is invalid")
    return server

  def setServerConfiguration(self):
    """
      set server configuration (serverid etc.)
    """
    self.updateServerAttribute("artifactsdir",self.artifactsdir)
    self.updateServerAttribute("siteUrl",self.siteurl)
    self.updateServerAttribute("secureSiteUrl",self.securesiteurl)
    self.updateServerAttribute("agentAutoRegisterKey",self.agentautoregisterkey)
    self.updateServerAttribute("webhookSecret",self.webhooksecret)
    self.updateServerAttribute("commandRepositoryLocation",self.commandrepositorylocation)
    self.updateServerAttribute("serverId",self.serverid)

  def removeSecurityConfiguration(self):
    """
      remove security configuration
    """
    server = self.getServerConfiguration()
    security = server.find("security")
    if security is not None:
      logger.debug("Remove security config")
      server.remove(security)

  def setSecurityConfiguration(self):
    """
      add security configuration
    """
    # get the server config
    server = self.getServerConfiguration()
    # create an empty list for the security entries
    logger.debug("Creating parent element for security")
    security = etree.Element("security")

    # fill up the security element
    if self.ldapenabled:
      logger.debug("Setup ldap authentication")
      # create the authconfigs element with a custom id
      # and the ldap authentication plugin
      logger.debug("LDAP is enabled. Create authconfig elements")
      authconfigs = etree.Element("authConfigs")
      authconfig = etree.Element("authConfig",pluginId="cd.go.authentication.ldap",id=self.ldapid)
      # now add the necesseary properties for the ldap authentication
      for k, v in self.ldapconfiguration.items():
        logger.debug("Add property for key {} with value {}".format(k,v))
        prop = etree.Element("property")
        key = etree.Element("key")
        value = etree.Element("value")
        key.text = k
        # if the value is a list we need to add values separated by newline
        if isinstance(v, list):
          value.text = "\n".join(v)
        else:
          value.text = v
        # now add the property to the authconfig
        prop.append(key)
        prop.append(value)
        authconfig.append(prop)

      # add the security element to the server config
      logger.debug("Append authconfig ldap element to authconfigs element")
      authconfigs.append(authconfig)
      logger.debug("Append authconfigs element to security element")
      security.append(authconfigs)
      logger.debug("Append security element to server element")
      security.append(authconfigs)
      server.append(security)

  def removePipelines(self):
    """
      remove pipeline configurations
      pipelines will be loaded via git repositories
    """
    for pipeline in self.cruise_root.findall("pipelines"):
      logger.debug("Remove pipeline {}".format(pipeline))
      self.cruise_root.remove(pipeline)

  def removeConfigRepos(self):
    """
      remove all configuration repositories
    """
    configrepos = self.cruise_root.find("config-repos")
    if configrepos is not None:
      for repo in configrepos.findall("config-repo"):
        logger.debug("Remove config-repo {}".format(repo))
        configrepos.remove(repo)

  def addConfigRepos(self):
    """
      add configuration repositories
    """
    configrepos = self.cruise_root.find("config-repos")
    # loop trough all defined source repositories
    # and append them to the config repos
    if configrepos is None:
      logger.debug("Config-Repos is empty. Creating parent element")
      configrepos = etree.Element("config-repos")
      # insert the config-repos element after the server element (2 place)
      self.cruise_root.insert(1,configrepos)

    for sr in self.source_repositories:
      repoId = os.path.basename(sr)
      # create xml elements
      logger.debug("Add config-repo {}".format(sr))
      configrepo = etree.Element("config-repo",pluginId="yaml.config.plugin",id=repoId)
      git = etree.Element("git", url="git@github.com:{}.git".format(sr))
      # append git config to config-repo element
      configrepo.append(git)
      # append config-repo to config-repos
      configrepos.append(configrepo)

  def removeSCMRepos(self):
    """
      remove all configuration repositories
    """
    scmrepos = self.cruise_root.find("scms")
    if scmrepos is not None:
      for repo in scmrepos.findall("scm"):
        logger.debug("Remove scm {}".format(repo))
        scmrepos.remove(repo)

  def addSCMRepos(self):
    """
      add configuration repositories
      https://docs.gocd.org/17.7.0/extension_points/scm_extension.html#sample-xml-configuration
    """
    scmrepos = self.cruise_root.find("scms")
    # loop trough all defined source repositories
    # and append them to the config repos
    if scmrepos is None:
      logger.debug("SCMs is empty. Creating parent element")
      scmrepos = etree.Element("scms")
      self.cruise_root.insert(1,scmrepos)

    for sr in self.source_repositories:
      logger.debug("Add SCM {}".format(sr))
      repoId = os.path.basename(sr)
      configrepo = etree.Element("scm",id=repoId, name=repoId)
      pluginConfig = etree.Element("pluginConfiguration", id="github.pr", version="1")
      cfg = etree.Element("configuration")
      prop = etree.Element("property")
      key = etree.Element("key")
      key.text = "url"
      val = etree.Element("value")
      val.text = "git@github.com:{}.git".format(sr)
      prop.append(key)
      prop.append(val)
      cfg.append(prop)
      configrepo.append(pluginConfig)
      configrepo.append(cfg)
      scmrepos.append(configrepo)


  def removeUndefinedEnvironments(self):
    """
      remove all undefined environments
    """
    environments = self.cruise_root.find("environments")
    if environments is not None:
      for env in environments.findall("environment"):
        if not env.attrib.get("name") in self.environments:
          logger.debug("Remove environment {}".format(env))
          environments.remove(env)

  def addEnvironments(self):
    """
      add defined environments
    """
    # get environments from xml
    environments = self.cruise_root.find("environments")
    if environments is None:
      logger.debug("environments  empty. Creating parent element")
      environments = etree.Element("environments")
      # insert the environments after the config-repos element (3 place)
      self.cruise_root.insert(3,environments)

    # create a list with all defined environments
    xmlenvs = []
    for xmlenv in environments.findall("environment"):
      xmlenvs.append(xmlenv.attrib.get("name"))

    # loop trough all defined environments
    for env in self.environments:
      if not env in xmlenvs:
        # create environment element
        logger.debug("create environment {}".format(env))
        element = etree.Element("environment",name=env)
        environments.append(element)

  def writeXMLConfiguration(self):
    """
      write the finished xml configuration
    """
    self.cruise.write(self.xmlfile, pretty_print=True, xml_declaration=True, encoding="utf-8")

  def chownXmlConfiguration(self):
    """
      change the ownership of the written xml configuration file
    """
    shutil.chown(self.xmlfile, user=self.owner, group=self.group)

def main():
    """
        main function
    """
    logger.info('Start cruise-config.xml configuration')

    logger.info('Load configuration')
    config = CruiseConfig()
    logger.info("Set Schema Version")
    config.setSchemaVersion()
    logger.info("Set Server Configuration")
    config.setServerConfiguration()
    logger.info("Remove Security Configuration")
    config.removeSecurityConfiguration()
    logger.info("Set Security Configuration")
    config.setSecurityConfiguration()
    logger.info("Remove Pipeline Configurations")
    config.removePipelines()
    logger.info("Remove Configuration Repositories")
    config.removeConfigRepos()
    logger.info("Remove SCM Repositories")
    config.removeSCMRepos()
    logger.info("Add Configuration Repositories")
    config.addConfigRepos()
    logger.info("Add SCM Repositories")
    config.addSCMRepos()
    logger.info("Remove undefined environments")
    config.removeUndefinedEnvironments()
    logger.info("Add environments")
    config.addEnvironments()
    logger.info("Write XML configuration")
    config.writeXMLConfiguration()
    logger.info("Set ownership of file")
    config.chownXmlConfiguration()

    logger.info('End cruise-config.xml configuration')

# main
if __name__ == '__main__':
    try:
        main()
    except Exception as err:
        logger.error(err)
        traceback.print_exc()




