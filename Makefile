# simple makefile to build and push docker container images
IMAGE_NAME = projectthor/gocd-server

# If the GoCD label is set overwrite the commit ID env variable
ifneq ($(GO_PIPELINE_LABEL),)
	export COMMIT_ID := $(GO_PIPELINE_LABEL)	
else
	export COMMIT_ID = latest
endif

# build
# build a new docker image
build_commit:
	docker build -t $(IMAGE_NAME):$(COMMIT_ID) .

# latest
# set the latest tag for the image with the specified nextcloud version tag
build_latest:
	docker build --build-arg PLUGIN_YAML_CONFIG_PLUGIN=$(PLUGIN_YAML_CONFIG_PLUGIN) -t $(IMAGE_NAME):latest .

# push the commit tag
push_commit:
	docker push $(IMAGE_NAME):$(COMMIT_ID)

# push the build containers
push_latest:
	docker push $(IMAGE_NAME):latest
