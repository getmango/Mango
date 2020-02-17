FROM crystallang/crystal:0.32.0

RUN apt-get update && apt-get install -y curl

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update && apt-get install -y nodejs yarn libsqlite3-dev

WORKDIR /Mango

COPY . .
COPY package*.json .

RUN make && make install

CMD ["mango"]
