FROM savonet/liquidsoap-alpine:v2.3.0

ARG USER_UID

ARG USER_GID

USER root

ENV TZ=UTC

RUN addgroup -g "${USER_GID}" radio && adduser -u "${USER_UID}" -G radio -S radio

RUN   apk add --no-cache --allow-untrusted \
      ffmpeg \
      python3 \
      py3-mutagen \
      tzdata \
      curl \ 
      bash \
      ;

COPY ./docker/liquidsoap/rootfs /

RUN chmod +x /usr/bin/entrypoint

RUN chown -R radio:radio /home/radio

USER radio

ENTRYPOINT [ "entrypoint" ]
