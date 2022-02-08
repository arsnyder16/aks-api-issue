FROM buildpack-deps:bionic-curl

RUN set -ex \ 
    && apt-get update \
    && curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get install --no-install-recommends -y \        
        nodejs \
        git \
    && rm -rf /var/lib/apt/lists/*

COPY package-lock.json .
COPY package.json .
RUN npm ci --only=production
COPY controller.js .

ENTRYPOINT [ "node", "controller.js"]