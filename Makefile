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
	crystal build src/mango.cr --release --progress

static: uglify | libs
	crystal build src/mango.cr --release --progress --static

libs:
	shards install --production

run:
	crystal run src/mango.cr --error-trace

test:
	crystal spec

check:
	crystal tool format --check
	./bin/ameba
	./dev/linewidth.sh

arm32v7:
	crystal build src/mango.cr --release --progress --cross-compile --target='arm-linux-gnueabihf'
	mv mango.o mango.arm32v7.o

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
