FROM debian:bullseye-slim as builder
ARG DEBIAN_FRONTEND=noninteractive
RUN set -ex \
    && apt-get update -y \
    && apt-get install -y gnupg wget \
    && wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y build-essential git cmake libssl-dev libpq-dev postgresql-server-dev-14 \
    && ln -fs /usr/share/zoneinfo/Europe/Moscow /etc/localtime \
    && apt clean -y \   
    && git clone https://github.com/yandex/odyssey.git 
WORKDIR /odyssey
RUN cmake -DPOSTGRESQL_INCLUDE_DIR=/usr/include/postgresql/14/server \
    -DPOSTGRESQL_LIBPGPORT=/usr/lib/postgresql/14/lib/libpgport.a \
    -DPOSTGRESQL_LIBRARY=/usr/lib/x86_64-linux-gnu/libpq.so.5 \
    -DPQ_LIBRARY=/usr/lib/x86_64-linux-gnu/libpq.a \
    -DCMAKE_BUILD_TYPE=Release \
    && make

FROM debian:bullseye-slim
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
    && apt-get install -y gnupg wget \
    && wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y postgresql-client \
    && ln -fs /usr/share/zoneinfo/Europe/Moscow /etc/localtime \
    && apt clean -y
COPY --from=builder /odyssey/sources/odyssey /usr/bin/
RUN addgroup appuser --gid 1001 && \
    useradd -u 1001 -g appuser -m -d /home/appuser appuser
COPY ./entrypoint.sh /home/appuser/
ENTRYPOINT ["/home/appuser/entrypoint.sh"]
USER appuser
CMD ["/usr/bin/odyssey", "/home/appuser/odyssey/odyssey.conf"]
EXPOSE 5432