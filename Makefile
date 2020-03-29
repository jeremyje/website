# Copyright 2020 Codecahedron Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BASE_VERSION = 0.0.0-dev
SHORT_SHA = $(shell git rev-parse --short=7 HEAD | tr -d [:punct:])
VERSION_SUFFIX = $(SHORT_SHA)
BRANCH_NAME = $(shell git rev-parse --abbrev-ref HEAD | tr -d [:punct:])
VERSION = $(BASE_VERSION)-$(VERSION_SUFFIX)
BUILD_DATE = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
YEAR_MONTH = $(shell date -u +'%Y%m')
MAJOR_MINOR_VERSION = $(shell echo $(BASE_VERSION) | cut -d '.' -f1).$(shell echo $(BASE_VERSION) | cut -d '.' -f2)

HUGO_VERSION = 0.64.1
NODEJS_VERSION = 12.16.1
HTMLTEST_VERSION = 0.10.3
SWAGGERUI_VERSION = 3.22.3

REPOSITORY_ROOT := $(patsubst %/,%,$(dir $(abspath $(MAKEFILE_LIST))))
SITE_DIR = $(REPOSITORY_ROOT)
BUILD_DIR = $(REPOSITORY_ROOT)/build
TOOLCHAIN_DIR = $(BUILD_DIR)/toolchain
TOOLCHAIN_BIN = $(TOOLCHAIN_DIR)/bin
NODEJS_BIN = $(TOOLCHAIN_DIR)/nodejs/bin
EXE_EXTENSION =
SITE_HOST = localhost
SITE_PORT = 8080
RENDERED_SITE_DIR = $(REPOSITORY_ROOT)/build/site
HTMLTEST = $(TOOLCHAIN_BIN)/htmltest$(EXE_EXTENSION)
HUGO = $(TOOLCHAIN_BIN)/hugo$(EXE_EXTENSION)

export PATH := $(REPOSITORY_ROOT)/node_modules/.bin/:$(TOOLCHAIN_BIN):$(TOOLCHAIN_DIR)/nodejs/bin:$(PATH)

ifeq ($(OS),Windows_NT)
	# TODO: Windows packages are here but things are broken since many paths are Linux based and zip vs tar.gz.
	EXE_EXTENSION = .exe
	HUGO_PACKAGE = https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/hugo_extended_$(HUGO_VERSION)_Windows-64bit.zip
	NODEJS_PACKAGE = https://storage.googleapis.com/codecahedron-cdn/windows/node-v$(NODEJS_VERSION)-win-x64.zip
	NODEJS_PACKAGE_NAME = nodejs.zip
	HTMLTEST_PACKAGE = https://github.com/wjdp/htmltest/releases/download/v$(HTMLTEST_VERSION)/htmltest_$(HTMLTEST_VERSION)_windows_amd64.zip
	SED_REPLACE = sed -i
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		HUGO_PACKAGE = https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/hugo_extended_$(HUGO_VERSION)_Linux-64bit.tar.gz
		NODEJS_PACKAGE = https://storage.googleapis.com/codecahedron-cdn/linux/node-v$(NODEJS_VERSION)-linux-x64.tar.gz
		NODEJS_PACKAGE_NAME = nodejs.tar.gz
		HTMLTEST_PACKAGE = https://github.com/wjdp/htmltest/releases/download/v$(HTMLTEST_VERSION)/htmltest_$(HTMLTEST_VERSION)_linux_amd64.tar.gz
		SED_REPLACE = sed -i
	endif
	ifeq ($(UNAME_S),Darwin)
		HUGO_PACKAGE = https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/hugo_extended_$(HUGO_VERSION)_macOS-64bit.tar.gz
		NODEJS_PACKAGE = https://storage.googleapis.com/codecahedron-cdn/macos/node-v$(NODEJS_VERSION)-darwin-x64.tar.gz
		NODEJS_PACKAGE_NAME = nodejs.tar.gz
		HTMLTEST_PACKAGE = https://github.com/wjdp/htmltest/releases/download/v$(HTMLTEST_VERSION)/htmltest_$(HTMLTEST_VERSION)_osx_amd64.tar.gz
		SED_REPLACE = sed -i ''
	endif
endif

help:
	@cat Makefile | grep ^\#\# | grep -v ^\#\#\# |cut -c 4-

SITE_TOOLCHAIN = build/toolchain/bin/hugo$(EXE_EXTENSION) build/toolchain/bin/htmltest$(EXE_EXTENSION)
presubmit: clean $(SITE_TOOLCHAIN) build test

build/toolchain/bin/hugo$(EXE_EXTENSION):
	mkdir -p $(TOOLCHAIN_BIN)
	mkdir -p $(TOOLCHAIN_DIR)/temp-hugo
ifeq ($(suffix $(HUGO_PACKAGE)),.zip)
	cd $(TOOLCHAIN_DIR)/temp-hugo && curl -Lo hugo.zip $(HUGO_PACKAGE) && unzip -q -o hugo.zip
else
	cd $(TOOLCHAIN_DIR)/temp-hugo && curl -Lo hugo.tar.gz $(HUGO_PACKAGE) && tar xzf hugo.tar.gz
endif
	mv $(TOOLCHAIN_DIR)/temp-hugo/hugo$(EXE_EXTENSION) $(TOOLCHAIN_BIN)/hugo$(EXE_EXTENSION)
	rm -rf $(TOOLCHAIN_DIR)/temp-hugo/

build/toolchain/bin/htmltest$(EXE_EXTENSION):
	mkdir -p $(TOOLCHAIN_BIN)
	mkdir -p $(TOOLCHAIN_DIR)/temp-htmltest
ifeq ($(suffix $(HTMLTEST_PACKAGE)),.zip)
	cd $(TOOLCHAIN_DIR)/temp-htmltest && curl -Lo htmltest.zip $(HTMLTEST_PACKAGE) && unzip -q -o htmltest.zip
else
	cd $(TOOLCHAIN_DIR)/temp-htmltest && curl -Lo htmltest.tar.gz $(HTMLTEST_PACKAGE) && tar xzf htmltest.tar.gz
endif
	mv $(TOOLCHAIN_DIR)/temp-htmltest/htmltest$(EXE_EXTENSION) $(TOOLCHAIN_BIN)/htmltest$(EXE_EXTENSION)
	rm -rf $(TOOLCHAIN_DIR)/temp-htmltest/

build/archives/$(NODEJS_PACKAGE_NAME):
	mkdir -p $(BUILD_DIR)/archives/
	cd $(BUILD_DIR)/archives/ && curl -L -o $(NODEJS_PACKAGE_NAME) $(NODEJS_PACKAGE)

build/toolchain/nodejs/: build/archives/$(NODEJS_PACKAGE_NAME)
	mkdir -p $(TOOLCHAIN_DIR)/nodejs/
ifeq ($(suffix $(NODEJS_PACKAGE_NAME)),.zip)
	# TODO: This is broken, there's the node-v10.15.3-win-x64 directory also windows does not have the bin/ directory.
	# https://superuser.com/questions/518347/equivalent-to-tars-strip-components-1-in-unzip
	cd $(TOOLCHAIN_DIR)/nodejs/ && unzip -q -o $(BUILD_DIR)/archives/$(NODEJS_PACKAGE_NAME)
else
	cd $(TOOLCHAIN_DIR)/nodejs/ && tar xzf $(BUILD_DIR)/archives/$(NODEJS_PACKAGE_NAME) --strip-components 1
endif

check: test
test: TEMP_SITE_DIR := /tmp/codecahedron-test
test: build/toolchain/bin/hugo$(EXE_EXTENSION) build/toolchain/bin/htmltest$(EXE_EXTENSION) build/site/
	rm -rf $(TEMP_SITE_DIR)
	mkdir -p $(TEMP_SITE_DIR)/site/
	cp -rf $(RENDERED_SITE_DIR)/public/* $(TEMP_SITE_DIR)/site/
	$(HTMLTEST) --conf $(SITE_DIR)/htmltest.yaml $(TEMP_SITE_DIR)/site

run: build/toolchain/bin/hugo$(EXE_EXTENSION) node_modules/
	@echo $(CURDIR)
	$(HUGO) server --debug --watch --enableGitInfo . --baseURL=http://localhost:$(SITE_PORT)/ --bind 0.0.0.0 --port $(SITE_PORT) --disableFastRender

node_modules/: build/toolchain/nodejs/
	-rm -r $(REPOSITORY_ROOT)/package.json $(REPOSITORY_ROOT)/package-lock.json
	-rm -rf $(REPOSITORY_ROOT)/node_modules/
	echo "{}" > $(REPOSITORY_ROOT)/package.json
	$(NODEJS_BIN)/npm install postcss-cli autoprefixer
	$(TOOLCHAIN_DIR)/nodejs/bin/npm install postcss-cli autoprefixer

build/site/: build/toolchain/bin/hugo$(EXE_EXTENSION) node_modules/
	rm -rf $(RENDERED_SITE_DIR)/
	mkdir -p $(RENDERED_SITE_DIR)/
	$(HUGO) --config=config.toml --source . --destination $(RENDERED_SITE_DIR)/public/

build: build/site/
	# TODO: Add test as a build dependency.
	echo "Root Directory: $(RENDERED_SITE_DIR)"
	ls $(RENDERED_SITE_DIR)

clean: clean-site clean-build clean-toolchain clean-archives clean-nodejs

clean-site:
	rm -rf build/site/

clean-build: clean-toolchain clean-archives
	rm -rf $(BUILD_DIR)/

clean-toolchain:
	rm -rf $(TOOLCHAIN_DIR)/

clean-archives:
	rm -rf $(BUILD_DIR)/archives/

clean-nodejs:
	rm -rf $(TOOLCHAIN_DIR)/nodejs/
	rm -rf $(REPOSITORY_ROOT)/node_modules/
	rm -f $(REPOSITORY_ROOT)/package.json
	rm -f $(REPOSITORY_ROOT)/package-lock.json

# Prevents users from running with sudo.
# There's an exception for Google Cloud Build because it runs as root.
no-sudo:
ifndef ALLOW_BUILD_WITH_SUDO
ifeq ($(shell whoami),root)
	@echo "ERROR: Running Makefile as root (or sudo)"
	@echo "Please follow the instructions at https://docs.docker.com/install/linux/linux-postinstall/ if you are trying to sudo run the Makefile because of the 'Cannot connect to the Docker daemon' error."
	@echo "NOTE: sudo/root do not have the authentication token to talk to any GCP service via gcloud."
	exit 1
endif
endif

.PHONY: help check test run netlify-build clean clean-site clean-build clean-toolchain clean-archives clean-nodejs no-sudo
