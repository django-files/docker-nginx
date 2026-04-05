FROM debian:bookworm-slim AS builder

ARG NGINX_VERSION=1.29.1
ARG RTMP_MODULE_VERSION=master

ENV NGINX_VERSION=${NGINX_VERSION}
ENV RTMP_MODULE_VERSION=${RTMP_MODULE_VERSION}

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        build-essential \
        ca-certificates \
        linux-headers-generic \
        libssl-dev \
        libpcre2-dev \
        git \
        zlib1g-dev \
        curl && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl --proto '=https' -L "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar xz && \
    git clone https://github.com/arut/nginx-rtmp-module.git -b "${RTMP_MODULE_VERSION}" && \
    cp ./nginx-rtmp-module/stat.xsl /stat.xsl

WORKDIR /tmp/build/nginx-${NGINX_VERSION}
RUN ./configure \
    --user=nginx \
    --group=nginx \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_gzip_static_module \
    --with-http_secure_link_module \
    --with-threads \
    --with-file-aio \
    --add-module=../nginx-rtmp-module
RUN make -j"$(nproc)" && make install
RUN rm -rf /tmp/build


FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/django-files/docker-nginx"
LABEL org.opencontainers.image.description="Nginx with RTMP module"

ENV TZ=UTC

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        libssl3 \
        zlib1g \
        libpcre2-8-0 \
        curl && \
    groupadd -g 101 nginx && \
    useradd -r -d /var/cache/nginx -M -u 101 -g 101 -s /usr/sbin/nologin nginx && \
    mkdir -p /etc/nginx/conf.rtmp.d /opt/nginx /tmp/record /tmp/hls && \
    chown nginx /tmp/record /tmp/hls && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /stat.xsl /stat.xsl
