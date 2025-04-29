FROM crystallang/crystal:1.0.0-alpine AS builder

WORKDIR /Mango

COPY . .
RUN apk add --no-cache yarn yaml-static sqlite-static libarchive-dev libarchive-static acl-static expat-static zstd-static lz4-static bzip2-static libjpeg-turbo-dev libpng-dev tiff-dev
RUN make static || make static

FROM library/alpine

WORKDIR /

COPY --from=builder /Mango/mango /usr/local/bin/mango

EXPOSE 9000

CMD ["/usr/local/bin/mango"]
