FROM valkey/valkey-bundle:9.1 as build

RUN apt update && \
    apt install -y git make gcc;

WORKDIR /opt
RUN git clone https://github.com/valkey-io/valkey
WORKDIR /opt/valkey/tests/modules
RUN make auth.so

FROM valkey/valkey-bundle:9.1
COPY --from=build /opt/valkey/tests/modules/auth.so /usr/lib/valkey/libauth.so
RUN rm /usr/lib/valkey/libsearch.so; \
    rm /usr/lib/valkey/libvalkey_bloom.so; \
    rm /usr/lib/valkey/libjson.so;
ENTRYPOINT []
CMD  ["valkey-server","--enable-module-command","local"]