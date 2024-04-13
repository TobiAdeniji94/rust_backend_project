#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v psql)" ]; then
  echo "Error: sqlx is not installed."
  exit 1
fi

if  ! [ -x "$(command -v sqlx)" ]; then
  echo "Error: sqlx is not installed."
  echo >&2 "Use:"
  echo >&2 "    cargo install --version='~0.7' sqlx-cli --no-default-features --features native-tls,postgres"
  echo >&2 "to install it."
  exit 1
fi

# check if a custom user has been set, other wise default to 'postgres'
DB_USER="${POSTGRES_USER:=postgres}"
# check if a custom password has been set, other wise default to 'password'
DB_PASSWORD="${POSTGRES_PASSWORD:=1234}"
# check if a custom DB name has been set, other wise default to 'newsletter_db'
DB_NAME="${POSTGRES_DB:=newsletter_db}"
# check if a custom port has been set, other wise default to '5432'
DB_PORT="${POSTGRES_PORT:=5432}"
# check if a custom host has been set, other wise default to 'localhost'
DB_HOST="${POSTGRES_HOST:=localhost}"

# Launch postgres using Docker
if [[ -z "${SKIP_DOCKER}" ]]
then
    RUNNING_POSTGRES_CONTAINER=$(docker ps --filter 'name=postgres' --format '{{.ID}}')
    if [[ -n $RUNNING_POSTGRES_CONTAINER ]]; then
        echo >&2 "There is a postgres container already running. Stop it with"
        echo >&2 "    docker kill $RUNNING_POSTGRES_CONTAINER"
        exit 1
    fi
    docker run \
    -e POSTGRES_USER=${DB_USER} \
    -e POSTGRES_PASSWORD=${DB_PASSWORD} \
    -e POSTGRES_DB=${DB_NAME} \
    -p "${DB_PORT}":5432 \
    -d \
    --name "postgres_$(date '+%s')" \
    postgres -N 1000
fi

# Keep pinging Postgres until it's ready to accept commands
export PGPASSWORD="${DB_PASSWORD}"
until psql -h "localhost" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
  >&2 echo "Postgres is still unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT} - running migrations now!"

export DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"