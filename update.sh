#!/bin/bash

# Parse YAML file using awk
parse_yaml() {
  local yaml_file=$1
  awk '/^[^ ]+: / {key=$1; sub(":", "", key); value=""; next} /^ / {value=value $0 "\n"} /^[^ ]/ {sub(/^ */, ""); value=value $0 "\n"; map[key]=value} END {for (key in map) print key"="map[key]}' "$yaml_file"
}

# Function to update Cloudflare DNS record
update_cloudflare_dns() {
  local yaml_file=$1

  # Read values from the YAML file
  declare -A yaml_values
  while IFS='=' read -r key value; do
    yaml_values[$key]=$value
  done < <(parse_yaml "$yaml_file")

  # Extract relevant values
  local email=${yaml_values["email"]}
  local api_key=${yaml_values["api_key"]}
  local zone_id=${yaml_values["zone_id"]}
  local record_name=${yaml_values["record_name"]}
  local record_value=${yaml_values["record_value"]}

  # Update DNS record using Cloudflare API
  local response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_name" \
                    -H "Content-Type: application/json" \
                    -H "X-Auth-Email: $email" \
                    -H "X-Auth-Key: $api_key" \
                    --data "{\"content\":\"$record_value\"}")

  # Parse response and check if the update was successful
  local success=$(echo "$response" | grep -Po '"success":\s*\K[^,\{]*')

  if [[ "$success" == "true" ]]; then
    echo "DNS record updated successfully"
  else
    local error_message=$(echo "$response" | grep -Po '"message":\s*"\K[^"]*')
    echo "Failed to update DNS record: $error_message"
  fi
}

# Check if YAML file argument is provided
if [[ -z "$1" ]]; then
  echo "YAML file argument is missing"
  exit 1
fi

# Check if the specified YAML file exists
if [[ ! -f "$1" ]]; then
  echo "Unable to find the specified YAML file"
  exit 1
fi

# Update the Cloudflare DNS record
update_cloudflare_dns "$1"

