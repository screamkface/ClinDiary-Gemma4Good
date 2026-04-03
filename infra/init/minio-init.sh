#!/bin/sh
set -eu

until mc alias set local http://minio:9000 minioadmin minioadmin; do
  sleep 2
done

mc mb -p local/clindiary || true
mc anonymous set private local/clindiary || true

