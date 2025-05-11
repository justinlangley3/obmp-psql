#!/bin/bash
set -e

echo "===> Enabling IRR"

cat > /etc/cron.d/openbmp-irr <<EOF
MAILTO=""

# Update IRR daily at 1:01 AM
1 1 * * *	root  . /usr/local/openbmp/pg_profile && /usr/local/openbmp/gen_whois_route.py -u \$PGUSER -p \$PGPASSWORD \$PGHOST >> /var/log/openbmp/irr_load.log 2>&1
EOF

# Load IRR on container start
echo "===> Loading IRR Data"
/usr/local/openbmp/gen_whois_route.py -u "$PGUSER" -p "$PGPASSWORD" "$PGHOST" >> /var/log/openbmp/irr_load.log 2>&1
echo "===> IRR Load Completed"