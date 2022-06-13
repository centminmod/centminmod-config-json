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
DT=$(date +"%d%m%y-%H%M%S")
DEBUG_MODE='y'

#############################################################################
# Cloudflare settings
CF_ENABLE_CACHE_RESERVE='n'
#############################################################################

parse_file() {
  file="$1"
  file_parsed=$(egrep -v '^#|^\/\*|^\/' "$file" | jq -r '.data[]')
  domain=$(echo "$file_parsed" | jq -r '."domain"')
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
    echo "domain=$domain"
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
        -H "Authorization: Bearer $cloudflare_api_token" \
        -H "Content-Type:application/json" | jq -r
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Cloudflare DNS API Token For: $domain"
  echo "---------------------------------------------------------------------"
  echo
  echo "CF_DNSAPI_GLOBAL='y'"
  echo "CF_Token=\"$cloudflare_api_token\""
  echo "CF_Account_ID=\"$cloudflare_accountid\""
  echo
  echo "---------------------------------------------------------------------"
  echo "Adjust Cloudflare Settings For: $domain"
  echo "---------------------------------------------------------------------"
  echo
  echo "-------------------------------------------------"
  echo "Set CF SSL Mode To Full SSL"
  echo "-------------------------------------------------"
  # options are off, flexible, full, strict
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/ssl" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"full"}' | jq
  echo "-------------------------------------------------"
  echo "Set CF Always Use HTTPS Off"
  echo "-------------------------------------------------"
  # options are off, on
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/always_use_https" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"off"}' | jq
  echo "-------------------------------------------------"
  echo "Set CF Automatic HTTPS Rewrites Off"
  echo "-------------------------------------------------"
  # options are off, on
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/automatic_https_rewrites" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"off"}' | jq
  echo "-------------------------------------------------"
  echo "Enable CF Tiered Caching"
  echo "-------------------------------------------------"
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/argo/tiered_caching" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"on"}' | jq
  echo "-------------------------------------------------"
  echo "Set CF Browser Cache TTL = Respect Origin Headers"
  echo "-------------------------------------------------"
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/browser_cache_ttl" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":0}' | jq
  echo "-------------------------------------------------"
  echo "Set CF Minimum TLSv1.2 Version"
  echo "-------------------------------------------------"
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/min_tls_version" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"1.2"}' | jq
  echo "-------------------------------------------------"
  echo "Disable Email Obfuscation (Page Speed Optimization)"
  echo "-------------------------------------------------"
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/email_obfuscation" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"off"}' | jq
  echo "-------------------------------------------------"
  echo "Enable CF Crawler Hints"
  echo "-------------------------------------------------"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/flags/products/cache/changes" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"feature":"crawlhints_enabled","value":true}' | jq
  if [[ "$CF_ENABLE_CACHE_RESERVE" = [yY] ]]; then
    echo "-------------------------------------------------"
    echo "Enable CF Cache Reserve"
    echo "-------------------------------------------------"
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/cache/cache_reserve" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"on"}' | jq
  fi
  echo "-------------------------------------------------"
  echo "Enable HTTP Prioritization"
  echo "-------------------------------------------------"
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${cloudflare_zoneid}/settings/h2_prioritization" \
          -H "Authorization: Bearer $cloudflare_api_token" \
          -H "Content-Type: application/json" \
          --data '{"value":"on"}' | jq

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