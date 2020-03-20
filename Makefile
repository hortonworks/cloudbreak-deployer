NAME=cloudbreak-deployer
BINARYNAME=cbd
BINARY=cbd

ARTIFACTS=LICENSE.txt NOTICE.txt VERSION README
ARCH=$(shell uname -m)
VERSION_FILE=$(shell cat VERSION)
GIT_REV=$(shell git rev-parse --short HEAD)
GIT_BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
GIT_TAG=$(shell git describe --exact-match --tags 2>/dev/null )
S3_TARGET?=s3://public-repo-1.hortonworks.com/HDP/cloudbreak/

# if on a git tag, use that as a version number
ifeq ($(GIT_TAG),)
	  VERSION=$(VERSION_FILE)-$(GIT_BRANCH)
else
	  VERSION=$(GIT_TAG)
endif

# if on release branch dont use git revision
ifeq ($(GIT_BRANCH), release)
  FLAGS=" -X main.Version=$(VERSION)"
  VERSION=$(VERSION_FILE)
else
	FLAGS=" -X main.Version=$(VERSION) -X main.GitRevision=$(GIT_REV)"
endif

echo_version:
	echo GIT_TAG[$(GIT_TAG)]
ifeq ($(GIT_TAG),)
	echo EMPTY TAG
 else
	echo NOT_EMPTY_TAG
endif

	echo VERSION=$(VERSION)

update-container-versions:
	sed -i "0,/DOCKER_TAG_CAAS_MOCK/  s/DOCKER_TAG_CAAS_MOCK .*/DOCKER_TAG_CAAS_MOCK $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_PERISCOPE/ s/DOCKER_TAG_PERISCOPE .*/DOCKER_TAG_PERISCOPE $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_DATALAKE/ s/DOCKER_TAG_DATALAKE .*/DOCKER_TAG_DATALAKE $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_REDBEAMS/ s/DOCKER_TAG_REDBEAMS .*/DOCKER_TAG_REDBEAMS $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_ENVIRONMENT/ s/DOCKER_TAG_ENVIRONMENT .*/DOCKER_TAG_ENVIRONMENT $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_FREEIPA/ s/DOCKER_TAG_FREEIPA .*/DOCKER_TAG_FREEIPA $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_CLOUDBREAK/  s/DOCKER_TAG_CLOUDBREAK .*/DOCKER_TAG_CLOUDBREAK $(CB_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_ULUWATU/ s/DOCKER_TAG_ULUWATU .*/DOCKER_TAG_ULUWATU $(CB_VERSION)/" include/cloudbreak.bash

update-container-versions-cdpcp:
	sed -i "0,/DOCKER_TAG_IDBMMS/ s/DOCKER_TAG_IDBMMS .*/DOCKER_TAG_IDBMMS $(CDPCP_VERSION)/" include/cloudbreak.bash
	sed -i "0,/DOCKER_TAG_ENVIRONMENTS2_API/ s/DOCKER_TAG_ENVIRONMENTS2_API .*/DOCKER_TAG_ENVIRONMENTS2_API $(CDPCP_VERSION)/" include/cloudbreak.bash

push-container-versions: update-container-versions
	git add include/cloudbreak.bash
	git commit -m "Updated container versions to $(CB_VERSION)"
	git tag $(CB_VERSION)
	git push origin HEAD:$(GIT_BRANCH) --tags

push-container-versions-cdpcp: update-container-versions-cdpcp
	git add include/cloudbreak.bash
	git commit -m "Updated CDPCP container versions to $(CDPCP_VERSION)"
	git push origin HEAD:$(GIT_BRANCH)

build: bindata ## Creates linux an osx binaries in "build/$OS"
	go test
	mkdir -p build/Linux  && GOOS=linux  go build -ldflags $(FLAGS) -o build/Linux/$(BINARYNAME)
	mkdir -p build/Darwin && GOOS=darwin go build -ldflags $(FLAGS) -o build/Darwin/$(BINARYNAME)

create-snapshot-tgz: ## Creates snapshot tgz from binaries into snapshot dir
	rm -rf snapshots
	mkdir -p snapshots

	tar -czf snapshots/cloudbreak-deployer_snapshot_Linux_x86_64.tgz -C build/Linux cbd
	tar -czf snapshots/cloudbreak-deployer_snapshot_Darwin_x86_64.tgz -C build/Darwin cbd

upload-snapshot: create-snapshot-tgz
	@echo upload snapshot artifacts to $(S3_TARGET) ...
	@docker run \
		-v $(PWD):/data \
		-w /data \
		-e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
		-e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
		anigeo/awscli s3 cp snapshots/ $(S3_TARGET) --recursive --include "$(NAME)_$(VERSION)_*.tgz"
	rm -rf snapshots

bindata: deps-bindata
	go-bindata include templates .deps/bin

install: build ## Installs OS specific binary into: /usr/local/bin
	install build/$(shell uname -s)/$(BINARYNAME) /usr/local/bin

deps-bindata:
ifeq ($(shell which go-bindata),)
	go get -u github.com/go-bindata/go-bindata/...
endif

deps: deps-bindata ## Installs required cli tools (only needed for new envs)
	go get -u github.com/progrium/gh-release/...
	go get -u github.com/kardianos/govendor
	go get github.com/progrium/basht
#	go get github.com/github/hub
	go get || true

build-version: deps bindata build-darwin-version build-linux-version build-windows-version

prepare-release:
	rm -rf release && mkdir release

	cp $(ARTIFACTS) build/Linux/
	tar -zcf release/$(NAME)_$(VERSION)_Linux_$(ARCH).tgz -C build/Linux $(ARTIFACTS) $(BINARYNAME)
	cp $(ARTIFACTS) build/Darwin/
	tar -zcf release/$(NAME)_$(VERSION)_Darwin_$(ARCH).tgz -C build/Darwin $(ARTIFACTS) $(BINARYNAME)

build-version: deps bindata build-darwin-version build-linux-version build-windows-version

build-darwin-version:
	go test
	GOOS=darwin go build -ldflags $(FLAGS) -o build/Darwin/${BINARY}

build-linux-version:
	go test
	GOOS=linux go build -ldflags $(FLAGS) -o build/Linux/${BINARY}

build-windows-version:
	go test
	GOOS=windows go build -ldflags $(FLAGS) -o build/Windows/${BINARY}.exe

release: build
	rm -rf release
	mkdir release
	#git tag v${VERSION}
	git push https://${GITHUB_ACCESS_TOKEN}@github.com/hortonworks/cloudbreak-deployer.git v${VERSION}
	tar -zcvf release/cdp_${VERSION}_Darwin_x86_64.tgz -C build/Darwin "${BINARY}"
	tar -zcvf release/cdp_${VERSION}_Linux_x86_64.tgz -C build/Linux "${BINARY}"
	tar -zcvf release/cdp_${VERSION}_Windows_x86_64.tgz -C build/Windows "${BINARY}.exe"

release-version: build-version
	rm -rf release
	mkdir release
	#git tag v${VERSION}
	git push https://${GITHUB_ACCESS_TOKEN}@github.com/hortonworks/cloudbreak-deployer.git v${VERSION}
	tar -zcvf release/cdp_${VERSION}_Darwin_x86_64.tgz -C build/Darwin "${BINARY}"
	tar -zcvf release/cdp_${VERSION}_Linux_x86_64.tgz -C build/Linux "${BINARY}"
	tar -zcvf release/cdp_${VERSION}_Windows_x86_64.tgz -C build/Windows "${BINARY}.exe"

release-docker:
	@USER_NS='-u $(shell id -u $(whoami)):$(shell id -g $(whoami))'
	docker run --rm ${USER_NS} -v "${PWD}":/go/src/github.com/hortonworks/cloudbreak-deployer -w /go/src/github.com/hortonworks/cloudbreak-deployer -e VERSION=${VERSION} -e GITHUB_ACCESS_TOKEN=${GITHUB_TOKEN} golang:1.13.1 bash -c "make release"

release-docker-version:
	@USER_NS='-u $(shell id -u $(whoami)):$(shell id -g $(whoami))'
	docker run --rm ${USER_NS} -v "${PWD}":/go/src/github.com/hortonworks/cloudbreak-deployer -w /go/src/github.com/hortonworks/cloudbreak-deployer -e VERSION=${VERSION} -e GITHUB_ACCESS_TOKEN=${GITHUB_TOKEN} golang:1.13.1 bash -c "make release-version"

upload_s3:
	ls -1 release | xargs -I@ aws s3 cp release/@ s3://public-repo-1.hortonworks.com/HDP/cloudbreak/@ --acl public-read


circleci:
	rm ~/.gitconfig

clean:
	rm -rf build release

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: build release generate-aws-json help

.DEFAULT_GOAL := help



