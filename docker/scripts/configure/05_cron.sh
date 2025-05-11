#!/bin/bash
set -e

echo "===> Configuring cron jobs"

cat > /etc/cron.d/openbmp <<EOF
MAILTO=""

# Update ASN info
6 */2 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/gen_whois.lock /usr/local/openbmp/gen_whois_asn.py -u $PGUSER -p $PGPASSWORD $PGHOST >> /var/log/openbmp/asn_load.log 2>&1
5 1,12 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/peeringdb.lock /usr/local/openbmp/peeringdb.py >> /var/log/openbmp/cron-peeringdb.log 2>&1

# Update aggregation table stats
*/5 * * * *  root   /usr/local/openbmp/jobs/update_chg_stats.sh > /dev/null 2>&1
*/5 * * * *  root   /usr/local/openbmp/jobs/update_l3vpn_chg_stats.sh > /dev/null 2>&1

# Update peer rib counts
*/15 * * * *	root   /usr/local/openbmp/jobs/update_peer_rib_counts.sh > /dev/null 2>&1

# Update peer update counts
*/30 * * * *    root   /usr/local/openbmp/jobs/update_peer_update_counts.sh > /dev/null 2>&1

# Update global rib
*/5 * * * *	root  /usr/local/openbmp/jobs/update_global_rib.sh > /dev/null 2>&1
5 */4 * * *	root  /usr/local/openbmp/jobs/purge_global_rib.sh > /dev/null 2>&1

# Update origin stats
21 * * * *	root  /usr/local/openbmp/jobs/update_origin_stats.sh > /dev/null 2>&1

EOF

cat > /etc/cron.d/logrotate <<EOF
# Rotate logs every day
0 0 * * *	root  /usr/sbin/logrotate -f /etc/logrotate.conf > /dev/null 2>&1
EOF