FROM alpine AS prep

LABEL maintainer="DmitriVLK" \
      contributors="See CONTRIBUTORS file <https://github.com/siomiz/SoftEtherVPN/blob/master/CONTRIBUTORS>"

ENV BUILD_VERSION=4.44-9807-rtm \
    SHA256_SUM=8CCD8959A674BD4B34F9FC5DD9EB60FE0226B0ADC0F6F852A07011DCC769ED97

RUN wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/archive/v${BUILD_VERSION}.tar.gz \
    && echo "${SHA256_SUM}  v${BUILD_VERSION}.tar.gz" | sha256sum -c \
    && mkdir -p /usr/local/src \
    && tar -x -C /usr/local/src/ -f v${BUILD_VERSION}.tar.gz \
    && rm v${BUILD_VERSION}.tar.gz

FROM debian:12 AS build

COPY --from=prep /usr/local/src /usr/local/src

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    libncurses6 \
    libncurses-dev \
    libreadline8 \
    libreadline-dev \
    libssl3 \
    libssl-dev \
    wget \
    zlib1g \
    zlib1g-dev \
    zip \
    && cd /usr/local/src/SoftEtherVPN_Stable-* \
    && ./configure \
    && make \
    && make install \
    && touch /usr/vpnserver/vpn_server.config \
    && zip -r9 /artifacts.zip /usr/vpn* /usr/bin/vpn*

FROM debian:12-slim

COPY --from=build /artifacts.zip /

COPY copyables /

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libncurses6 \
    libreadline8 \
    libssl3 \
    iptables \
    unzip \
    zlib1g \
    && unzip -o /artifacts.zip -d / \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x /entrypoint.sh /gencert.sh \
    && rm /artifacts.zip \
    && rm -rf /opt \
    && ln -s /usr/vpnserver /opt \
    && find /usr/bin/vpn* -type f ! -name vpnserver \
       -exec bash -c 'ln -s {} /opt/$(basename {})' \;

WORKDIR /usr/vpnserver/

VOLUME ["/usr/vpnserver/server_log/", "/usr/vpnserver/packet_log/", "/usr/vpnserver/security_log/"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 500/udp 4500/udp 1701/tcp 1194/udp 5555/tcp 443/tcp

CMD ["/usr/bin/vpnserver", "execsvc"]
