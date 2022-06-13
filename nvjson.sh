#!/bin/bash
#############################################################################
# centmin mod nginx vhost site generator that takes a JSON config file to
# create a centmin mod nginx vhost site using the existing nv command line
# tool with additional setup functions that expand functionality and allow
# users to create a more complete nginx vhost site configuration in an
# unattended manner
#############################################################################
# run nvjson.sh script passing the desired vhost-config.json file on the 
# command line
#
# usage:
#
# nvjson.sh vhost-config.json
#############################################################################
# Notes:
#
# currently the only JSON config parameters not adjustable are the following:
#
# webroot - which points to /home/nginx/domains/domain.com/public
# index - which points to /home/nginx/domains/domain.com/public/index.html
#
# eventually they will be adjustable just not right now
#############################################################################
# {
#   "domain": "domain.com",
#   "domain-www": "www.domain.com",
#   "domain-preferred": "www.domain.com",
#   "domain-parked1": "sub1.domain.com",
#   "domain-parked2": "sub2.domain.com",
#   "domain-parked3": "sub3.domain.com",
#   "email": "email@domain",
#   "https": "yes",
#   "origin-sslcert": "letsencrypt",
#   "cloudflare": "yes",
#   "cloudflare-accountid": "aabbcc",
#   "cloudflare-zoneid": "zoneid",
#   "cloudflare-api-token": "xxxyyyzzz",
#   "cloudflare-min-tls": "1.2",
#   "cloudflare-tiered-cache": "yes",
#   "cloudflare-cache-reserve": "yes",
#   "cloudflare-crawler-hints": "yes",
#   "cloudflare-respect-origin-headers": "yes",
#   "type": "site",
#   "mysqldb1": "db1",
#   "mysqluser1": "dbuser1",
#   "mysqlpass1": "dbpass1",
#   "mysqldb2": "db2",
#   "mysqluser2": "dbuser2",
#   "mysqlpass2": "dbpass2",
#   "mysqldb3": "db3",
#   "mysqluser3": "dbuser3",
#   "mysqlpass3": "dbpass3",
#   "mysqldb4": "db4",
#   "mysqluser4": "dbuser4",
#   "mysqlpass4": "dbpass4",
#   "mysqldb5": "db5",
#   "mysqluser5": "dbuser5",
#   "mysqlpass5": "dbpass5",
#   "webroot": "/home/nginx/domains/domain.com/public",
#   "index": "/home/nginx/domains/domain.com/public/index.html",
#   "robotsfile": "/path/to/robots.txt",
#   "cronjobfile": "/path/to/cronjobfile.txt"
# }
#############################################################################
VER='0.1'
DT=$(date +"%d%m%y-%H%M%S")
DEBUG_MODE='y'

#############################################################################
# Cloudflare settings
IS_PROXIED='y'
CF_ENABLE_CACHE_RESERVE='n'
CF_ENABLE_CRAWLER_HINTS='n'

# Cloudflare DNS API settings
WORKDIR='/etc/cfapi'
BIND_ZONE_BACKUPDIR="$WORKDIR/backup-zone-bind"

# Cloudflare API
endpoint=https://api.cloudflare.com/client/v4/
#############################################################################
# Other Settings
CURL_AGENT="$(curl -V 2>&1 | head -n 1 |  awk '{print $1"/"$2}') nvjson.sh $VER"
#############################################################################
if [ ! -d "$BIND_ZONE_BACKUPDIR" ]; then
  mkdir -p "$BIND_ZONE_BACKUPDIR"
fi
if [ -f "$WORKDIR/nvjson.ini" ]; then
  source "$WORKDIR/nvjson.ini"
fi

backup_zone_bind() {
  domain="$1"
  token="$cloudflare_api_token"
  curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/dns_records/export" -H "Content-Type:application/json" -H "Authorization: Bearer $token" > "$BIND_ZONE_BACKUPDIR/cf-zone-bind-export-$domain-$DT.txt"
  echo
  echo "---------------------------------------------------------------------"
  echo "backed up Cloudflare Zone Bind File at:"
  echo "---------------------------------------------------------------------"
  echo "$BIND_ZONE_BACKUPDIR/cf-zone-bind-export-$domain-$DT.txt"
  echo "---------------------------------------------------------------------"
  echo
}

parse_file() {
  file="$1"
  file_parsed=$(egrep -v '^#|^\/\*|^\/' "$file" | jq -r '.data[]')
  domain=$(echo "$file_parsed" | jq -r '."domain"')
  domain_www=$(echo "$file_parsed" | jq -r '."domain-www"')
  domain_preferred=$(echo "$file_parsed" | jq -r '."domain-preferred"')
  domain_parked1=$(echo "$file_parsed" | jq -r '."domain-parked1"')
  domain_parked2=$(echo "$file_parsed" | jq -r '."domain-parked2"')
  domain_parked3=$(echo "$file_parsed" | jq -r '."domain-parked3"')
  email=$(echo "$file_parsed" | jq -r '."email"')
  https=$(echo "$file_parsed" | jq -r '."https"')
  origin_sslcert=$(echo "$file_parsed" | jq -r '."origin-sslcert"')
  cloudflare=$(echo "$file_parsed" | jq -r '."cloudflare"')
  cloudflare_accountid=$(echo "$file_parsed" | jq -r '."cloudflare-accountid"')
  # CF_Account_ID=$(echo "$file_parsed" | jq -r '."cloudflare-accountid"')
  cloudflare_zoneid=$(echo "$file_parsed" | jq -r '."cloudflare-zoneid"')
  # CF_ZONEID=$(echo "$file_parsed" | jq -r '."cloudflare-zoneid"')
  cloudflare_api_token=$(echo "$file_parsed" | jq -r '."cloudflare-api-token"')
  # CF_Token=$(echo "$file_parsed" | jq -r '."cloudflare-api-token"')
  cloudflare_min_tls=$(echo "$file_parsed" | jq -r '."cloudflare-min-tls"')
  cloudflare_tiered_cache=$(echo "$file_parsed" | jq -r '."cloudflare-tiered-cache"')
  cloudflare_cache_reserve=$(echo "$file_parsed" | jq -r '."cloudflare-cache-reserve"')
  cloudflare_crawler_hints=$(echo "$file_parsed" | jq -r '."cloudflare-crawler-hints"')
  cloudflare_respect_origin_headers=$(echo "$file_parsed" | jq -r '."cloudflare-respect-origin-headers"')
  type=$(echo "$file_parsed" | jq -r '."type"')
  mysqldb1=$(echo "$file_parsed" | jq -r '."mysqldb1"')
  mysqluser1=$(echo "$file_parsed" | jq -r '."mysqluser1"')
  mysqlpass1=$(echo "$file_parsed" | jq -r '."mysqlpass1"')
  mysqldb2=$(echo "$file_parsed" | jq -r '."mysqldb2"')
  mysqluser2=$(echo "$file_parsed" | jq -r '."mysqluser2"')
  mysqlpass2=$(echo "$file_parsed" | jq -r '."mysqlpass2"')
  mysqldb3=$(echo "$file_parsed" | jq -r '."mysqldb3"')
  mysqluser3=$(echo "$file_parsed" | jq -r '."mysqluser3"')
  mysqlpass3=$(echo "$file_parsed" | jq -r '."mysqlpass3"')
  mysqldb4=$(echo "$file_parsed" | jq -r '."mysqldb4"')
  mysqluser4=$(echo "$file_parsed" | jq -r '."mysqluser4"')
  mysqlpass4=$(echo "$file_parsed" | jq -r '."mysqlpass4"')
  mysqldb5=$(echo "$file_parsed" | jq -r '."mysqldb5"')
  mysqluser5=$(echo "$file_parsed" | jq -r '."mysqluser5"')
  mysqlpass5=$(echo "$file_parsed" | jq -r '."mysqlpass5"')
  webroot=$(echo "$file_parsed" | jq -r '."webroot"')
  index=$(echo "$file_parsed" | jq -r '."index"')
  robotsfile=$(echo "$file_parsed" | jq -r '."robotsfile"')
  cronjobfile=$(echo "$file_parsed" | jq -r '."cronjobfile"')
  cfplan=$(curl -sX GET -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$cloudflare_zoneid" | jq -r '.result.plan.legacy_id')
  if [[ "$DEBUG_MODE" = [yY] ]]; then
    echo
    echo "---------------------------------------------------------------------"
    echo "Debug Mode Output:"
    echo "---------------------------------------------------------------------"
    echo "parsed vhost config file output"
    echo "$file_parsed"
    echo "---------------------------------------------------------------------"
    echo "Variable checks:"
    echo "---------------------------------------------------------------------"
    echo "cfplan=$cfplan"
    echo "domain=$domain"
    echo "domain_www=$domain_www"
    echo "domain_preferred=$domain-preferred"
    echo "domain_parked1=$domain-parked1"
    echo "domain_parked2=$domain-parked2"
    echo "domain_parked3=$domain-parked3"
    echo "email=$email"
    echo "https=$https"
    echo "origin_sslcert=$origin-sslcert"
    echo "cloudflare=$cloudflare"
    echo "cloudflare_accountid=$cloudflare-accountid"
    echo "cloudflare_zoneid=$cloudflare-zoneid"
    echo "cloudflare_api_token=$cloudflare-api-token"
    echo "cloudflare_min_tls=$cloudflare-min-tls"
    echo "cloudflare_tiered_cache=$cloudflare-tiered-cache"
    echo "cloudflare_cache_reserve=$cloudflare-cache-reserve"
    echo "cloudflare_crawler_hints=$cloudflare-crawler-hints"
    echo "cloudflare_respect_origin_headers=$cloudflare-respect-origin-headers"
    echo "type=$type"
    echo "mysqldb1=$mysqldb1"
    echo "mysqluser1=$mysqluser1"
    echo "mysqlpass1=$mysqlpass1"
    echo "mysqldb2=$mysqldb2"
    echo "mysqluser2=$mysqluser2"
    echo "mysqlpass2=$mysqlpass2"
    echo "mysqldb3=$mysqldb3"
    echo "mysqluser3=$mysqluser3"
    echo "mysqlpass3=$mysqlpass3"
    echo "mysqldb4=$mysqldb4"
    echo "mysqluser4=$mysqluser4"
    echo "mysqlpass4=$mysqlpass4"
    echo "mysqldb5=$mysqldb5"
    echo "mysqluser5=$mysqluser5"
    echo "mysqlpass5=$mysqlpass5"
    echo "webroot=$webroot"
    echo "index=$index"
    echo "robotsfile=$robotsfile"
    echo "cronjobfile=$cronjobfile"
    echo "---------------------------------------------------------------------"
  fi
}

create_vhost() {
  file="$1"
  parse_file "$file"
  echo
  echo "---------------------------------------------------------------------"
  echo "Check Cloudflare API Token For: $domain"
  echo "---------------------------------------------------------------------"
  echo
  echo "curl -X GET \"https://api.cloudflare.com/client/v4/user/tokens/verify\" \\"
  echo "     -H \"Authorization: Bearer $cloudflare_api_token\" \\"
  echo "     -H \"Content-Type:application/json\""
  curl -sX GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type:application/json" | jq -r
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Cloudflare DNS API Token For: $domain (CF $cfplan plan)"
  echo "---------------------------------------------------------------------"
  echo
  echo "CF_DNSAPI_GLOBAL='y'"
  echo "CF_Token=\"$cloudflare_api_token\""
  echo "CF_Account_ID=\"$cloudflare_accountid\""
  echo
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Cloudflare DNS A For: $domain (CF $cfplan plan)"
  echo "---------------------------------------------------------------------"
  SERVERIP_A=$(curl -4s -A "$CURL_AGENT" https://geoip.centminmod.com/v3 | jq -r '.ip')
  SERVERIP_AAAA=$(curl -6s -A "$CURL_AGENT" https://geoip.centminmod.com/v3 | jq -r '.ip')
  DNS_CONTENT_A="$SERVERIP_A"
  DNS_CONTENT_AAAA="$SERVERIP_AAAA"
  if [[ "$IS_PROXIED" = [yY] ]]; then
    PROXY_OPT=true
  else
    PROXY_OPT=false
  fi
  backup_zone_bind "$domain"
  # create A record
  if [[ "$DNS_CONTENT_A" && "$domain" ]]; then
    RECORD_TYPE="A"
    DNS_RECORD_NAME="$domain"
    dns_mode=create
    create_dns_a=$(curl -sX POST "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/dns_records" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
      --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_A $DNS_CONTENT_A --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_A\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
    check_create_dns_a=$(echo "$create_dns_a" | jq -r '.success')
    check_create_dns_a_errcode=$(echo "$create_dns_a" | jq -r '.errors[] | .code')
    if [[ "$check_create_dns_a_errcode" = '81057' ]]; then
      dns_mode=update
      # update not create DNS record
      endpoint_target="zones/${cloudflare_zoneid}/dns_records?type=${RECORD_TYPE}&name=${DNS_RECORD_NAME}&page=1&per_page=100&order=type&direction=desc&match=all"
      dnsrecid=$(curl -sX GET "https://api.cloudflare.com/client/v4/${endpoint_target}" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" | jq -r '.result[] | .id')
      create_dns_a=$(curl -sX PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/dns_records/$dnsrecid" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
      --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_A $DNS_CONTENT_A --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_A\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
      check_create_dns_a=$(echo "$create_dns_a" | jq -r '.success')
    fi
    if [[ "$check_create_dns_a" = 'false' && "$check_create_dns_a_errcode" != '81057' ]]; then
      echo "error: $dns_mode DNS $RECORD_TYPE record failed"
      echo "$create_dns_a" | jq -r '.errors[] | "code: \(.code) message: \(.message)"'
    elif [[ "$check_create_dns_a" = 'true' ]]; then
      echo "success: $dns_mode DNS $RECORD_TYPE record succeeded"
      echo "$create_dns_a" | jq -r
    fi
  fi
  # create AAAA record
  if {[ "$DNS_CONTENT_AAAA" && "$domain" ]}; then
    RECORD_TYPE="AAAA"
    DNS_RECORD_NAME="$domain"
    create_dns_aaaa=$(curl -sX POST "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/dns_records" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
      --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_AAAA $DNS_CONTENT_AAAA --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_AAAA\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
    check_create_dns_aaaa=$(echo "$create_dns_aaaa" | jq -r '.success')
    check_create_dns_aaaa_errcode=$(echo "$create_dns_aaaa" | jq -r '.errors[] | .code')
    if [[ "$check_create_dns_a_errcode" = '81057' ]]; then
      dns_mode=update
      # update not create DNS record
      endpoint_target="zones/${cloudflare_zoneid}/dns_records?type=${RECORD_TYPE}&name=${DNS_RECORD_NAME}&page=1&per_page=100&order=type&direction=desc&match=all"
      dnsrecid=$(curl -sX GET "https://api.cloudflare.com/client/v4/${endpoint_target}" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" | jq -r '.result[] | .id')
      create_dns_aaaa=$(curl -sX PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/dns_records/$dnsrecid" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
      --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_AAAA $DNS_CONTENT_AAAA --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_AAAA\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
      check_create_dns_aaaa=$(echo "$create_dns_aaaa" | jq -r '.success')
    fi
    if [[ "$check_create_dns_aaaa" = 'false' && "$check_create_dns_a_errcode" != '81057' ]]; then
      echo "error: $dns_mode DNS $RECORD_TYPE record failed"
      echo "$create_dns_aaaa" | jq -r '.errors[] | "code: \(.code) message: \(.message)"'
    elif [[ "$check_create_dns_aaaa" = 'true' ]]; then
      echo "success: $dns_mode DNS $RECORD_TYPE record succeeded"
      echo "$create_dns_aaaa" | jq -r
    fi
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Adjust Cloudflare Settings For: $domain"
  echo "---------------------------------------------------------------------"
  echo
  if [[ "$cloudflare_zoneid" && "$cloudflare_api_token" ]]; then
    echo "-------------------------------------------------"
    echo "Set CF SSL Mode To Full SSL"
    echo "-------------------------------------------------"
    # options are off, flexible, full, strict
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/ssl" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"full"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/ssl" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    echo "-------------------------------------------------"
    echo "Set CF Always Use HTTPS Off"
    echo "-------------------------------------------------"
    # options are off, on
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/always_use_https" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"off"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/always_use_https" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    echo "-------------------------------------------------"
    echo "Set CF Automatic HTTPS Rewrites Off"
    echo "-------------------------------------------------"
    # options are off, on
  set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/ automatic_https_rewrites" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"off"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/automatic_https_rewrites" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    echo "-------------------------------------------------"
    echo "Enable CF Tiered Caching"
    echo "-------------------------------------------------"
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/argo/tiered_caching" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"on"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/argo/tiered_caching" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    echo "-------------------------------------------------"
    echo "Set CF Browser Cache TTL = Respect Origin Headers"
    echo "-------------------------------------------------"
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/browser_cache_ttl" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":0}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/browser_cache_ttl" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    echo "-------------------------------------------------"
    echo "Set CF Minimum TLSv1.2 Version"
    echo "-------------------------------------------------"
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/min_tls_version" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"1.2"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/min_tls_version" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    echo "-------------------------------------------------"
    echo "Disable Email Obfuscation (Page Speed Optimization)"
    echo "-------------------------------------------------"
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/email_obfuscation" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"off"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/email_obfuscation" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
    if [[ "$CF_ENABLE_CRAWLER_HINTS" = [yY] ]]; then
      echo "-------------------------------------------------"
      echo "Enable CF Crawler Hints"
      echo "-------------------------------------------------"
      set=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/flags/products/cache/changes" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
              --data '{"feature":"crawlhints_enabled","value":true}' )
      check_cmd=$(echo "$set" | jq -r '.success')
      if [[ "$check_cmd" = 'false' ]]; then
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo "error: CF API command failed."
          echo "$set" | jq -r
        else
          echo "error: CF API command failed."
        fi
      elif [[ "$check_cmd" = 'true' ]]; then
        echo "ok: CF API command succeeded."
        echo
        echo "$set" | jq -r
        echo
        echo "check setting"
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/flags/products/cache/changes" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
      fi
    fi
    if [[ "$CF_ENABLE_CACHE_RESERVE" = [yY] ]]; then
      echo "-------------------------------------------------"
      echo "Enable CF Cache Reserve"
      echo "-------------------------------------------------"
      set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/cache/cache_reserve" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"on"}' )
      check_cmd=$(echo "$set" | jq -r '.success')
      if [[ "$check_cmd" = 'false' ]]; then
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo "error: CF API command failed."
          echo "$set" | jq -r
        else
          echo "error: CF API command failed."
        fi
      elif [[ "$check_cmd" = 'true' ]]; then
        echo "ok: CF API command succeeded."
        echo
        echo "$set" | jq -r
        echo
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/cache/cache_reserve" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
      fi
    fi
    echo "-------------------------------------------------"
    echo "Enable HTTP Prioritization"
    echo "-------------------------------------------------"
    set=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/h2_prioritization" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
            --data '{"value":"on"}' )
    check_cmd=$(echo "$set" | jq -r '.success')
    if [[ "$check_cmd" = 'false' ]]; then
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "error: CF API command failed."
        echo "$set" | jq -r
      else
        echo "error: CF API command failed."
      fi
    elif [[ "$check_cmd" = 'true' ]]; then
      echo "ok: CF API command succeeded."
      echo
      echo "$set" | jq -r
      echo
      echo "check setting"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/h2_prioritization" \
            -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
    fi
  else
    echo
    echo "$cloudflare_zoneid and $cloudflare_api_token not set"
  fi # check if $cloudflare_api_token and $cloudflare_zoneid set
  echo
  echo "---------------------------------------------------------------------"
  echo "Nginx Vhost Creation For: $domain"
  echo "---------------------------------------------------------------------"
  echo
  if [ -f /usr/bin/nv ]; then
    ftp_pass=$(pwgen -1cnys 29)
    echo "creating vhost $domain..."
    echo
    echo "/usr/bin/nv -d $domain -s lelived -u $ftp_pass"
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Create MySSQL Databases For: $domain"
  echo "---------------------------------------------------------------------"
  echo
  if [ -f /usr/local/src/centminmod/addons/mysqladmin_shell.sh ]; then
    if [[ "$mysqldb1" && "$mysqluser1" && "$mysqlpass1" ]]; then
      echo "/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb $mysqldb1 $mysqluser1 $mysqlpass1"
    fi
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Robots.txt File For: $domain"
  echo "---------------------------------------------------------------------"
  if [[ -f "$robotsfile" || "$DEBUG_MODE" = [yY] ]]; then
    echo
    # echo "copying $robotsfile to ${webroot}/robots.txt"
    echo "\cp -af $robotsfile ${webroot}/robots.txt"
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Cronjobs For: $domain"
  echo "---------------------------------------------------------------------"
  if [[ -f "$cronjobfile" || "$DEBUG_MODE" = [yY] ]]; then
    echo
    echo "setup $cronjobfile"
    echo "mkdir -p /etc/centminmod/cronjobs/"
    echo "crontab -l > \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\""
    echo "cat \"$cronjobfile\" >> \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\""
    echo "crontab \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\""
    # mkdir -p /etc/centminmod/cronjobs/
    # crontab -l > "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
    # cat "$cronjobfile" >> "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
    # crontab "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
  fi
  echo
  echo
}

help() {
  echo
  echo "Usage:"
  echo
  echo "$0 create vhost-config.json"
}

case "$1" in
  create )
    create_vhost "$2"
    ;;
  * )
    help
    ;;
esac