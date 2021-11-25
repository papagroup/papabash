#!/bin/sh

set -e

ZONE_ID=bc196f152c8ab4a696bed018568c95ce
API_TOKEN=sx3GbvanWHPOmpvwGIYWRD7FmgCijBkJKEHGHL7r
DNS_RECORD_ID=372e67954025e0ba6aaa6d586b9e0b59
RECORD_ID=079fbae21da71da37cc6c5290767405b

NEW_IP=`sudo bash /.scripts/get_ip.sh`

# For global key...
#X_AUTH_KEY=92efa3145d9a738142a7e74c23cf2f2e
#-H "X-Auth-Email: user@example.com" \
#-H "X-Auth-Key: $X_AUTH_KEY" \

# curl -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=100" \
#      -H "Authorization: Bearer $API_TOKEN" \
#      -H "Content-Type: application/json" | \
#     python3 -c "import sys, json; print(list(filter(lambda x:x['name']=='*.console2.papagroup.net' or x['name']=='console2.papagroup.net',json.load(sys.stdin))))"

curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"console2.papagroup.net\",\"content\":\"$NEW_IP\",\"ttl\":120,\"proxied\":false}"

# curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/4fcf31768b42f292929cdd60f411ab7f" \
#     -H "Authorization: Bearer $API_TOKEN" \
#     -H "Content-Type: application/json" \
#     --data "{\"type\":\"A\",\"name\":\"*.console2.papagroup.net\",\"content\":\"$NEW_IP\",\"ttl\":120,\"proxied\":false}"

echo ""
echo "Done."
echo ""