FROM crystallang/crystal:0.32.1-alpine

WORKDIR /Mango

COPY . .
COPY package*.json .
RUN apk add --no-cache nodejs yarn sqlite sqlite-doc sqlite-static sqlite-dev sqlite-libs yaml \
    && apk add uglifycss uglify-js --repository http://nl.alpinelinux.org/alpine/edge/testing/ \
    && make static

FROM library/alpine

WORKDIR /root

COPY --from=0 /Mango/mango ./Mango/

CMD ["/root/Mango/mango"]
