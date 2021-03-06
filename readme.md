A work in progress experimental method for creating new Centmin Mod Nginx vhost sites with Cloudflare API Token for quicker setup of Centmin Mod Nginx vhost sites behind Cloudflare CDN Proxy. Not fully working yet, so do not use for production live sites.

# Cloudflare API Token

For Cloudflare settings and DNS configuration, you'll need to use Cloudflare API. Cloudflare API, requires you to create your Cloudflare Token API with permissions for edit access to `Zone.Zone`, `Zone.DNS`, `Zone.Zone Settings` and `Zone.Cache Settings` across all Zones at https://dash.cloudflare.com/profile/api-tokens and to grab your Cloudflare Account ID from any of your Cloudflare domain's main dashboard's right side column listing.

![CF API Token Permissions](/screenshots/nvjson-api-token-permissions-01.png)

# nvjson.sh

The `nvjson.sh` tool takes input from a `vhost-config.json` JSON formatted config file that users can create for their relevant Centmin Mod Nginx vhost + Cloudflare settings. 

`nvjson.sh` differs from existing Centmin Mod `nv` command line tool for Centmin Mod Nginx vhost creation in that it:

* supports additional options for optimal Cloudflare CDN proxy configuration and Cloudflare DNS record setup via Cloudflare API 
* better supports adding parked domain names to Centmin Mod Nginx vhost 
* supports automatically creating user defined MySQL database name/database users/database user passwords
* as well as optionally support cronjob and robots.txt file setup.
* when `SENSITIVE_INFO_MASK='y'` enabled (by default), output for sensitive info is masked i.e. CF ZoneID, DNS A/AAAA record real server IP address and actual domain name. This allows sharing the info publicly on forums etc for troubleshooting. Set `SENSITIVE_INFO_MASK='n'` will disable the unmasked real info.

Example run with `DEBUG_MODE='y'` enabled for displaying and checking parsed JSON key/values and assigned variables.

```
./nvjson.sh create vhost-config.json

---------------------------------------------------------------------
Debug Mode Output:
---------------------------------------------------------------------
parsed vhost config file output
{
  "domain": "domain.com",
  "domain-www": "www.domain.com",
  "domain-preferred": "www.domain.com",
  "domain-parked1": "sub1.domain.com",
  "domain-parked2": "sub2.domain.com",
  "domain-parked3": "sub3.domain.com",
  "email": "email@domain",
  "https": "yes",
  "origin-sslcert": "letsencrypt",
  "cloudflare": "yes",
  "cloudflare-accountid": "CF_ACCOUNT_ID",
  "cloudflare-zoneid": "CF_ZONE_ID",
  "cloudflare-api-token": "CF_API_TOKEN",
  "cloudflare-min-tls": "1.2",
  "cloudflare-tiered-cache": "yes",
  "cloudflare-cache-reserve": "yes",
  "cloudflare-crawler-hints": "yes",
  "cloudflare-respect-origin-headers": "yes",
  "type": "site",
  "mysqldb1": "db1",
  "mysqluser1": "dbuser1",
  "mysqlpass1": "dbpass1",
  "mysqldb2": "db2",
  "mysqluser2": "dbuser2",
  "mysqlpass2": "dbpass2",
  "mysqldb3": "db3",
  "mysqluser3": "dbuser3",
  "mysqlpass3": "dbpass3",
  "mysqldb4": "db4",
  "mysqluser4": "dbuser4",
  "mysqlpass4": "dbpass4",
  "mysqldb5": "db5",
  "mysqluser5": "dbuser5",
  "mysqlpass5": "dbpass5",
  "webroot": "/home/nginx/domains/domain.com/public",
  "index": "/home/nginx/domains/domain.com/public/index.html",
  "robotsfile": "/path/to/robots.txt",
  "cronjobfile": "/path/to/cronjobfile.txt"
}
---------------------------------------------------------------------
Variable checks:
---------------------------------------------------------------------
cfplan=free
domain=domain.com
domain_www=www.domain.com
domain_preferred=www.domain.com
domain_parked1=sub1.domain.com
domain_parked2=sub2.domain.com
domain_parked3=sub3.domain.com
domain_parked4=null
domain_parked5=null
domain_parked6=null
email=email@domain
https=yes
origin_sslcert=sslcert
cloudflare=yes
cloudflare_accountid=yes
cloudflare_zoneid=yes
cloudflare_api_token=yes
cloudflare_min_tls=yes
cloudflare_tiered_cache=yes
cloudflare_cache_reserve=yes
cloudflare_crawler_hints=yes
cloudflare_respect_origin_headers=yes
type=site
mysqldb1=db1
mysqluser1=dbuser1
mysqlpass1=dbpass1
mysqldb2=db2
mysqluser2=dbuser2
mysqlpass2=dbpass2
mysqldb3=db3
mysqluser3=dbuser3
mysqlpass3=dbpass3
mysqldb4=db4
mysqluser4=dbuser4
mysqlpass4=dbpass4
mysqldb5=db5
mysqluser5=dbuser5
mysqlpass5=dbpass5
webroot=/home/nginx/domains/domain.com/public
index=/home/nginx/domains/domain.com/public/index.html
robotsfile=/path/to/robots.txt
cronjobfile=/path/to/cronjobfile.txt
---------------------------------------------------------------------

---------------------------------------------------------------------
Check Cloudflare API Token For: domain.com
---------------------------------------------------------------------

curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer CF_API_TOKEN" \
     -H "Content-Type:application/json"
{
  "result": {
    "id": "bd076a61e7a57bd623089fde53011490",
    "status": "active"
  },
  "success": true,
  "errors": [],
  "messages": [
    {
      "code": 10000,
      "message": "This API Token is valid and active",
      "type": null
    }
  ]
}

---------------------------------------------------------------------
Setup Cloudflare DNS API Token For: domain.com (CF free plan)
---------------------------------------------------------------------

configured /etc/centminmod/acmetool-config.ini
CF_DNSAPI_GLOBAL='y'
CF_Token="CF_API_TOKEN"
CF_Account_ID="CF_ACCOUNT_ID"


---------------------------------------------------------------------
Setup Cloudflare DNS A For: domain.com (CF free plan)
---------------------------------------------------------------------

---------------------------------------------------------------------
backed up Cloudflare Zone Bind File at:
---------------------------------------------------------------------
/etc/cfapi/backup-zone-bind/cf-zone-bind-export-domain.com-160622-102858.txt
---------------------------------------------------------------------

success: update DNS A record succeeded
{
  "result": {
    "id": "90adb5d5122aea41c8a0d345f916520c",
    "zone_id": "CF_ZONE_ID",
    "zone_name": "domain.com",
    "name": "domain.com",
    "type": "A",
    "content": "111.222.333.444",
    "proxiable": true,
    "proxied": true,
    "ttl": 1,
    "locked": false,
    "meta": {
      "auto_added": false,
      "managed_by_apps": false,
      "managed_by_argo_tunnel": false
    },
    "created_on": "2022-06-14T05:29:32.808626Z",
    "modified_on": "2022-06-14T05:29:32.808626Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
success: update DNS A record succeeded
{
  "result": {
    "id": "ad2abc16f23c561c5e2a37983b91d4f4",
    "zone_id": "CF_ZONE_ID",
    "zone_name": "domain.com",
    "name": "sub1.domain.com",
    "type": "A",
    "content": "111.222.333.444",
    "proxiable": true,
    "proxied": true,
    "ttl": 1,
    "locked": false,
    "meta": {
      "auto_added": false,
      "managed_by_apps": false,
      "managed_by_argo_tunnel": false
    },
    "created_on": "2022-06-14T05:29:33.697751Z",
    "modified_on": "2022-06-14T05:29:33.697751Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
success: update DNS A record succeeded
{
  "result": {
    "id": "9d26b7ebe1d9a02f209733e43f598ed4",
    "zone_id": "CF_ZONE_ID",
    "zone_name": "domain.com",
    "name": "sub2.domain.com",
    "type": "A",
    "content": "111.222.333.444",
    "proxiable": true,
    "proxied": true,
    "ttl": 1,
    "locked": false,
    "meta": {
      "auto_added": false,
      "managed_by_apps": false,
      "managed_by_argo_tunnel": false
    },
    "created_on": "2022-06-14T05:29:34.887328Z",
    "modified_on": "2022-06-14T05:29:34.887328Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
success: update DNS A record succeeded
{
  "result": {
    "id": "499b8b34aaf8c652f36cdfaa0c39267e",
    "zone_id": "CF_ZONE_ID",
    "zone_name": "domain.com",
    "name": "sub3.domain.com",
    "type": "A",
    "content": "111.222.333.444",
    "proxiable": true,
    "proxied": true,
    "ttl": 1,
    "locked": false,
    "meta": {
      "auto_added": false,
      "managed_by_apps": false,
      "managed_by_argo_tunnel": false
    },
    "created_on": "2022-06-14T05:29:35.788126Z",
    "modified_on": "2022-06-14T05:29:35.788126Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}

---------------------------------------------------------------------
Adjust Cloudflare Settings For: domain.com
---------------------------------------------------------------------

-------------------------------------------------
Set CF SSL Mode To Full SSL
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "ssl",
    "value": "full",
    "modified_on": "2022-06-13T15:48:43.563831Z",
    "certificate_status": "active",
    "validation_errors": [],
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}

check setting
{
  "result": {
    "id": "ssl",
    "value": "full",
    "modified_on": "2022-06-13T15:48:43.563831Z",
    "certificate_status": "active",
    "validation_errors": [],
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}
-------------------------------------------------
Set CF Always Use HTTPS Off
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "always_use_https",
    "value": "off",
    "modified_on": null,
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}

check setting
{
  "result": {
    "id": "always_use_https",
    "value": "off",
    "modified_on": null,
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}
-------------------------------------------------
Set CF Automatic HTTPS Rewrites Off
-------------------------------------------------
-------------------------------------------------
Enable CF Tiered Caching
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "tiered_caching",
    "value": "on",
    "modified_on": "2022-02-15T04:07:24.309384Z",
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}

check setting
{
  "result": {
    "id": "tiered_caching",
    "value": "on",
    "modified_on": "2022-02-15T04:07:24.309384Z",
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}
-------------------------------------------------
Set CF Browser Cache TTL = Respect Origin Headers
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "browser_cache_ttl",
    "value": 0,
    "modified_on": "2022-06-13T15:48:44.879725Z",
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}

check setting
{
  "result": {
    "id": "browser_cache_ttl",
    "value": 0,
    "modified_on": "2022-06-13T15:48:44.879725Z",
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}
-------------------------------------------------
Disable Email Obfuscation (Page Speed Optimization)
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "email_obfuscation",
    "value": "off",
    "modified_on": "2022-06-13T15:48:45.798810Z",
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}

check setting
{
  "result": {
    "id": "email_obfuscation",
    "value": "off",
    "modified_on": "2022-06-13T15:48:45.798810Z",
    "editable": true
  },
  "success": true,
  "errors": [],
  "messages": []
}
-------------------------------------------------
Enable HTTP Prioritization
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "h2_prioritization",
    "editable": true,
    "value": "on",
    "modified_on": null
  },
  "success": true,
  "errors": [],
  "messages": []
}

check setting
{
  "result": {
    "id": "h2_prioritization",
    "editable": true,
    "value": "on",
    "modified_on": null
  },
  "success": true,
  "errors": [],
  "messages": []
}

---------------------------------------------------------------------
Nginx Vhost Creation For: domain.com with server_names:
domain.com,sub1.domain.com,sub2.domain.com,sub3.domain.com
---------------------------------------------------------------------

/usr/local/src/centminmod/addons/acmetool.sh issue domain.com,sub1.domain.com,sub2.domain.com,sub3.domain.com lived

---------------------------------------------------------------------
Create MySSQL Databases For: domain.com
---------------------------------------------------------------------

Debug mode check:
dbname=db1
dbuser=dbuser1
dbpass=dbpass1

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db1 dbuser1 dbpass1

Debug mode check:
dbname=db2
dbuser=dbuser2
dbpass=dbpass2

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db2 dbuser2 dbpass2

Debug mode check:
dbname=db3
dbuser=dbuser3
dbpass=dbpass3

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db3 dbuser3 dbpass3

Debug mode check:
dbname=db4
dbuser=dbuser4
dbpass=dbpass4

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db4 dbuser4 dbpass4

Debug mode check:
dbname=db5
dbuser=dbuser5
dbpass=dbpass5

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db5 dbuser5 dbpass5


---------------------------------------------------------------------
Setup Robots.txt File For: domain.com
---------------------------------------------------------------------

\cp -af /path/to/robots.txt /home/nginx/domains/domain.com/public/robots.txt

---------------------------------------------------------------------
Setup Cronjobs For: domain.com
---------------------------------------------------------------------

setup /path/to/cronjobfile.txt
mkdir -p /etc/centminmod/cronjobs/
crontab -l > "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-domain.com-setup-160622-102858.txt"
cat "/path/to/cronjobfile.txt" >> "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-domain.com-setup-160622-102858.txt"
crontab "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-domain.com-setup-160622-102858.txt"
```

From above example run output, you can see the Centmin Mod Nginx vhost is created using `addons/acmetool.sh` Letsencrypt SSL wrapper script for underlying [acme.sh](https://acme.sh) client and supports passing the additional SAN domain names and Nginx parked domain names for SSL certificate issuance and Nginx vhost creation.

```
---------------------------------------------------------------------
Nginx Vhost Creation For: domain.com with server_names:
domain.com,sub1.domain.com,sub2.domain.com,sub3.domain.com
---------------------------------------------------------------------

/usr/local/src/centminmod/addons/acmetool.sh issue domain.com,sub1.domain.com,sub2.domain.com,sub3.domain.com lived
```

Also each listed database name, database user/pass entries in vhost JSON config file is also processed using `addons/mysqladmin_shell.sh` tool.

```
---------------------------------------------------------------------
Create MySSQL Databases For: domain.com
---------------------------------------------------------------------

Debug mode check:
dbname=db1
dbuser=dbuser1
dbpass=dbpass1

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db1 dbuser1 dbpass1

Debug mode check:
dbname=db2
dbuser=dbuser2
dbpass=dbpass2

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db2 dbuser2 dbpass2

Debug mode check:
dbname=db3
dbuser=dbuser3
dbpass=dbpass3

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db3 dbuser3 dbpass3

Debug mode check:
dbname=db4
dbuser=dbuser4
dbpass=dbpass4

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db4 dbuser4 dbpass4

Debug mode check:
dbname=db5
dbuser=dbuser5
dbpass=dbpass5

/usr/local/src/centminmod/addons/mysqladmin_shell.sh createuserdb db5 dbuser5 dbpass5
```

# JSON Format Vhost Config File

The `vhost-config.json` JSON formatted config.

```json
{
    "data": [
        {
            "domain": "domain.com",
            "domain-www": "www.domain.com",
            "domain-preferred": "www.domain.com",
            "domain-parked1": "sub1.domain.com",
            "domain-parked2": "sub2.domain.com",
            "domain-parked3": "sub3.domain.com",
            "email": "email@domain",
            "https": "yes",
            "origin-sslcert": "letsencrypt",
            "cloudflare": "yes",
            "cloudflare-accountid": "CF_ACCOUNTID",
            "cloudflare-zoneid": "CF_ZONEID",
            "cloudflare-api-token": "CF_API_TOKEN",
            "cloudflare-min-tls": "1.2",
            "cloudflare-tiered-cache": "yes",
            "cloudflare-cache-reserve": "yes",
            "cloudflare-crawler-hints": "yes",
            "cloudflare-respect-origin-headers": "yes",
            "type": "site",
            "mysqldb1": "db1",
            "mysqluser1": "dbuser1",
            "mysqlpass1": "dbpass1",
            "mysqldb2": "db2",
            "mysqluser2": "dbuser2",
            "mysqlpass2": "dbpass2",
            "mysqldb3": "db3",
            "mysqluser3": "dbuser3",
            "mysqlpass3": "dbpass3",
            "mysqldb4": "db4",
            "mysqluser4": "dbuser4",
            "mysqlpass4": "dbpass4",
            "mysqldb5": "db5",
            "mysqluser5": "dbuser5",
            "mysqlpass5": "dbpass5",
            "webroot": "/home/nginx/domains/domain.com/public",
            "index": "/home/nginx/domains/domain.com/public/index.html",
            "robotsfile": "/path/to/robots.txt",
            "cronjobfile": "/path/to/cronjobfile.txt"
        }
    ]
}
```