#!/bin/bash
# SentinelWatch Diagnostics — run on your server
echo "============================================"
echo " SentinelWatch Full Diagnostic Report"
echo " $(date)"
echo "============================================"

echo ""
echo "--- PHP VERSION ---"
php -v 2>/dev/null | head -1

echo ""
echo "--- APACHE STATUS ---"
systemctl is-active apache2

echo ""
echo "--- MYSQL STATUS ---"
systemctl is-active mysql

echo ""
echo "--- WAZUH SERVICES ---"
systemctl is-active wazuh-manager
systemctl is-active wazuh-agent 2>/dev/null || echo "no agent on this host"
systemctl is-active wazuh-indexer
systemctl is-active wazuh-dashboard

echo ""
echo "--- WAZUH ALERTS FILE (last 5 JSON lines) ---"
sudo tail -5 /var/ossec/logs/alerts/alerts.json 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- ACTIVE RESPONSE LOG (last 10) ---"
sudo tail -10 /var/ossec/logs/active-responses.log 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- DASHBOARD FILES ---"
ls -la /var/www/html/wazuh-dashboard/ 2>/dev/null || echo "DIR NOT FOUND"

echo ""
echo "--- MYSQL: tables + row counts ---"
mysql -u wazuh_user -pWazuhDB@2024! wazuh_dashboard 2>/dev/null <<SQL
SELECT 'brute_force_alerts' AS tbl, COUNT(*) AS rows FROM brute_force_alerts
UNION SELECT 'blocked_ips', COUNT(*) FROM blocked_ips
UNION SELECT 'dashboard_settings', COUNT(*) FROM dashboard_settings
UNION SELECT 'slack_log', COUNT(*) FROM slack_log;
SQL

echo ""
echo "--- MYSQL: last 3 alerts ---"
mysql -u wazuh_user -pWazuhDB@2024! wazuh_dashboard 2>/dev/null -e \
  "SELECT id,src_ip,rule_id,rule_level,description,created_at FROM brute_force_alerts ORDER BY id DESC LIMIT 3;"

echo ""
echo "--- MYSQL: blocked_ips ---"
mysql -u wazuh_user -pWazuhDB@2024! wazuh_dashboard 2>/dev/null -e \
  "SELECT ip_address,is_active,blocked_at,reason FROM blocked_ips ORDER BY blocked_at DESC LIMIT 5;"

echo ""
echo "--- MYSQL: settings ---"
mysql -u wazuh_user -pWazuhDB@2024! wazuh_dashboard 2>/dev/null -e \
  "SELECT setting_key, setting_value FROM dashboard_settings;"

echo ""
echo "--- CRON JOBS (root) ---"
sudo crontab -l 2>/dev/null || echo "no root crontab"
crontab -l 2>/dev/null || echo "no user crontab"

echo ""
echo "--- CRON LOG (last 20) ---"
sudo tail -20 /var/log/wazuh-cron.log 2>/dev/null || echo "NO CRON LOG"

echo ""
echo "--- APACHE ERROR LOG (last 20) ---"
sudo tail -20 /var/log/apache2/error.log 2>/dev/null

echo ""
echo "--- WAZUH OSSEC LOG (last 20) ---"
sudo tail -20 /var/ossec/logs/ossec.log 2>/dev/null

echo ""
echo "--- WAZUH API TEST ---"
TOKEN=$(curl -sk -u wazuh:$(sudo grep -r 'password' /var/ossec/etc/api/configuration/security/ 2>/dev/null | head -1 | awk '{print $NF}') \
  -X POST "https://127.0.0.1:55000/security/user/authenticate" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('token','FAIL'))" 2>/dev/null)
echo "API Token (first 30 chars): ${TOKEN:0:30}..."

echo ""
echo "--- IPTABLES BLOCKED IPs ---"
sudo iptables -L INPUT -n 2>/dev/null | grep DROP | head -20

echo ""
echo "=== DONE ==="
