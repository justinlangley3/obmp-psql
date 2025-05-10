#!/bin/bash
set -e

echo "===> Configuring cron jobs"

cat > /etc/cron.d/openbmp <<EOF
MAILTO=""

# Update ASN info
6 */2 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/gen_whois.lock /usr/local/openbmp/gen_whois_asn.py -u $PGUSER -p $PGPASSWORD $PGHOST >> /var/log/openbmp/asn_load.log 2>&1
5 1,12 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/peeringdb.lock /usr/local/openbmp/peeringdb.py >> /var/log/openbmp/cron-peeringdb.log 2>&1

# Update aggregation table stats
*/5 * * * *  root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_chg_stats.lock psql -c "select update_chg_stats('5 minute')" >> /var/log/openbmp/cron-update_chg_stats.log 2>&1
*/5 * * * *  root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_l3vpn_chg_stats.lock psql -c "select update_l3vpn_chg_stats('5 minute')" >> /var/log/openbmp/cron-update_l3vpn_chg_stats.log 2>&1

# Update peer rib counts
*/15 * * * *	root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_peer_rib_counts.lock psql -c "select update_peer_rib_counts()"  >> /var/log/openbmp/cron-update_peer_rib_counts.log 2>&1

# Update peer update counts
*/30 * * * *    root   . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_peer_counts.lock psql -c "select update_peer_update_counts(1800)"  >> /var/log/openbmp/cron-update_peer_counts.log 2>&1

# Update global rib
*/5 * * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/global_ip_rib.lock psql -c "select update_global_ip_rib();" >> /var/log/openbmp/cron-update_global_ip_rib.log 2>&1
5 */4 * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/global_ip_rib.lock psql -c "select purge_global_ip_rib('6 hour');" >> /var/log/openbmp/cron-purge_global_ip_rib.log 2>&1

# Update origin stats
21 * * * *	root  . /usr/local/openbmp/pg_profile && flock -n /tmp/locks/update_origin_stats.lock psql -c "select update_origin_stats('1 hour');" >> /var/log/openbmp/cron-update_origin_stats.log 2>&1

EOF

cat > /etc/cron.d/logrotate <<EOF
# Rotate logs every day
0 0 * * *	root  /usr/sbin/logrotate -f /etc/logrotate.conf
EOF