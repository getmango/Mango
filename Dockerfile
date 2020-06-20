FROM crystallang/crystal:0.35.1-alpine AS builder

WORKDIR /Mango

COPY . .
COPY package*.json .
RUN apk add --no-cache yarn yaml sqlite-static libarchive-dev libarchive-static acl-static expat-static zstd-static lz4-static bzip2-static \
    && make static

FROM library/alpine

WORKDIR /

COPY --from=builder /Mango/mango .

CMD ["./mango"]
