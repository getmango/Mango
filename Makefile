PREFIX=/usr/local
INSTALL_DIR=$(PREFIX)/bin

all: uglify | build

uglify:
	yarn
	yarn uglify

build: libs
	crystal build src/mango.cr --release --progress

libs:
	shards install

run:
	crystal run src/mango.cr --error-trace

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
