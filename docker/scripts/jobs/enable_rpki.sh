#!/bin/bash
set -e

echo "===> Enabling RPKI"

cat > /etc/cron.d/openbmp-rpki <<EOF
MAILTO=""

# Update RPKI every 2 hours at 31 min mark
31 */2 * * *	root  . /usr/local/openbmp/pg_profile && /usr/local/openbmp/rpki_validator.py -u $PGUSER -p $PGPASSWORD -s $OPENBMP_RPKI_URL --rpkipassword $OPENBMP_RPKI_PASSWORD --rpkiuser $OPENBMP_RPKI_USER $PGHOST >> /var/log/openbmp/cron-rpki-import.log 2>&1
EOF
