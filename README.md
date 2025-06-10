# Cloudflare DNS updater

A set of bash scripts to automatically update Cloudflare DNS records with your server's external IP address or a specified IP address.
                                                                                                                                  
## Features

- Update single or multiple DNS records from one YAML configuration file
- Automatic external IP detection or manual IP override
- Detailed progress reporting and error handling
- Support for different DNS record types (A, AAAA, etc.)
- Validates Cloudflare API credentials and zone access


## Usage

```bash                                                                                                                          
# Update using detected external IP
./update.sh config.yaml

# Update using specific IP address
./update.sh config.yaml 192.168.1.100
```

## Prerequisites

- `bash` shell
- `curl` command
- Cloudflare account with API token
- DNS records already created in Cloudflare (the script updates existing records)

## Setup 
 
### 1. Get your Cloudflare API Token 
 
1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/) → My Profile → API Tokens 
2. Click "Create Token" 
3. Use "Custom token" with these permissions: 
   - **Zone:Read** - for all zones (or specific zones) 
   - **Zone:Edit** - for all zones (or specific zones) 
4. Copy the generated token 
 
### 2. Get your Zone ID 
 
1. Go to your domain in the Cloudflare dashboard 
2. In the right sidebar, copy the "Zone ID" under the API section 

## Configuration

You need to create a YAML file with the credentials to update the DNS with the following format:

### Single Record Configuration

```yaml
api_token: "your_cloudflare_api_token_here"
zone_id: "your_zone_id_here"
record_name: "subdomain.example.com"
record_type: "A"  # Optional, defaults to "A"
```

### Multiple Records Configuration
                                                                                                                                 
```yaml
api_token: "your_cloudflare_api_token_here"
zone_id: "your_zone_id_here"
record_name: "subdomain1.example.com, subdomain2.example.com, www.example.com"
record_type: "A"  # Optional, defaults to "A"
```

It should probably work to update many different root domains, given that your API token has access to them (`example.com, sub.test.nu, *.example.org`)

### Other Record Types

The **record type** is whatever the record you have should be, e.g. `A` for ip addresses, `CNAME` for other DNS names.

It works to update `TXT` (and probably other types as well), by giving the content of the record as the 2nd argument to the script, e.g.

```bash
# config.yaml:
#   api_token:   Itr7Q9HNVFwXGF80c40mLyGdKatRES-3BIAMMnIH7YZCIqpWJWQd0zqfRH-QjquQ
#   zone_id:     d8a3bb379ea3ce407586a5046ef305a1
#   record_name: _github-pages-challenge-test.test.example.com
#   record_type: TXT # Optional, defaults to "A"

./update.sh config.yaml "f7a02def4ff9ad860dfd7080beb44f4f"
```

## Automation

Set up a cron job to automatically update your home server's DNS records:

```bash
# Edit crontab
crontab -e

# Add line to check every hour
0 * * * * /path/to/update.sh /path/to/config.yaml
```

## Error Handling

The scripts include comprehensive error handling for:

- Invalid API tokens or insufficient permissions
- Incorrect Zone IDs
- Non-existent DNS records
- Network connectivity issues
- Malformed YAML configuration files

Failed updates will display detailed error messages to help with troubleshooting.

## Security Notes

- Store your API tokens securely and limit their permissions
- Consider using environment variables instead of storing tokens in YAML files for production use
- The API token only needs Zone:Read and Zone:Edit permissions
- Regularly rotate your API tokens

## Troubleshooting

### "No route for that URI" Error
- Verify your Zone ID is correct
- Ensure your API token has the required permissions
- Check that the DNS record exists in Cloudflare

### "DNS record not found" Error                                                                                              
- Verify the record name matches exactly (including subdomain)
- Ensure the record type is correct (A, AAAA, etc.)
- Create the DNS record in Cloudflare dashboard first

### Permission Errors
- Verify API token has Zone:Read and Zone:Edit permissions
- Ensure the token has access to the specific zone
- Check token hasn't expired

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve these scripts.

## License

This project is open source. Feel free to use and modify as needed.
