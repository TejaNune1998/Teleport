#!/bin/bash
set -e

# Run certbot renew non-interactively
# Note: --deploy-hook runs ONLY if a certificate was actually renewed
RENEWED=0

docker run --rm --name certbot \
  --dns 1.1.1.1 --dns 8.8.8.8 \
  -v /opt/docker_files/teleport/data/teleport/certs:/etc/letsencrypt \
  -v /opt/docker_files/teleport/data/certbot/secrets/cloudflare.ini:/cloudflare.ini:ro \
  certbot/dns-cloudflare:latest renew \
  --no-random-sleep-on-renew \
  --deploy-hook "touch /etc/letsencrypt/renewed.flag"

# Check if the renew hook created the flag
if [ -f /opt/docker_files/teleport/data/teleport/certs/renewed.flag ]; then
  echo "Certificate was renewed. Restarting Teleport..."
  rm -f /opt/docker_files/teleport/data/teleport/certs/renewed.flag
  docker restart teleport
else
  echo "Certificates not due for renewal. Teleport was not restarted."
fi

find /opt/docker_files/teleport/logs -type f -mtime +30 -exec rm -f {} +
