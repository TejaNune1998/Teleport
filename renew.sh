#!/bin/bash
set -e

# Run certbot renew non-interactively
RENEWED=0

docker run --rm --name certbot \
  --dns 1.1.1.1 --dns 8.8.8.8 \
  -v /path/to/teleport/data/teleport/certs:/etc/letsencrypt \
  -v /path/to/teleport/data/certbot/secrets/cloudflare.ini:/cloudflare.ini:ro \
  certbot/dns-cloudflare:latest renew \
  --no-random-sleep-on-renew \
  --deploy-hook "touch /etc/letsencrypt/renewed.flag"

# Check if the renew hook created the flag
if [ -f /path/to/teleport/data/teleport/certs/renewed.flag ]; then
  echo "Certificate was renewed. Restarting Teleport..."
  rm -f /opt/docker_files/teleport/data/teleport/certs/renewed.flag
  docker restart teleport
else
  echo "Certificates not due for renewal. Teleport was not restarted."
fi

find /path/to/teleport/logs -type f -mtime +30 -exec rm -f {} +
