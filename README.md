# Cloudflare DNS updater

A bash script to automate DNS record updating. Set up as a cron job and it will update the DNS records you specify to the current external IP of the server, or a user-specified IP.

## Usage

```bash
# to update your domain name(s) configured in example.com.yaml, using the external IP of the server
update.sh example.com.yaml

# update your domain name(s) to a specified ip
update.sh example.com.yaml 192.168.1.1
```

## Automation

Set up a cronjob that runs the script as oftens as you'd like by running `crontab -e` and adding:

```bash
# updating dns record every hour
0 * * * * ~/cloudflare_dns_update/update.sh ~/cloudflare_dns_update/example.com.yaml
```

## Configuration

You need to create a YAML file with the credentials to update the DNS with the following format:

```yaml
api_token:   Itr7Q9HNVFwXGF80c40mLyGdKatRES-3BIAMMnIH7YZCIqpWJWQd0zqfRH-QjquQ
zone_id:     d8a3bb379ea3ce407586a5046ef305a1
record_name: example.com
record_type: A # Optional, defaults to "A"
```

#### API Token creation
You need to create an API token that has access to edit the DNS setting for the domain you want to update. Go to `Manage Account - Account API Tokens` in the [Cloudflare web interface](https://dash.cloudflare.com). Select `Create new token`, use the `Edit zone DNS` template, select which zone should be authorized under `Zone Resources`, and then click `Continue to summary` and create the token. Copy the created token and put in the YAML file.

#### Finding Zone ID

Login to the [Cloudflare web interface](https://dash.cloudflare.com) and select the domain you want to update records for. Now you should have a sidebar on the right-hand side where you can see thing like `Zone ID` and `Account ID`. Copy the `Zone ID` and put it in the YAML file.

#### Record Name and Type

The **record name** is the domain name you want to update, e.g. `example.com`, `sub.example.com` or `*.example.com`. If you want to update multiple domains at the same time you can just comma-separate them, e.g.

```bash
record_name: example.com, www.example.com, sub.example.com, *.example.com
```

It should probably work to update many different root domains, given that your API token has access to them (`example.com, sub.test.nu, *.example.org`)

The **record type** is whatever the record you have should be, e.g. `A` for ip addresses, `CNAME` for other DNS names.

It works to update `TXT` (and probably other types as well), by giving the content of the record as the 2nd argument to the script, e.g.

```bash
# txt.example.com:
#   api_token:   Itr7Q9HNVFwXGF80c40mLyGdKatRES-3BIAMMnIH7YZCIqpWJWQd0zqfRH-QjquQ
#   zone_id:     d8a3bb379ea3ce407586a5046ef305a1
#   record_name: _github-pages-challenge-test.test.example.com
#   record_type: TXT # Optional, defaults to "A"


./update.sh txt.example.com "f7a02def4ff9ad860dfd7080beb44f4f"
```


