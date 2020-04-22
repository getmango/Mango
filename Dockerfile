FROM crystallang/crystal:0.34.0-alpine AS builder

WORKDIR /Mango

COPY . .
COPY package*.json .
RUN apk add --no-cache yarn yaml sqlite-static \
    && make static

FROM library/alpine

WORKDIR /

COPY --from=builder /Mango/mango .

CMD ["./mango"]
