build:
	yarn
	yarn uglify
	shards install
	crystal build src/mango.cr --release --progress
run:
	crystal run src/mango.cr --error-trace
clean:
	rm mango
	rm -rf dist
	rm yarn.lock
	rm -rf node_modules
