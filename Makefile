# simple makefile to build and push docker container images
IMAGE_NAME = "sebastianhutter/gocd-server"
IMAGE_VERSION = "0.0.1"
PLUGIN_YAML_CONFIG_PLUGIN="0.4.0"
# build
# build a new docker image
.PHONY: build
build:
	docker build --build-arg PLUGIN_YAML_CONFIG_PLUGIN=$(PLUGIN_YAML_CONFIG_PLUGIN) -t $(IMAGE_NAME):$(IMAGE_VERSION) .

# latest
# set the latest tag for the image with the specified nextcloud version tag
.PHONY: latest
latest:
	docker build --build-arg PLUGIN_YAML_CONFIG_PLUGIN=$(PLUGIN_YAML_CONFIG_PLUGIN) -t $(IMAGE_NAME):latest .
# push the build containers
.PHONY: push
push:
		docker push $(IMAGE_NAME):$(IMAGE_VERSION)
		docker push $(IMAGE_NAME):latest
