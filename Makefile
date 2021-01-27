PREFIX ?= /usr/local
INSTALL_DIR=$(PREFIX)/bin

all: uglify | build

uglify:
	yarn
	yarn uglify

setup: libs
	yarn
	yarn gulp dev

build: libs
	crystal build src/mango.cr --release --progress --error-trace

static: uglify | libs
	crystal build src/mango.cr --release --progress --static --error-trace

libs:
	shards install --production

run:
	crystal run src/mango.cr --error-trace

test:
	crystal spec

check:
	crystal tool format --check
	./bin/ameba

arm32v7:
	crystal build src/mango.cr --release --progress --error-trace --cross-compile --target='arm-linux-gnueabihf' -o mango-arm32v7

arm64v8:
	crystal build src/mango.cr --release --progress --error-trace --cross-compile --target='aarch64-linux-gnu' -o mango-arm64v8

install:
	cp mango $(INSTALL_DIR)/mango

uninstall:
	rm -f $(INSTALL_DIR)/mango

cleandist:
	rm -rf dist
	rm -f yarn.lock
	rm -rf node_modules

clean:
	rm -f mango
