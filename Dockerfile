FROM crystallang/crystal:0.32.1-alpine AS builder

WORKDIR /Mango

COPY . .
COPY package*.json .
RUN apk add --no-cache yarn yaml sqlite-static \
    && make static

FROM library/alpine

WORKDIR /root

COPY --from=builder /Mango/mango ./Mango/

CMD ["/root/Mango/mango"]
