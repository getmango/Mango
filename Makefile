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

clean:
	rm -rf dist
	rm yarn.lock
	rm -rf node_modules
