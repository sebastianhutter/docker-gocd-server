#!/usr/bin/env python3

"""
  python script to parse the cruise-config.xml file
"""

from lxml import etree
import os
from io import StringIO, BytesIO
import logging
import traceback

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
  logger.setLevel(logging.info)

class CruiseConfig:
  """
    cruise-config xml representation and config values
  """

  def __init__(self):
    """
      initialize configuration values
    """
    self.xmlfile = "/etc/go/cruise-config.xml"
    self.templatefile = "/cruise-config.xml.template"

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
    self.schemaversion = os.getenv("GOCD_SCHEMAVERSION","93")

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
    server = self.cruise_root.find("server")

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
      # create xml elements
      logger.debug("Add config-repo {}".format(sr))
      configrepo = etree.Element("config-repo",plugin="yaml.config.plugin")
      git = etree.Element("git", url="git@github.com:{}.git".format(sr))
      # append git config to config-repo element
      configrepo.append(git)
      # append config-repo to config-repos
      configrepos.append(configrepo)

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
      self.cruise_root.insert(2,environments)

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
    logger.info("Remove Pipeline Configurations")
    config.removePipelines()
    logger.info("Remove Configuration Repositories")
    config.removeConfigRepos()
    logger.info("Add Configuration Repositories")
    config.addConfigRepos()
    logger.info("Remove undefined environments")
    config.removeUndefinedEnvironments()
    logger.info("Add environments")
    config.addEnvironments()
    logger.info("Write XML configuration")
    config.writeXMLConfiguration()

    logger.info('End cruise-config.xml configuration')

# main
if __name__ == '__main__':
    try:
        main()
    except Exception as err:
        logger.error(err)
        traceback.print_exc()




