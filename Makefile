NAME=cloudbreak-deployer
BINARYNAME=cbd
BINARY=cbd

ARTIFACTS=LICENSE.txt NOTICE.txt VERSION README
ARCH=$(shell uname -m)
VERSION_FILE=$(shell cat VERSION)
GIT_REV=$(shell git rev-parse --short HEAD)
GIT_BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
S3_TARGET?=s3://public-repo-1.hortonworks.com/HDP/cloudbreak/
ifeq ($(VERSION),)
    	VERSION = $(shell echo \${GIT_BRANCH}-snapshot)
endif
FLAGS=" -X main.Version=$(VERSION)"
GO_IMAGE_VERSION=1.20.1
GO_IMAGE=golang

update-container-versions:
	sed -i "0,/DOCKER_TAG_THUNDERHEAD_MOCK/  s/DOCKER_TAG_THUNDERHEAD_MOCK .*/DOCKER_TAG_THUNDERHEAD_MOCK $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_MOCK_INFRASTRUCTURE/  s/DOCKER_TAG_MOCK_INFRASTRUCTURE .*/DOCKER_TAG_MOCK_INFRASTRUCTURE $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_PERISCOPE/ s/DOCKER_TAG_PERISCOPE .*/DOCKER_TAG_PERISCOPE $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_DATALAKE/ s/DOCKER_TAG_DATALAKE .*/DOCKER_TAG_DATALAKE $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_REDBEAMS/ s/DOCKER_TAG_REDBEAMS .*/DOCKER_TAG_REDBEAMS $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_ENVIRONMENT/ s/DOCKER_TAG_ENVIRONMENT .*/DOCKER_TAG_ENVIRONMENT $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_FREEIPA/ s/DOCKER_TAG_FREEIPA .*/DOCKER_TAG_FREEIPA $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_CLOUDBREAK/  s/DOCKER_TAG_CLOUDBREAK .*/DOCKER_TAG_CLOUDBREAK $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_CONSUMPTION/  s/DOCKER_TAG_CONSUMPTION .*/DOCKER_TAG_CONSUMPTION $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_ULUWATU/ s/DOCKER_TAG_ULUWATU .*/DOCKER_TAG_ULUWATU $(CB_VERSION)/" include/cloudbreak.bash

update-container-versions-cdpcp:
	sed -i "0,/DOCKER_TAG_IDBMMS/ s/DOCKER_TAG_IDBMMS .*/DOCKER_TAG_IDBMMS $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_WORKLOADIAM/ s/DOCKER_TAG_WORKLOADIAM .*/DOCKER_TAG_WORKLOADIAM $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_ENVIRONMENTS2_API/ s/DOCKER_TAG_ENVIRONMENTS2_API .*/DOCKER_TAG_ENVIRONMENTS2_API $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_DATALAKE_API/ s/DOCKER_TAG_DATALAKE_API .*/DOCKER_TAG_DATALAKE_API $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_DISTROX_API/ s/DOCKER_TAG_DISTROX_API .*/DOCKER_TAG_DISTROX_API $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_AUDIT/ s/DOCKER_TAG_AUDIT .*/DOCKER_TAG_AUDIT $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_DATALAKE_DR/ s/DOCKER_TAG_DATALAKE_DR .*/DOCKER_TAG_DATALAKE_DR $(CDPCP_VERSION)/" include/cloudbreak.bash

push-container-versions: update-container-versions
	git add include/cloudbreak.bash
	git commit -m "Updated container versions to $(CB_VERSION)"
	git tag $(CB_VERSION)
	git push origin HEAD:$(GIT_BRANCH) --tags

push-container-versions-cdpcp: update-container-versions-cdpcp
	git add include/cloudbreak.bash
	git commit -m "Updated CDPCP container versions to $(CDPCP_VERSION)"
	git push origin HEAD:$(GIT_BRANCH)

build: bindata
	go test
	mkdir -p build/Linux  && GOOS=linux  go build -ldflags $(FLAGS) -o build/Linux/$(BINARYNAME)
	mkdir -p build/Darwin && GOOS=darwin go build -ldflags $(FLAGS) -o build/Darwin/$(BINARYNAME)

deps-bindata:
ifeq ($(shell which go-bindata),)
	go get -u github.com/go-bindata/go-bindata/...
	go install -mod=mod github.com/go-bindata/go-bindata/...
endif

_bindata: deps-bindata
	go-bindata include templates .deps/bin

_bindata-docker:
	@ docker run --rm -v "${PWD}":/go/src/github.com/hortonworks/cloudbreak-deployer -w /go/src/github.com/hortonworks/cloudbreak-deployer -e GO111MODULE=on $(GO_IMAGE):$(GO_IMAGE_VERSION) make _bindata

bindata:
	@ if which docker; then \
		make _bindata-docker; \
	else \
		make _bindata; \
    fi

install: build ## Installs OS specific binary into: /usr/local/bin and ~/.local/bin
	install build/$(shell uname -s)/$(BINARYNAME) /usr/local/bin || true
	install build/$(shell uname -s)/$(BINARYNAME) ~/.local/bin || true

prepare-release:
	rm -rf release && mkdir release

	cp $(ARTIFACTS) build/Linux/
	tar -zcf release/$(NAME)_$(VERSION)_Linux_$(ARCH).tgz -C build/Linux $(ARTIFACTS) $(BINARYNAME)
	cp $(ARTIFACTS) build/Darwin/
	tar -zcf release/$(NAME)_$(VERSION)_Darwin_$(ARCH).tgz -C build/Darwin $(ARTIFACTS) $(BINARYNAME)

release: build
	rm -rf release
	mkdir release
	tar -zcvf release/$(NAME)_${VERSION}_Darwin_x86_64.tgz -C build/Darwin "${BINARY}"
	tar -zcvf release/$(NAME)_${VERSION}_Linux_x86_64.tgz -C build/Linux "${BINARY}"

release-version: build
	rm -rf release
	mkdir release
	tar -zcvf release/$(NAME)_${VERSION}_Darwin_x86_64.tgz -C build/Darwin "${BINARY}"
	tar -zcvf release/$(NAME)_${VERSION}_Linux_x86_64.tgz -C build/Linux "${BINARY}"

release-docker:
	@USER_NS='-u $(shell id -u $(whoami)):$(shell id -g $(whoami))'
	docker run --rm ${USER_NS} -v "${PWD}":/go/src/github.com/hortonworks/cloudbreak-deployer -w /go/src/github.com/hortonworks/cloudbreak-deployer -e VERSION=${VERSION} -e GITHUB_ACCESS_TOKEN=${GITHUB_TOKEN} $(GO_IMAGE):$(GO_IMAGE_VERSION) bash -c "make release"

release-docker-version:
	@USER_NS='-u $(shell id -u $(whoami)):$(shell id -g $(whoami))'
	docker run --rm ${USER_NS} -v "${PWD}":/go/src/github.com/hortonworks/cloudbreak-deployer -w /go/src/github.com/hortonworks/cloudbreak-deployer -e VERSION=${VERSION} -e GITHUB_ACCESS_TOKEN=${GITHUB_TOKEN} $(GO_IMAGE):$(GO_IMAGE_VERSION) bash -c "make release-version"

upload_s3:
	ls -1 release | xargs -I@ aws s3 cp release/@ s3://public-repo-1.hortonworks.com/HDP/cloudbreak/@ --acl public-read

mod-tidy:
	@docker run --rm -v "${PWD}":/go/src/github.com/hortonworks/cloudbreak-deployer -w /go/src/github.com/hortonworks/cloudbreak-deployer -e GO111MODULE=on $(GO_IMAGE):$(GO_IMAGE_VERSION) make _mod-tidy

_mod-tidy:
	go mod tidy -v
	go mod vendor

circleci:
	rm ~/.gitconfig

clean:
	rm -rf build release

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: build release generate-aws-json help

.DEFAULT_GOAL := help
