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
VER='0.2'
DT=$(date +"%d%m%y-%H%M%S")
DEBUG_MODE='y'
SENSITIVE_INFO_MASK='n'

#############################################################################
# Cloudflare settings
CF_DNS_IPFOUR_ONLY='y'
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
# utilise /etc/centminmod/acmetool-config.ini for convenience
if [ ! -f /etc/centminmod/acmetool-config.ini ]; then
  touch /etc/centminmod/acmetool-config.ini
fi

check_dns() {
  vhostname_dns="$1"
    # if CHECKIDN = 0 then internationalized domain name which not supported by letsencrypt
    CHECKIDN=$(echo $vhostname_dns | idn | grep '^xn--' >/dev/null 2>&1; echo $?)
    if [[ "$CHECKIDN" = '0' ]]; then
      TOPLEVELCHECK=$(dig soa @8.8.8.8 $vhostname_dns | grep -v ^\; | grep SOA | awk '{print $1}' | sed 's/\.$//' | idn)
    else
      TOPLEVELCHECK=$(dig soa @8.8.8.8 $vhostname_dns | grep -v ^\; | grep SOA | awk '{print $1}' | sed 's/\.$//')
    fi
    if [[ "$TOPLEVELCHECK" = "$vhostname_dns" ]]; then
      # top level domain
      TOPLEVEL=y
    elif [[ -z "$TOPLEVELCHECK" ]]; then
      # vhost dns not setup
      TOPLEVEL=z
      if [[ "$(echo $vhostname_dns | grep -o "\." | wc -l)" -le '1' ]]; then
        TOPLEVEL=y
      else
        TOPLEVEL=n
      fi
    else
      # subdomain or non top level domain
      TOPLEVEL=n
    fi
}

backup_zone_bind() {
  domain="$1"
  token="$cloudflare_api_token"
  curl -4sX GET "${endpoint}zones/${cloudflare_zoneid}/dns_records/export" -H "Content-Type:application/json" -H "Authorization: Bearer $token" > "$BIND_ZONE_BACKUPDIR/cf-zone-bind-export-$domain-$DT.txt"
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
  input_domain="$2"
  file_parsed=$(egrep -v '^#|^\/\*|^\/' "$file" | jq -r '.data[]')
  if [ "$input_domain" ]; then
    # parse domains to process
    domain=$(echo "$file_parsed" | jq -r '."domain"')
    domain_array_json=$(echo "$file_parsed" | jq 'with_entries(if (.key|test("domain-parked|domain$")) then ( {key: ."key", value: ."value" } ) else empty end )' | sed -e "s|$domain|$input_domain|g")
    domain_array_list=$(echo "$domain_array_json" | jq -r 'to_entries[] | ."value"' | sed -e "s|$domain|$input_domain|g")
    domain_array_comma_list=$(echo "$domain_array_json" | jq -r 'to_entries[] | ."value"' | xargs | sed -e 's| |,|g' | sed -e "s|$domain|$input_domain|g")
    check_domain_is_array=$(echo "$domain_array_comma_list"| awk '/\,/'; domain_is_array_check=$?)
    domain_preferred=$(echo "$file_parsed" | jq -r '."domain-preferred"' | sed -e "s|$domain|$input_domain|g")
    domain_parked1=$(echo "$file_parsed" | jq -r '."domain-parked1"' | sed -e "s|$domain|$input_domain|g")
    domain_parked2=$(echo "$file_parsed" | jq -r '."domain-parked2"' | sed -e "s|$domain|$input_domain|g")
    domain_parked3=$(echo "$file_parsed" | jq -r '."domain-parked3"' | sed -e "s|$domain|$input_domain|g")
    domain_parked4=$(echo "$file_parsed" | jq -r '."domain-parked4"' | sed -e "s|$domain|$input_domain|g")
    domain_parked5=$(echo "$file_parsed" | jq -r '."domain-parked5"' | sed -e "s|$domain|$input_domain|g")
    domain_parked6=$(echo "$file_parsed" | jq -r '."domain-parked6"' | sed -e "s|$domain|$input_domain|g")
    webroot=$(echo "$file_parsed" | jq -r '."webroot"' | sed -e "s|$domain|$input_domain|g")
    index=$(echo "$file_parsed" | jq -r '."index"' | sed -e "s|$domain|$input_domain|g")
    robotsfile=$(echo "$file_parsed" | jq -r '."robotsfile"' | sed -e "s|$domain|$input_domain|g")
    domain=${input_domain}
  else
    domain=$(echo "$file_parsed" | jq -r '."domain"')
    # parse domains to process
    domain_array_json=$(echo "$file_parsed" | jq 'with_entries(if (.key|test("domain-parked|domain$")) then ( {key: ."key", value: ."value" } ) else empty end )')
    domain_array_list=$(echo "$domain_array_json" | jq -r 'to_entries[] | ."value"')
    domain_array_comma_list=$(echo "$domain_array_json" | jq -r 'to_entries[] | ."value"' | xargs | sed -e 's| |,|g')
    check_domain_is_array=$(echo "$domain_array_comma_list"| awk '/\,/'; domain_is_array_check=$?)
    domain_preferred=$(echo "$file_parsed" | jq -r '."domain-preferred"')
    domain_parked1=$(echo "$file_parsed" | jq -r '."domain-parked1"')
    domain_parked2=$(echo "$file_parsed" | jq -r '."domain-parked2"')
    domain_parked3=$(echo "$file_parsed" | jq -r '."domain-parked3"')
    domain_parked4=$(echo "$file_parsed" | jq -r '."domain-parked4"')
    domain_parked5=$(echo "$file_parsed" | jq -r '."domain-parked5"')
    domain_parked6=$(echo "$file_parsed" | jq -r '."domain-parked6"')
    webroot=$(echo "$file_parsed" | jq -r '."webroot"')
    index=$(echo "$file_parsed" | jq -r '."index"')
    robotsfile=$(echo "$file_parsed" | jq -r '."robotsfile"')
  fi
  if [ "${domain}" ]; then
    check_dns "${domain}"
  fi
  # check if domain is subdomain or not as subdomains
  # do not have www hostname
  if [[ "$TOPLEVEL" = [nN] ]]; then
    domain_www=""
  else
    if [ "$input_domain" ]; then
      domain=$(echo "$file_parsed" | jq -r '."domain"')
      domain_www=$(echo "$file_parsed" | jq -r '."domain-www"' | sed -e "s|$domain|$input_domain|g")
      domain=${input_domain}
    else
      domain_www=$(echo "$file_parsed" | jq -r '."domain-www"')
    fi
  fi
  # parse databases to process
  database_array_json=$(echo "$file_parsed" | jq 'with_entries(if (.key|test("mysqldb|mysqluser|mysqlpass")) then ( {key: ."key", value: ."value" } ) else empty end )')
  database_array_list=$(echo "$database_array_json" | jq -r 'to_entries[] | ."value"')
  database_array_user_pairs=$(echo "$database_array_list" | xargs -n3)

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
  cronjobfile=$(echo "$file_parsed" | jq -r '."cronjobfile"')
  cfplan=$(curl -sX GET -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" "${endpoint}zones/$cloudflare_zoneid" | jq -r '.result.plan.legacy_id')
  if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
    debug_label_domain=$(echo "$domain" | sed -e "s|$domain|domain.com|g")
    debug_label_domain_www=$(echo "${domain_www}" | sed -e "s|${domain_www}|www.domain.com|g")
    debug_label_domain_preferred=$(echo "$domain_preferred" | sed -e "s|$domain_preferred|domain.com|g")
    debug_label_domain_parked1=$(echo "$domain_parked1" | sed -e "s|$domain_parked1|parkeddomain1.domain.com|g")
    debug_label_domain_parked2=$(echo "$domain_parked2" | sed -e "s|$domain_parked2|parkeddomain2.domain.com|g")
    debug_label_domain_parked3=$(echo "$domain_parked3" | sed -e "s|$domain_parked3|parkeddomain3.domain.com|g")
    debug_label_domain_parked4=$(echo "$domain_parked4" | sed -e "s|$domain_parked4|parkeddomain4.domain.com|g")
    debug_label_domain_parked5=$(echo "$domain_parked5" | sed -e "s|$domain_parked5|parkeddomain5.domain.com|g")
    debug_label_domain_parked6=$(echo "$domain_parked6" | sed -e "s|$domain_parked6|parkeddomain6.domain.com|g")
  else
    debug_label_domain=${domain}
    debug_label_domain_www=${domain_www}
    debug_label_domain_preferred=${domain_preferred}
    debug_label_domain_parked1=${domain_parked1}
    debug_label_domain_parked2=${domain_parked2}
    debug_label_domain_parked3=${domain_parked3}
    debug_label_domain_parked4=${domain_parked4}
    debug_label_domain_parked5=${domain_parked5}
    debug_label_domain_parked6=${domain_parked6}
  fi
  if [[ "$DEBUG_MODE" = [yY] ]]; then
    echo
    echo "---------------------------------------------------------------------"
    echo "Debug Mode Output:"
    echo "---------------------------------------------------------------------"
    if [ -z "$input_domain" ]; then
      echo "parsed vhost config file output"
      if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
        echo "${file_parsed}" | sed -e "s|$domain|domain.com|g" -e "s|$cloudflare_api_token|CF_API_TOKEN|" -e "s|$cloudflare_accountid|CF_Account_ID|"
      else
        echo "${file_parsed}" 
      fi
    fi
    echo "---------------------------------------------------------------------"
    echo "Variable checks:"
    echo "---------------------------------------------------------------------"
    echo "cfplan=$cfplan"
    echo "domain=$debug_label_domain"
    echo "domain_www=${debug_label_domain_www}"
    echo "domain_preferred=${debug_label_domain_preferred}"
    if [ "$debug_label_domain_parked1" ]; then
      echo "domain_parked1=${debug_label_domain_parked1}"
    fi
    if [ "$debug_label_domain_parked2" ]; then
      echo "domain_parked2=${debug_label_domain_parked2}"
    fi
    if [ "$debug_label_domain_parked3" ]; then
      echo "domain_parked3=${debug_label_domain_parked3}"
    fi
    if [ "$debug_label_domain_parked4" ]; then
      echo "domain_parked4=${debug_label_domain_parked4}"
    fi
    if [ "$debug_label_domain_parked5" ]; then
      echo "domain_parked5=${debug_label_domain_parked5}"
    fi
    if [ "$debug_label_domain_parked6" ]; then
      echo "domain_parked6=${debug_label_domain_parked6}"
    fi
    echo "email=${email}"
    echo "https=${https}"
    echo "origin_sslcert=${origin-sslcert}"
    echo "cloudflare=${cloudflare}"
    if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
      echo "cloudflare_accountid=*********"
      echo "cloudflare_zoneid=*********"
      echo "cloudflare_api_token=*********"
    else
      echo "cloudflare_accountid=${cloudflare-accountid}"
      echo "cloudflare_zoneid=${cloudflare-zoneid}"
      echo "cloudflare_api_token=${cloudflare-api-token}"
    fi
    echo "cloudflare_min_tls=${cloudflare-min-tls}"
    echo "cloudflare_tiered_cache=${cloudflare-tiered-cache}"
    echo "cloudflare_cache_reserve=${cloudflare-cache-reserve}"
    echo "cloudflare_crawler_hints=${cloudflare-crawler-hints}"
    echo "cloudflare_respect_origin_headers=${cloudflare-respect-origin-headers}"
    echo "type=${type}"
    if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
      echo "mysqldb1=mysqldb1_mask"
      echo "mysqluser1=mysqluser1_mask"
      echo "mysqlpass1=mysqlpass1_mask"
      echo "mysqldb2=mysqldb2_mask"
      echo "mysqluser2=mysqluser2_mask"
      echo "mysqlpass2=mysqlpass2_mask"
      echo "mysqldb3=mysqldb3_mask"
      echo "mysqluser3=mysqluser3_mask"
      echo "mysqlpass3=mysqlpass3_mask"
      echo "mysqldb4=mysqldb4_mask"
      echo "mysqluser4=mysqluser4_mask"
      echo "mysqlpass4=mysqlpass4_mask"
      echo "mysqldb5=mysqldb5_mask"
      echo "mysqluser5=mysqluser5_mask"
      echo "mysqlpass5=mysqlpass5_mask"
    else
      echo "mysqldb1=${mysqldb1}"
      echo "mysqluser1=${mysqluser1}"
      echo "mysqlpass1=${mysqlpass1}"
      echo "mysqldb2=${mysqldb2}"
      echo "mysqluser2=${mysqluser2}"
      echo "mysqlpass2=${mysqlpass2}"
      echo "mysqldb3=${mysqldb3}"
      echo "mysqluser3=${mysqluser3}"
      echo "mysqlpass3=${mysqlpass3}"
      echo "mysqldb4=${mysqldb4}"
      echo "mysqluser4=${mysqluser4}"
      echo "mysqlpass4=${mysqlpass4}"
      echo "mysqldb5=${mysqldb5}"
      echo "mysqluser5=${mysqluser5}"
      echo "mysqlpass5=${mysqlpass5}"
    fi
    echo "webroot=${webroot}"
    echo "index=${index}"
    echo "robotsfile=${robotsfile}"
    echo "cronjobfile=${cronjobfile}"
    echo "---------------------------------------------------------------------"
  fi
}

create_vhost() {
  file="$1"
  if [ "$2" ]; then
    parse_file "$file" "$2"
  else
    parse_file "$file"
  fi
  
  if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
    domain_name_label=domain.com
  else
    domain_name_label=${domain}
  fi
  if [[ "$cloudflare" = 'yes' || "$cloudflare" = [yY] ]]; then
    echo
    echo "---------------------------------------------------------------------"
    echo "Check Cloudflare API Token For: ${domain_name_label}"
    echo "---------------------------------------------------------------------"
    echo
    echo "curl -X GET \"https://api.cloudflare.com/client/v4/user/tokens/verify\" \\"
    echo "     -H \"Authorization: Bearer $cloudflare_api_token\" \\"
    echo "     -H \"Content-Type:application/json\""
    curl -sX GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
          -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type:application/json" | jq -r
    echo
    echo "---------------------------------------------------------------------"
    echo "Setup Cloudflare DNS API Token For: ${domain_name_label} (CF $cfplan plan)"
    echo "---------------------------------------------------------------------"
    echo
    # if /etc/centminmod/acmetool-config.ini doesn't exist, then rely on
    # /etc/centminmod/custom_config.inc
    if [ ! -f /etc/centminmod/acmetool-config.ini ]; then
      if [ -f /etc/centminmod/custom_config.inc ]; then
        # check if CF DNS API for acmetool.sh/acme.sh exists already
        get_cf_dnsapi_global=$(grep '^CF_DNSAPI_GLOBAL' /etc/centminmod/custom_config.inc)
        get_cf_token=$(grep '^CF_Token' /etc/centminmod/custom_config.inc)
        get_cf_account_id=$(grep '^CF_Account_ID' /etc/centminmod/custom_config.inc)
      elif [ ! -f /etc/centminmod/custom_config.inc ]; then
        touch /etc/centminmod/custom_config.inc
        echo "CF_DNSAPI_GLOBAL='y'" >> /etc/centminmod/custom_config.inc
        echo "CF_Token=\"$cloudflare_api_token\"" >> /etc/centminmod/custom_config.inc
        echo "CF_Account_ID=\"$cloudflare_accountid\"" >> /etc/centminmod/custom_config.inc
      fi
      # determine if we should remove entries after nvjson.sh run
      if [[ "$get_cf_dnsapi_global" && "$get_cf_token" && "$get_cf_account_id" ]]; then
        # CF DNS API for acmetool.sh/acme.sh exists already
        # setup overriding config at /etc/centminmod/acmetool-config.ini
        touch /etc/centminmod/acmetool-config.ini
        # then replace them with ones set in user vhost-config.json file temporarily
        # sed -i '/^CF_DNSAPI_GLOBAL/d' /etc/centminmod/custom_config.inc
        # sed -i '/^CF_Token/d' /etc/centminmod/custom_config.inc
        # sed -i '/^CF_Account_ID/d' /etc/centminmod/custom_config.inc
        echo "CF_DNSAPI_GLOBAL='y'" >> /etc/centminmod/acmetool-config.ini
        echo "CF_Token=\"$cloudflare_api_token\"" >> /etc/centminmod/acmetool-config.ini
        echo "CF_Account_ID=\"$cloudflare_accountid\"" >> /etc/centminmod/acmetool-config.ini
      fi
    elif [ -f /etc/centminmod/acmetool-config.ini ]; then
      # /etc/centminmod/acmetool-config.ini exists and takes priority over
      # /etc/centminmod/custom_config.inc
      # check if CF DNS API for acmetool.sh/acme.sh exists already
      get_cf_dnsapi_global=$(grep '^CF_DNSAPI_GLOBAL' /etc/centminmod/acmetool-config.ini)
      get_cf_token=$(grep '^CF_Token' /etc/centminmod/acmetool-config.ini)
      get_cf_account_id=$(grep '^CF_Account_ID' /etc/centminmod/acmetool-config.ini)
      if [[ -z "$get_cf_dnsapi_global" && -z "$get_cf_token" && -z "$get_cf_account_id" ]]; then
        echo "CF_DNSAPI_GLOBAL='y'" >> /etc/centminmod/acmetool-config.ini
        echo "CF_Token=\"$cloudflare_api_token\"" >> /etc/centminmod/acmetool-config.ini
        echo "CF_Account_ID=\"$cloudflare_accountid\"" >> /etc/centminmod/acmetool-config.ini
        if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
          echo "configured /etc/centminmod/acmetool-config.ini"
          cat /etc/centminmod/acmetool-config.ini | sed -e "s|$cloudflare_api_token|CF_API_TOKEN|" -e "s|$cloudflare_accountid|CF_Account_ID|"
        else
          echo "configured /etc/centminmod/acmetool-config.ini"
          cat /etc/centminmod/acmetool-config.ini
        fi
      fi
      # determine if we should remove entries after nvjson.sh run
      if [[ "$get_cf_dnsapi_global" && "$get_cf_token" && "$get_cf_account_id" ]]; then
        # CF DNS API for acmetool.sh/acme.sh exists already
        # want to backup existing credentials /etc/centminmod/cf-dns-api-nvjson.ini
        if [ ! -f /etc/centminmod/cf-dns-api-nvjson.ini ]; then
          touch /etc/centminmod/cf-dns-api-nvjson.ini
          echo "$get_cf_dnsapi_global" >> /etc/centminmod/cf-dns-api-nvjson.ini
          echo "$get_cf_token" >> /etc/centminmod/cf-dns-api-nvjson.ini
          echo "$get_cf_account_id" >> /etc/centminmod/cf-dns-api-nvjson.ini
        fi
        # then replace them with ones set in user vhost-config.json file temporarily
        sed -i '/^CF_DNSAPI_GLOBAL/d' /etc/centminmod/acmetool-config.ini
        sed -i '/^CF_Token/d' /etc/centminmod/acmetool-config.ini
        sed -i '/^CF_Account_ID/d' /etc/centminmod/acmetool-config.ini
        echo "CF_DNSAPI_GLOBAL='y'" >> /etc/centminmod/acmetool-config.ini
        echo "CF_Token=\"$cloudflare_api_token\"" >> /etc/centminmod/acmetool-config.ini
        echo "CF_Account_ID=\"$cloudflare_accountid\"" >> /etc/centminmod/acmetool-config.ini
        if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
          echo "configured /etc/centminmod/acmetool-config.ini"
          cat /etc/centminmod/acmetool-config.ini | sed -e "s|$cloudflare_api_token|CF_API_TOKEN|" -e "s|$cloudflare_accountid|CF_Account_ID|"
        else
          echo "configured /etc/centminmod/acmetool-config.ini"
          cat /etc/centminmod/acmetool-config.ini
        fi
      fi
    fi
    # if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
    #   echo "CF_DNSAPI_GLOBAL='y'"
    #   echo "CF_Token=\"cloudflare_api_token\""
    #   echo "CF_Account_ID=\"cloudflare_accountid\""
    # else
    #   echo "CF_DNSAPI_GLOBAL='y'"
    #   echo "CF_Token=\"$cloudflare_api_token\""
    #   echo "CF_Account_ID=\"$cloudflare_accountid\""
    # fi
    echo
    echo
    echo "---------------------------------------------------------------------"
    echo "Setup Cloudflare DNS A For: ${domain_name_label} (CF $cfplan plan)"
    echo "---------------------------------------------------------------------"
    SERVERIP_A=$(curl -4s -A "$CURL_AGENT IPv4" https://geoip.centminmod.com/v3 | jq -r '.ip')
    SERVERIP_AAAA=$(curl -6s -A "$CURL_AGENT IPv6" https://geoip.centminmod.com/v3 | jq -r '.ip')
    DNS_CONTENT_A="$SERVERIP_A"
    DNS_CONTENT_AAAA="$SERVERIP_AAAA"
    if [[ "$IS_PROXIED" = [yY] ]]; then
      PROXY_OPT=true
    else
      PROXY_OPT=false
    fi
    backup_zone_bind "${domain}"
    # cycle through $domain_array_list to create DNS A/AAAA records for
    # primary domain and any parked domain names listed in vhost JSON config file
    # under .domain-parkedX keys and .domain key
    for dn in $domain_array_list; do
      #############################################################################
      # create A record
      if [[ "$DNS_CONTENT_A" && "$dn" ]]; then
        RECORD_TYPE="A"
        DNS_RECORD_NAME="$dn"
        dns_mode=create
        create_dns_a=$(curl -sX POST "${endpoint}zones/${cloudflare_zoneid}/dns_records" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
          --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_A $DNS_CONTENT_A --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_A\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
        check_create_dns_a=$(echo "$create_dns_a" | jq -r '.success')
        check_create_dns_a_errcode=$(echo "$create_dns_a" | jq -r '.errors[] | .code')
        if [[ "$check_create_dns_a_errcode" = '81057' ]]; then
          dns_mode=update
          # update not create DNS record
          endpoint_target="zones/${cloudflare_zoneid}/dns_records?type=${RECORD_TYPE}&name=${DNS_RECORD_NAME}&page=1&per_page=100&order=type&direction=desc&match=all"
          dnsrecid=$(curl -sX GET "${endpoint}${endpoint_target}" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" | jq -r '.result[] | .id')
          create_dns_a=$(curl -sX PATCH "${endpoint}zones/${cloudflare_zoneid}/dns_records/$dnsrecid" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
          --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_A $DNS_CONTENT_A --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_A\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
          check_create_dns_a=$(echo "$create_dns_a" | jq -r '.success')
        fi
        if [[ "$check_create_dns_a" = 'false' && "$check_create_dns_a_errcode" != '81057' ]]; then
          echo "error: $dns_mode DNS $RECORD_TYPE record failed"
          echo "$create_dns_a" | jq -r '.errors[] | "code: \(.code) message: \(.message)"'
        elif [[ "$check_create_dns_a" = 'false' && "$check_create_dns_a_errcode" = '81057' ]]; then
          echo "error: $dns_mode DNS $RECORD_TYPE record failed"
          echo "$create_dns_a" | jq -r '.errors[] | "code: \(.code) message: \(.message)"'
        elif [[ "$check_create_dns_a" = 'true' ]]; then
          echo "success: $dns_mode DNS $RECORD_TYPE record succeeded"
          if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
            echo "$create_dns_a" | sed -e "s|$cloudflare_zoneid|CF_ZONEID|g" -e "s|$DNS_CONTENT_A|111.222.333.444|g" -e "s|$dn|domain.com|g" -e "s|$domain|domain.com|g" | jq -r
          else
            echo "$create_dns_a" | jq -r
          fi
        fi
      fi
      if [[ "$CF_DNS_IPFOUR_ONLY" != [yY] ]]; then
        # create AAAA record
        if [[ "$DNS_CONTENT_AAAA" && "$dn" ]]; then
          RECORD_TYPE="AAAA"
          DNS_RECORD_NAME="$dn"
          create_dns_aaaa=$(curl -sX POST "${endpoint}zones/${cloudflare_zoneid}/dns_records" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
            --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_AAAA $DNS_CONTENT_AAAA --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_AAAA\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
          check_create_dns_aaaa=$(echo "$create_dns_aaaa" | jq -r '.success')
          check_create_dns_aaaa_errcode=$(echo "$create_dns_aaaa" | jq -r '.errors[] | .code')
          if [[ "$check_create_dns_a_errcode" = '81057' ]]; then
            dns_mode=update
            # update not create DNS record
            endpoint_target="zones/${cloudflare_zoneid}/dns_records?type=${RECORD_TYPE}&name=${DNS_RECORD_NAME}&page=1&per_page=100&order=type&direction=desc&match=all"
            dnsrecid=$(curl -sX GET "${endpoint}${endpoint_target}" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" | jq -r '.result[] | .id')
            create_dns_aaaa=$(curl -sX PATCH "${endpoint}zones/${cloudflare_zoneid}/dns_records/$dnsrecid" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" \
            --data $(jq -c -n --arg RECORD_TYPE $RECORD_TYPE --arg DNS_RECORD_NAME $DNS_RECORD_NAME --arg DNS_CONTENT_AAAA $DNS_CONTENT_AAAA --arg PROXY_OPT $PROXY_OPT $(echo "{\"type\":\"$RECORD_TYPE\",\"name\":\"$DNS_RECORD_NAME\",\"content\":\"$DNS_CONTENT_AAAA\",\"ttl\":120,\"proxied\":$PROXY_OPT}") ))
            check_create_dns_aaaa=$(echo "$create_dns_aaaa" | jq -r '.success')
          fi
          if [[ "$check_create_dns_aaaa" = 'false' && "$check_create_dns_a_errcode" != '81057' ]]; then
            echo "error: $dns_mode DNS $RECORD_TYPE record failed"
            echo "$create_dns_aaaa" | jq -r '.errors[] | "code: \(.code) message: \(.message)"'
          elif [[ "$check_create_dns_aaaa" = 'false' && "$check_create_dns_a_errcode" = '81057' ]]; then
            echo "error: $dns_mode DNS $RECORD_TYPE record failed"
            echo "$create_dns_aaaa" | jq -r '.errors[] | "code: \(.code) message: \(.message)"'
          elif [[ "$check_create_dns_aaaa" = 'true' ]]; then
            echo "success: $dns_mode DNS $RECORD_TYPE record succeeded"
            if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
              echo "$create_dns_aaaa" | sed -e "s|$cloudflare_zoneid|CF_ZONEID|g" -e "s|$DNS_CONTENT_A|111.222.333.444|g" -e "s|$dn|domain.com|g" -e "s|$domain|domain.com|g" | jq -r
            else
              echo "$create_dns_aaaa" | jq -r
            fi
          fi
        fi
      elif [[ "$CF_DNS_IPFOUR_ONLY" = [yY] ]]; then
        RECORD_TYPE="AAAA"
        DNS_RECORD_NAME="$dn"
        # if IPv4 only DNS is set, check and remove any AAAA entries 
        # check if existing AAAA record exists
        endpoint_target="zones/${cloudflare_zoneid}/dns_records?name=${dn}&type=${RECORD_TYPE}&page=1&per_page=100&direction=desc&match=all"
        dnsrecid=$(curl -sX GET "${endpoint}${endpoint_target}" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" | jq -r '.result[] | .id')
        if [ "$dnsrecid" ]; then
          echo "detected $RECORD_TYPE record for $dn"
          echo "removing $RECORD_TYPE record for $dn"
          endpoint_target="zones/${cloudflare_zoneid}/dns_records/$dnsrecid"
          curl -sX DELETE "${endpoint}${endpoint_target}" -H "Content-Type:application/json" -H "Authorization: Bearer $cloudflare_api_token" | jq -r
        fi
      fi # CF_DNS_IPFOUR_ONLY
      #############################################################################
    done # domain_array_list loop
    echo
    echo "---------------------------------------------------------------------"
    echo "Adjust Cloudflare Settings For: ${domain_name_label}"
    echo "---------------------------------------------------------------------"
    echo
    if [[ "$cloudflare_zoneid" && "$cloudflare_api_token" ]]; then
      if [[ "$https" = 'yes' || "$https" = [yY] ]]; then
        echo "-------------------------------------------------"
        echo "Set CF SSL Mode To Full SSL"
        echo "-------------------------------------------------"
        # options are off, flexible, full, strict
        set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/ssl" \
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
          if [[ "$DEBUG_MODE" = [yY] ]]; then
            echo "check setting"
            curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/ssl" \
                -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
          fi
        fi
      else
        echo "-------------------------------------------------"
        echo "Set CF SSL Mode To Flexible SSL"
        echo "-------------------------------------------------"
        # options are off, flexible, full, strict
        set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/ssl" \
                -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" \
                --data '{"value":"flexible"}' )
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
          if [[ "$DEBUG_MODE" = [yY] ]]; then
            echo "check setting"
            curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/ssl" \
                -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
          fi
        fi
      fi # non-https/https
      echo "-------------------------------------------------"
      echo "Set CF Always Use HTTPS Off"
      echo "-------------------------------------------------"
      # options are off, on
      set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/always_use_https" \
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
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo "check setting"
          curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/always_use_https" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
        fi
      fi
      echo "-------------------------------------------------"
      echo "Set CF Automatic HTTPS Rewrites Off"
      echo "-------------------------------------------------"
      # options are off, on
      set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/ automatic_https_rewrites" \
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
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo "check setting"
          curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/automatic_https_rewrites" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
        fi
      fi
      if [[ "$cloudflare_tiered_cache" = 'yes' || "$cloudflare_tiered_cache" = [yY] ]]; then
        echo "-------------------------------------------------"
        echo "Enable CF Tiered Caching"
        echo "-------------------------------------------------"
        set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/argo/tiered_caching" \
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
          if [[ "$DEBUG_MODE" = [yY] ]]; then
            echo "check setting"
            curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/argo/tiered_caching" \
                -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
          fi
        fi
      fi
      if [[ "$cloudflare_respect_origin_headers" = 'yes' || "$cloudflare_respect_origin_headers" = [yY] ]]; then
        echo "-------------------------------------------------"
        echo "Set CF Browser Cache TTL = Respect Origin Headers"
        echo "-------------------------------------------------"
        set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/browser_cache_ttl" \
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
          if [[ "$DEBUG_MODE" = [yY] ]]; then
            echo "check setting"
            curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/browser_cache_ttl" \
                -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
          fi
        fi
      fi
      if [[ "$cloudflare_min_tls" = 'yes' || "$cloudflare_min_tls" = [yY] ]]; then
        echo "-------------------------------------------------"
        echo "Set CF Minimum TLSv1.2 Version"
        echo "-------------------------------------------------"
        set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/min_tls_version" \
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
          if [[ "$DEBUG_MODE" = [yY] ]]; then
            echo "check setting"
            curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/min_tls_version" \
                -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
          fi
        fi
      fi
      echo "-------------------------------------------------"
      echo "Disable Email Obfuscation (Page Speed Optimization)"
      echo "-------------------------------------------------"
      set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/email_obfuscation" \
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
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo "check setting"
          curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/email_obfuscation" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
        fi
      fi
      if [[ "$CF_ENABLE_CRAWLER_HINTS" = [yY] ]]; then
        if [[ "$cloudflare_crawler_hints" = 'yes' || "$cloudflare_crawler_hints" = [yY] ]]; then
          echo "-------------------------------------------------"
          echo "Enable CF Crawler Hints"
          echo "-------------------------------------------------"
          set=$(curl -s -X POST "${endpoint}zones/${cloudflare_zoneid}/flags/products/cache/changes" \
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
            if [[ "$DEBUG_MODE" = [yY] ]]; then
              echo "check setting"
              curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/flags/products/cache/changes" \
                  -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
            fi
          fi
        fi
      fi
      if [[ "$CF_ENABLE_CACHE_RESERVE" = [yY] ]]; then
        if [[ "$cloudflare_cache_reserve" = 'yes' || "$cloudflare_cache_reserve" = [yY] ]]; then
          echo "-------------------------------------------------"
          echo "Enable CF Cache Reserve"
          echo "-------------------------------------------------"
          set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/cache/cache_reserve" \
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
            curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/cache/cache_reserve" \
                  -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
          fi
        fi
      fi
      echo "-------------------------------------------------"
      echo "Enable HTTP Prioritization"
      echo "-------------------------------------------------"
      set=$(curl -s -X PATCH "${endpoint}zones/${cloudflare_zoneid}/settings/h2_prioritization" \
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
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo "check setting"
          curl -s -X GET "${endpoint}zones/${cloudflare_zoneid}/settings/h2_prioritization" \
              -H "Authorization: Bearer $cloudflare_api_token" -H "Content-Type: application/json" | jq
        fi
      fi
    else
      echo
      echo "$cloudflare_zoneid and $cloudflare_api_token not set"
    fi # check if $cloudflare_api_token and $cloudflare_zoneid set
  fi # cloudflare=yes
  # only run Nginx vhost creation if the domain doesn't already exist
  if [[ ! -d "/home/nginx/domains/${domain}" ]]; then
    if [[ "$domain_is_array_check"  -eq '0' ]]; then
      if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
        domain_name_label_nginx=$(echo "${domain_array_comma_list}" | sed -e "s|$domain|domain.com|g")
        domain_name_nginx=${domain_array_comma_list}
      else
        domain_name_label_nginx=${domain_array_comma_list}
        domain_name_nginx=${domain_array_comma_list}
      fi
    else
      domain_name_label_nginx=${domain_name_label}
      domain_name_nginx=${domain}
    fi
    echo
    echo "---------------------------------------------------------------------"
    if [[ "$domain_is_array_check"  -eq '0' ]]; then
      echo "Nginx Vhost Creation For: ${domain} with server_names:"
      echo "${domain_name_label_nginx}"
    else
      echo "Nginx Vhost Creation For: ${domain_name_label_nginx}"
    fi
    echo "---------------------------------------------------------------------"
    echo
    if [ -f /usr/bin/nv ]; then
      ftp_pass=$(pwgen -1cnys 29)
      if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
        ftp_pass_label=ftp_password
      else
        ftp_pass_label=$ftp_pass
      fi
      if [[ "$https" = 'yes' || "$https" = [yY] ]] && [[ "$origin_sslcert" = 'letsencrypt' || "$origin_sslcert" = 'zerossl' || "$origin_sslcert" = 'google' ]]; then
        # browser trusted SSL certs from letsencrypt, zerossl, google CA
        ngx_ssl_ca=lived
      elif [[ "$https" = 'yes' || "$https" = [yY] ]]; then
        # self-signed SSL certificate
        ngx_ssl_ca=y
      fi
      # echo "creating vhost ${domain_name_label_nginx}"
      # echo
      if [[ "$https" = 'yes' || "$https" = [yY] ]]; then
        # echo "/usr/bin/nv -d ${domain_name_label_nginx} -s $ngx_ssl_ca -u $ftp_pass_label"
        # /usr/bin/nv -d $domain_name_nginx -s $ngx_ssl_ca -u $ftp_pass
        echo "/usr/local/src/centminmod/addons/acmetool.sh issue $domain_name_label_nginx lived"
        # /usr/local/src/centminmod/addons/acmetool.sh issue $domain_name_nginx lived
      else
        echo "/usr/bin/nv -d ${domain_name_label_nginx} -s n -u $ftp_pass_label"
        # /usr/bin/nv -d $domain_name_nginx -s n -u $ftp_pass
      fi
      # enable cloudflare.conf include file
      if [[ "$cloudflare" = 'yes' || "$cloudflare" = [yY] ]] && [[ -f "/usr/local/nginx/conf/conf.d/$domain.conf" ]]; then
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo
          echo "enable cloudflare.conf include file in /usr/local/nginx/conf/conf.d/${domain_name_label}.conf"
          sed -i 's|#include \/usr\/local\/nginx\/conf\/cloudflare.conf|include \/usr\/local\/nginx\/conf\/cloudflare.conf|' "/usr/local/nginx/conf/conf.d/$domain.conf"
        else
          sed -i 's|#include \/usr\/local\/nginx\/conf\/cloudflare.conf|include \/usr\/local\/nginx\/conf\/cloudflare.conf|' "/usr/local/nginx/conf/conf.d/$domain.conf"
        fi
      fi
      if [[ "$cloudflare" = 'yes' || "$cloudflare" = [yY] ]] && [[ -f "/usr/local/nginx/conf/conf.d/$domain.ssl.conf" ]]; then
        if [[ "$DEBUG_MODE" = [yY] ]]; then
          echo
          echo "enable cloudflare.conf include file in /usr/local/nginx/conf/conf.d/${domain_name_label}.ssl.conf"
          sed -i 's|#include \/usr\/local\/nginx\/conf\/cloudflare.conf|include \/usr\/local\/nginx\/conf\/cloudflare.conf|' "/usr/local/nginx/conf/conf.d/$domain.ssl.conf"
        else
          sed -i 's|#include \/usr\/local\/nginx\/conf\/cloudflare.conf|include \/usr\/local\/nginx\/conf\/cloudflare.conf|' "/usr/local/nginx/conf/conf.d/$domain.ssl.conf"
        fi
      fi
      ngxreload >/dev/null 2>&1
    fi # nginx vhost creation
    #
    if [[ "$get_cf_dnsapi_global" && "$get_cf_token" && "$get_cf_account_id" && -f /etc/centminmod/acmetool-config.ini && -f /etc/centminmod/cf-dns-api-nvjson.ini ]]; then
      # remove CF DNS API acmetool.sh credentials after run
      sed -i '/^CF_DNSAPI_GLOBAL/d' /etc/centminmod/acmetool-config.ini
      sed -i '/^CF_Token/d' /etc/centminmod/acmetool-config.ini
      sed -i '/^CF_Account_ID/d' /etc/centminmod/acmetool-config.ini
      # restore previous detected credentials
      cat /etc/centminmod/cf-dns-api-nvjson.ini >> /etc/centminmod/acmetool-config.ini
    fi
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Create MySSQL Databases For: ${domain_name_label}"
  echo "---------------------------------------------------------------------"
  echo
  if [ -f /usr/local/src/centminmod/addons/mysqladmin_shell.sh ]; then
    echo "$database_array_user_pairs" | while read d u p; do
      dbname=${d}
      dbuser=${u}
      dbpass=${p}
      if [[ "$DEBUG_MODE" = [yY] ]]; then
        echo "Debug mode check:"
        echo "dbname=${dbname}"
        echo "dbuser=${dbuser}"
        echo "dbpass=${dbpass}"
        echo
      fi
      if [[ "${dbname}" && "${dbuser}" && "${dbpass}" ]]; then
        echo "/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb $dbname $dbuser $dbpass"
        echo
      fi
    done
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Robots.txt File For: ${domain_name_label}"
  echo "---------------------------------------------------------------------"
  if [[ -f "$robotsfile" || "$DEBUG_MODE" = [yY] ]]; then
    echo
    # echo "copying $robotsfile to ${webroot}/robots.txt"
    if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
      echo "\cp -af $robotsfile ${webroot}/robots.txt" | sed -e "s|${domain}|domain.com|g"
    else
      echo "\cp -af $robotsfile ${webroot}/robots.txt"
    fi
  fi
  echo
  echo "---------------------------------------------------------------------"
  echo "Setup Cronjobs For: ${domain_name_label}"
  echo "---------------------------------------------------------------------"
  if [[ -f "$cronjobfile" || "$DEBUG_MODE" = [yY] ]]; then
    echo
    echo "setup $cronjobfile"
    echo "mkdir -p /etc/centminmod/cronjobs/"
    if [[ "$SENSITIVE_INFO_MASK" = [yY] ]]; then
      echo "crontab -l > \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\"" | sed -e "s|$domain|domain.com|g"
      echo "cat \"$cronjobfile\" >> \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\"" | sed -e "s|$domain|domain.com|g"
      echo "crontab \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\"" | sed -e "s|$domain|domain.com|g"
      # mkdir -p /etc/centminmod/cronjobs/
      # crontab -l > "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
      # cat "$cronjobfile" >> "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
      # crontab "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
    else
      echo "crontab -l > \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\""
      echo "cat \"$cronjobfile\" >> \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\""
      echo "crontab \"/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt\""
      # mkdir -p /etc/centminmod/cronjobs/
      # crontab -l > "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
      # cat "$cronjobfile" >> "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
      # crontab "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-${domain}-setup-${DT}.txt"
    fi
  fi
  echo
  echo
}

help() {
  echo
  echo "Usage:"
  echo
  echo "$0 create vhost-config.json"
  echo "$0 create vhost-config.json domain.com"
}

case "$1" in
  create )
    create_vhost "$2" "$3"
    ;;
  * )
    help
    ;;
esac