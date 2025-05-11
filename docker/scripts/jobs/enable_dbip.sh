#!/bin/bash
set -e

echo "===> Enabling DB-IP Import"

cat > /etc/cron.d/openbmp-dbip <<EOF
MAILTO=""

# Update DB-IP every Saturday between minute 1 and 59 after 2 AM
$(( RANDOM % 59 + 1 )) 2 * * 6	root  /usr/local/openbmp/db-ip-import.sh >> /var/log/openbmp/cron-dbip-import.log 2>&1
EOF

# Load DB-IP on container start
echo "===> Running DB-IP Import Immediately"
/usr/local/openbmp/db-ip-import.sh >> /var/log/openbmp/cron-dbip-import.log 2>&1
echo "===> DB-IP Import Completed"
