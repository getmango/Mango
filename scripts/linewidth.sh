#!/bin/sh

[ ! -z "$(grep '.\{80\}' --exclude-dir=lib --include="*.cr" -nr --color=always . | tee /dev/tty)" ] \
	&& echo "The above lines exceed the 80 characters limit" \
	|| exit 0
