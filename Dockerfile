FROM ubuntu:latest

ENV NODE_VERSION v18.12.0
ENV NVM_DIR /usr/src/.nvm
ENV NODE_PATH $NVM_DIR/versions/node/$NODE_VERSION/bin
ENV PATH $NODE_PATH:$PATH

ARG BLESS_USER_ID=999

COPY fonts.conf /etc/fonts/local.conf

# Update base image
RUN apt-get -qq update && \
  apt-get -qq dist-upgrade

# Add the partner repository
RUN apt-get -y -qq install software-properties-common && \
  apt-add-repository "deb http://archive.canonical.com/ubuntu $(lsb_release -sc) partner"

# Accept Microsoft EULA agreement for ttf-mscorefonts-installer
RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

# Install dependencies for Chrome / Chromium
RUN apt-get -y -qq --no-install-recommends install \
  build-essential \
  ca-certificates \
  curl \
  dumb-init \
  ffmpeg \
  fontconfig \
  fonts-freefont-ttf \
  fonts-gfs-neohellenic \
  fonts-indic \
  fonts-ipafont-gothic \
  fonts-kacst \
  fonts-liberation \
  fonts-noto-cjk \
  fonts-noto-color-emoji \
  fonts-roboto \
  fonts-thai-tlwg \
  fonts-ubuntu \
  fonts-wqy-zenhei \
  gconf-service \
  git \
  libappindicator1 \
  libappindicator3-1 \
  libasound2 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libc6 \
  libcairo2 \
  libcups2 \
  libdbus-1-3 \
  libexpat1 \
  libfontconfig1 \
  libgbm-dev \
  libgbm1 \
  libgcc1 \
  libgconf-2-4 \
  libgdk-pixbuf2.0-0 \
  libglib2.0-0 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libpango-1.0-0 \
  libpangocairo-1.0-0 \
  libstdc++6 \
  libu2f-udev \
  libx11-6 \
  libx11-xcb1 \
  libxcb1 \
  libxcomposite1 \
  libxcursor1 \
  libxdamage1 \
  libxext6 \
  libxfixes3 \
  libxi6 \
  libxrandr2 \
  libxrender1 \
  libxss1 \
  libxtst6 \
  locales \
  lsb-release \
  msttcorefonts \
  pdftk \
  unzip \
  wget \
  xdg-utils \
  xvfb

# Install nvm with node and npm
RUN mkdir -p $NVM_DIR &&\
  curl -sL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash &&\
  . $NVM_DIR/nvm.sh &&\
  nvm install $NODE_VERSION

# Cleanup
RUN fc-cache -f -v && \
  apt-get -qq clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add the browserless user (blessuser)
RUN groupadd -r blessuser && useradd --uid ${BLESS_USER_ID} -r -g blessuser -G audio,video blessuser && \
  mkdir -p /home/blessuser/Downloads && \
  chown -R blessuser:blessuser /home/blessuser


# Build Args
ARG USE_CHROME_STABLE
ARG CHROME_STABLE_VERSION
ARG PUPPETEER_CHROMIUM_REVISION
ARG PUPPETEER_VERSION
ARG PORT=3000

# Application parameters and variables
ENV APP_DIR=/usr/src/app
ENV PUPPETEER_CACHE_DIR=${APP_DIR}
ENV PLAYWRIGHT_BROWSERS_PATH=${APP_DIR}
ENV CONNECTION_TIMEOUT=60000
ENV CHROME_PATH=/usr/bin/google-chrome
ENV HOST=0.0.0.0
ENV IS_DOCKER=true
ENV LANG="C.UTF-8"
ENV NODE_ENV=production
ENV PORT=${PORT}
ENV PUPPETEER_CHROMIUM_REVISION=${PUPPETEER_CHROMIUM_REVISION}
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV USE_CHROME_STABLE=${USE_CHROME_STABLE}
ENV WORKSPACE_DIR=$APP_DIR/workspace

RUN mkdir -p $APP_DIR $WORKSPACE_DIR

WORKDIR $APP_DIR

# Install app dependencies
COPY . .

# Install Chrome Stable when specified
RUN if [ -n "$CHROME_STABLE_VERSION" ]; then \
    wget -q -O /tmp/chrome.deb https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_STABLE_VERSION}-1_amd64.deb && \
    apt install -y /tmp/chrome.deb &&\
    rm /tmp/chrome.deb; \
  elif [ "$USE_CHROME_STABLE" = "true" ]; then \
    cd /tmp &&\
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb &&\
    dpkg -i google-chrome-stable_current_amd64.deb;\
  fi

# Build and install external binaries + assets
# NOTE: The `PUPPETEER_VERSION` is needed for production versions
# listed in package.json
RUN if [ "$USE_CHROME_STABLE" = "true" ]; then \
    export CHROMEDRIVER_SKIP_DOWNLOAD=false;\
  else \
    export CHROMEDRIVER_SKIP_DOWNLOAD=true;\
  fi &&\
  npm i puppeteer@$PUPPETEER_VERSION;\
  npm run postinstall &&\
  npm run build &&\
  npm prune --production &&\
  chown -R blessuser:blessuser $APP_DIR


RUN echo "deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse" > /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse" >> /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu focal-security main restricted universe multiverse" >> /etc/apt/sources.list



# Install x11vnc
RUN apt-get update && apt-get install -y x11vnc

# Run everything after as non-privileged user.
USER blessuser

# Expose the web-socket and HTTP ports
EXPOSE ${PORT} 9222 
EXPOSE 5900:5900



CMD ["./start.sh"]
