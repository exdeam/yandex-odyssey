#!/usr/bin/env bash
set -e
INTERNALVAR_LOG=no
if [ -n "${ODYSSEY_DEBUG}" ]; then
INTERNALVAR_LOG=yes
fi
mkdir -p /home/appuser/odyssey/
IFS=' '
# create list of databases and owners from ${POSTGRES_HOST2_DB_LIST}
read -a arrDBs <<< "${POSTGRES_HOST2_DB_LIST}"
echo ${arrDBs[@]}
for i in "${arrDBs[@]}"; do
PGPASSWORD="${ODYSSEY_AUTH_PASSWORD:-postgres}" psql -h ${POSTGRES_HOST2} -p ${POSTGRES_PORT2} -d postgres -U ${ODYSSEY_AUTH_USER} -c "SELECT d.datname as "Name", pg_catalog.pg_get_userbyid(d.datdba) as "Owner" FROM pg_catalog.pg_database d WHERE d.datname LIKE '$i' ORDER BY 1" | awk '{print $1,$3}' | tail -n +3 | head -n -2 >> /home/appuser/odyssey/psql02_list.txt
done
# create list of databases and owners from ${POSTGRES_HOST3_DB_LIST}
read -a arrDBs <<< "${POSTGRES_HOST3_DB_LIST}"
echo ${arrDBs[@]}
for i in "${arrDBs[@]}"; do
PGPASSWORD="${ODYSSEY_AUTH_PASSWORD:-postgres}" psql -h ${POSTGRES_HOST3} -p ${POSTGRES_PORT3} -d postgres -U ${ODYSSEY_AUTH_USER} -c "SELECT d.datname as "Name", pg_catalog.pg_get_userbyid(d.datdba) as "Owner" FROM pg_catalog.pg_database d WHERE d.datname LIKE '$i' ORDER BY 1" | awk '{print $1,$3}' | tail -n +3 | head -n -2 >> /home/appuser/odyssey/psql03_list.txt
done
cat > /home/appuser/odyssey/odyssey.conf << EOF
daemonize no
unix_socket_dir "/tmp"
unix_socket_mode "0644"
log_format "%p %t %l [%i %s] (%c) %m\n"
log_to_stdout yes
log_syslog no
log_debug ${INTERNALVAR_LOG}
log_config ${INTERNALVAR_LOG}
log_session yes
log_query ${INTERNALVAR_LOG}
log_stats yes
workers 1
resolvers 1
readahead ${ODYSSEY_READAHEAD:-8192}
cache_coroutine ${ODYSSEY_CACHE_COROUTINE:-0}
coroutine_stack_size ${ODYSSEY_STACK_SIZE:-128}
nodelay yes
keepalive ${ODYSSEY_KEEPALIVE:-10}
#include "/home/appuser/odyssey/add.conf"
listen {
host "*"
port 5432
backlog 128
}
storage "psql01" {
type "remote"
host "${POSTGRES_HOST1:-localhost}"
port ${POSTGRES_PORT1:-5432}
}
storage "psql02" {
type "remote"
host "${POSTGRES_HOST2:-localhost}"
port ${POSTGRES_PORT2:-5432}
}
storage "psql03" {
type "remote"
host "${POSTGRES_HOST3:-localhost}"
port ${POSTGRES_PORT3:-5432}
}
storage "local" {
type "local"
}
database default {
  user default {
  authentication "md5"
  password_passthrough yes
  auth_query "SELECT usename, passwd FROM pg_shadow WHERE usename=\$1"
  auth_query_db "auth"
  auth_query_user "auth"
  storage "psql01"
  pool "${ODYSSEY_POOL_TYPE:-transaction}"
  pool_size ${ODYSSEY_POOL_SIZE:-32}
  pool_timeout ${ODYSSEY_POOL_TIMEOUT:-0}
  pool_ttl ${ODYSSEY_POOL_TTL:-5}
  pool_discard ${ODYSSEY_POOL_DISCARD:-yes}
  pool_cancel ${ODYSSEY_POOL_CANCEL:-yes}
  pool_rollback ${ODYSSEY_POOL_ROLLBACK:-yes}
  client_fwd_error yes
  }
}
database "auth" {
  user "auth" {
  authentication "none"
  storage "psql01"
  storage_db "postgres"
  storage_user "${ODYSSEY_AUTH_USER:-postgres}"
  storage_password "${ODYSSEY_AUTH_PASSWORD:-postgres}"
  pool "transaction"
  pool_routing "internal"
  pool_size 0
  pool_timeout 0
  pool_ttl ${ODYSSEY_POOL_TTL:-5}
  pool_discard no
  pool_cancel no
  pool_rollback no
  }
}
database "auth2" {
  user "auth2" {
  authentication "none"
  storage "psql02"
  storage_db "postgres"
  storage_user "${ODYSSEY_AUTH_USER:-postgres}"
  storage_password "${ODYSSEY_AUTH_PASSWORD:-postgres}"
  pool "transaction"
  pool_routing "internal"
  pool_size 0
  pool_timeout 0
  pool_ttl ${ODYSSEY_POOL_TTL:-5}
  pool_discard no
  pool_cancel no
  pool_rollback no
  }
}
database "auth3" {
  user "auth3" {
  authentication "none"
  storage "psql03"
  storage_db "postgres"
  storage_user "${ODYSSEY_AUTH_USER:-postgres}"
  storage_password "${ODYSSEY_AUTH_PASSWORD:-postgres}"
  pool "transaction"
  pool_routing "internal"
  pool_size 0
  pool_timeout 0
  pool_ttl ${ODYSSEY_POOL_TTL:-5}
  pool_discard no
  pool_cancel no
  pool_rollback no
  }
}
database "console" {
  user default {
  authentication "none"
  pool "${ODYSSEY_POOL_TYPE:-transaction}"
  storage "local"
  }
}
database "console" {
  user "${ODYSSEY_MONITORING_USER:-monitor}" {
  authentication "md5"
  password "${ODYSSEY_MONITORING_PASSWORD:-monitor}"
  pool "${ODYSSEY_POOL_TYPE:-transaction}"
  storage "local"
  }
}
EOF
# create psql03.sh
cat > /home/appuser/odyssey/psql03.sh <<EOF
#!/bin/bash
mapfile arrList < /home/appuser/odyssey/psql03_list.txt
for i in "\${arrList[@]}"; do
  DB_NAME=\$(echo \$i | awk '{print \$1}')
  DB_OWNER=\$(echo \$i | awk '{print \$2}')
  if [ "\$DB_NAME" != "postgres" ] && [ "\$DB_OWNER" != "postgres" ]; then
  cat >> /home/appuser/odyssey/odyssey.conf <<INTEOF
  database "\${DB_NAME}" {
    user default {
    authentication "md5"
    password_passthrough yes
    auth_query "SELECT usename, passwd FROM pg_shadow WHERE usename=$1"
    auth_query_db "auth3"
    auth_query_user "auth3"
    storage "psql03"
    pool "${ODYSSEY_POOL_TYPE:-transaction}"
    pool_size ${ODYSSEY_POOL_SIZE:-32}
    pool_timeout ${ODYSSEY_POOL_TIMEOUT:-0}
    pool_ttl ${ODYSSEY_POOL_TTL:-5}
    pool_discard ${ODYSSEY_POOL_DISCARD:-yes}
    pool_cancel ${ODYSSEY_POOL_CANCEL:-yes}
    pool_rollback ${ODYSSEY_POOL_ROLLBACK:-yes}
    client_fwd_error yes
    }
  }
INTEOF
  else
    echo "postgres db ignored"
  fi
done
EOF
sed -i 's|usename=|usename=\\\$1|g' /home/appuser/odyssey/psql03.sh
chmod +x /home/appuser/odyssey/psql03.sh
# add to odyssey.con routing blocks of code for database and users from psql03 cluster
/bin/bash /home/appuser/odyssey/psql03.sh

# create psql02.sh
cat > /home/appuser/odyssey/psql02.sh <<EOF
#!/bin/bash
mapfile arrList < /home/appuser/odyssey/psql02_list.txt
for i in "\${arrList[@]}"; do
  DB_NAME=\$(echo \$i | awk '{print \$1}')
  DB_OWNER=\$(echo \$i | awk '{print \$2}')
  if [ "\$DB_NAME" != "postgres" ] && [ "\$DB_OWNER" != "postgres" ]; then
  cat >> /home/appuser/odyssey/odyssey.conf <<INTEOF
  database "\${DB_NAME}" {
    user default {
    authentication "md5"
    password_passthrough yes
    auth_query "SELECT usename, passwd FROM pg_shadow WHERE usename=$1"
    auth_query_db "auth2"
    auth_query_user "auth2"
    storage "psql02"
    pool "${ODYSSEY_POOL_TYPE:-transaction}"
    pool_size ${ODYSSEY_POOL_SIZE:-32}
    pool_timeout ${ODYSSEY_POOL_TIMEOUT:-0}
    pool_ttl ${ODYSSEY_POOL_TTL:-5}
    pool_discard ${ODYSSEY_POOL_DISCARD:-yes}
    pool_cancel ${ODYSSEY_POOL_CANCEL:-yes}
    pool_rollback ${ODYSSEY_POOL_ROLLBACK:-yes}
    client_fwd_error yes
    }
  }
INTEOF
  else
    echo "postgres db ignored"
  fi
done
EOF
sed -i 's|usename=|usename=\\\$1|g' /home/appuser/odyssey/psql02.sh
chmod +x /home/appuser/odyssey/psql02.sh
# add to odyssey.con routing blocks of code for database and users from psql02 cluster
/bin/bash /home/appuser/odyssey/psql02.sh
# all missmatched dbs and users go to default route
sed -i 's|usename=$1/usr/bin/odyssey|usename=$1|g' /home/appuser/odyssey/odyssey.conf
#chmod 644 ~/odyssey
exec "$@"
