A work in progress experimental method for creating new Centmin Mod Nginx vhost sites with Cloudflare API Token for quicker setup of Centmin Mod Nginx vhost sites behind Cloudflare CDN Proxy. Not fully working yet, so do not use for production live sites.

# Cloudflare API Token

For Cloudflare settings and DNS configuration, you'll need to use Cloudflare API. Cloudflare API, requires you to create your Cloudflare Token API with permissions for edit access to `Zone.Zone`, `Zone.DNS`, `Zone.Zone Settings` and `Zone.Cache Settings` across all Zones at https://dash.cloudflare.com/profile/api-tokens and to grab your Cloudflare Account ID from any of your Cloudflare domain's main dashboard's right side column listing.

# nvjson.sh

The `nvjson.sh` tool takes input from a `vhost-config.json` JSON formatted config file that users can create for their relevant Centmin Mod Nginx vhost + Cloudflare settings. 

`nvjson.sh` differs from existing Centmin Mod `nv` command line tool for Centmin Mod Nginx vhost creation in that it:

* supports additional options for optimal Cloudflare CDN proxy configuration and Cloudflare DNS record setup via Cloudflare API 
* better supports adding parked domain names to Centmin Mod Nginx vhost 
* supports automatically creating user defined MySQL database name/database users/database user passwords
* as well as optionally support cronjob and robots.txt file setup.

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
---------------------------------------------------------------------
Variable checks:
---------------------------------------------------------------------
cfplan=free
domain=domain.com
domain_www=www.domain.com
domain_preferred=domain.com-preferred
domain_parked1=domain.com-parked1
domain_parked2=domain.com-parked2
domain_parked3=domain.com-parked3
email=email@domain
https=yes
origin_sslcert=-sslcert
cloudflare=yes
cloudflare_accountid=yes-accountid
cloudflare_zoneid=yes-zoneid
cloudflare_api_token=yes-api-token
cloudflare_min_tls=yes-min-tls
cloudflare_tiered_cache=yes-tiered-cache
cloudflare_cache_reserve=yes-cache-reserve
cloudflare_crawler_hints=yes-crawler-hints
cloudflare_respect_origin_headers=yes-respect-origin-headers
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

CF_DNSAPI_GLOBAL='y'
CF_Token="CF_API_TOKEN"
CF_Account_ID="CF_ACCOUNTID"


---------------------------------------------------------------------
Setup Cloudflare DNS A For: domain.com (CF free plan)
---------------------------------------------------------------------

---------------------------------------------------------------------
backed up Cloudflare Zone Bind File at:
---------------------------------------------------------------------
/etc/cfapi/backup-zone-bind/cf-zone-bind-export-domain.com-140622-052930.txt
---------------------------------------------------------------------

success: create DNS A record succeeded
{
  "result": {
    "id": "90adb5d5122aea41c8a0d345f916520c",
    "zone_id": "CF_ZONEID",
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
      "managed_by_argo_tunnel": false,
      "source": "primary"
    },
    "created_on": "2022-06-14T05:29:32.808626Z",
    "modified_on": "2022-06-14T05:29:32.808626Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
detected AAAA record for domain.com
removing AAAA record for domain.com
{
  "result": {
    "id": "55cffee0e70285c4f684c80210af8ee4"
  },
  "success": true,
  "errors": [],
  "messages": []
}
success: create DNS A record succeeded
{
  "result": {
    "id": "ad2abc16f23c561c5e2a37983b91d4f4",
    "zone_id": "CF_ZONEID",
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
      "managed_by_argo_tunnel": false,
      "source": "primary"
    },
    "created_on": "2022-06-14T05:29:33.697751Z",
    "modified_on": "2022-06-14T05:29:33.697751Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
detected AAAA record for sub1.domain.com
removing AAAA record for sub1.domain.com
{
  "result": {
    "id": "3a9e0211bfef8e65b6a9c4c18a2da9d5"
  },
  "success": true,
  "errors": [],
  "messages": []
}
success: create DNS A record succeeded
{
  "result": {
    "id": "9d26b7ebe1d9a02f209733e43f598ed4",
    "zone_id": "CF_ZONEID",
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
      "managed_by_argo_tunnel": false,
      "source": "primary"
    },
    "created_on": "2022-06-14T05:29:34.887328Z",
    "modified_on": "2022-06-14T05:29:34.887328Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
detected AAAA record for sub2.domain.com
removing AAAA record for sub2.domain.com
{
  "result": {
    "id": "f2080b74eaf73f71b9ab40add8f3cab6"
  },
  "success": true,
  "errors": [],
  "messages": []
}
success: create DNS A record succeeded
{
  "result": {
    "id": "499b8b34aaf8c652f36cdfaa0c39267e",
    "zone_id": "CF_ZONEID",
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
      "managed_by_argo_tunnel": false,
      "source": "primary"
    },
    "created_on": "2022-06-14T05:29:35.788126Z",
    "modified_on": "2022-06-14T05:29:35.788126Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
detected AAAA record for sub3.domain.com
removing AAAA record for sub3.domain.com
{
  "result": {
    "id": "43072b25d9c40cf6c40369ee5f7d8582"
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
Set CF Minimum TLSv1.2 Version
-------------------------------------------------
ok: CF API command succeeded.

{
  "result": {
    "id": "min_tls_version",
    "value": "1.2",
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
    "id": "min_tls_version",
    "value": "1.2",
    "modified_on": null,
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
Nginx Vhost Creation For: domain.com
---------------------------------------------------------------------

creating vhost domain.com...

/usr/bin/nv -d domain.com -s lelived -u }/f~1;"F_LLs]Z(Fzz(Bx7AU(bp"6

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
crontab -l > "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-domain.com-setup-140622-052930.txt"
cat "/path/to/cronjobfile.txt" >> "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-domain.com-setup-140622-052930.txt"
crontab "/etc/centminmod/cronjobs/nvjson-cronjoblist-before-domain.com-setup-140622-052930.txt"
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