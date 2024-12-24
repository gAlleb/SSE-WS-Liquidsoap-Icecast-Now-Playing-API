FROM alpine:3.20@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5 AS builder

ARG VERSION

RUN apk --no-cache add \
    build-base \
    # Icecast
    curl-dev \
    libogg-dev \
    libtheora-dev \
    libvorbis-dev \
    libxml2-dev \
    libxslt-dev \
    openssl-dev \
    speex-dev

WORKDIR /build
RUN wget https://github.com/karlheyes/icecast-kh/archive/refs/tags/icecast-2.4.0-kh22.tar.gz
RUN tar -xvzf icecast-2.4.0-kh22.tar.gz
RUN if test ! -d icecast-$VERSION; then mv icecast-* icecast-$VERSION; fi

WORKDIR /build/icecast-$VERSION
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var

RUN make
RUN make install DESTDIR=/build/output

FROM alpine:3.20@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5

RUN apk --no-cache add \
    libcurl \
    libogg \
    libtheora \
    libvorbis \
    libxml2 \
    libxslt \
    openssl \
    speex \
    tzdata

ENV USER=icecast
ENV TZ=UTC
RUN adduser --disabled-password --gecos '' --no-create-home $USER

COPY ./docker/icecast/config/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY ./docker/icecast/config/xml-edit.sh /usr/local/bin/xml-edit

RUN chmod +x \
    /usr/local/bin/docker-entrypoint \
    /usr/local/bin/xml-edit

COPY --from=builder /build/output /
RUN xml-edit errorlog - /etc/icecast.xml
COPY ./docker/icecast/config/icecast.xml /etc/icecast.xml
RUN xml-edit errorlog - /etc/icecast.xml

RUN mkdir -p /var/log/icecast && \
    chown $USER /etc/icecast.xml /var/log/icecast 

COPY ./docker/icecast/web /usr/share/icecast/web

EXPOSE 8000
ENTRYPOINT ["docker-entrypoint"]
USER $USER
CMD ["icecast", "-c", "/etc/icecast.xml"]