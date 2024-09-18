#!/bin/bash

# Function to extract value for a specific key from the YAML file
get_yaml_value() {
  local yaml_file="$1"
  local yaml_key="$2"
  
  # Extract the value corresponding to the key
  awk -F ": " "/^$yaml_key: /{print \$2}" "$yaml_file" | tr -d '\"'
}

# Function to fetch record ID and update DNS record for each domain
update_cloudflare_dns() {
  local yaml_file=$1
  local override_ip=$2
  
  # Read configuration from YAML
  local api_key=$(get_yaml_value "$yaml_file" "api_key")
  local zone_id=$(get_yaml_value "$yaml_file" "zone_id")
  local record_names=$(get_yaml_value "$yaml_file" "record_name") # Multiple domains stored here
  local record_value=$(get_yaml_value "$yaml_file" "record_value")

  # If an override IP is provided, use it instead of the IP address from the YAML file
  if [[ -n "$override_ip" ]]; then
    echo "Overriding the IP address with: $override_ip"
    record_value="$override_ip"
  fi

  # Split the list of record names using a comma as the separator
  IFS=',' read -r -a domains <<< "$record_names"

  # Loop over each domain in the list
  for record_name in "${domains[@]}"; do
    # Trim any unnecessary whitespaces
    record_name=$(echo "$record_name" | xargs)
    
    echo "Fetching DNS record ID for: $record_name"

    # Fetch the current DNS record's ID, including the type "A" record
    local get_record_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$record_name" \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json")
    
    # Extract the DNS record ID from the response
    local record_id=$(echo "$get_record_response" | grep -Po '"id":\s*"\K[^"]*')
    
    # Extract the current IP address of the A record
    local current_record_value=$(echo "$get_record_response" | grep -Po '"content":\s*"\K[^"]*')

    echo "[OK]     Current IP for $record_name is: $current_record_value"
    
    # Check if the current record value matches the desired IP address
    if [[ "$current_record_value" == "$record_value" ]]; then
      echo "[SKIP]   No update needed: DNS record $record_name is already set to $record_value."
    else
      echo "[UPDATE] Updating DNS record $record_name to $record_value with record ID: $record_id."

      # Perform PUT request to update the DNS record via its record ID
      local update_response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$record_value\",\"ttl\":120,\"proxied\":false}")

      # Check if the update was successful
      local success=$(echo "$update_response" | grep -Po '"success":\s*\Ktrue')

      if [[ "$success" == "true" ]]; then
        echo "[OK]     DNS record for $record_name updated successfully to $record_value."
      else
        # If failed, show the error message
        local error_message=$(echo "$update_response" | grep -Po '"message":\s*"\K[^"]*')
        echo "[FAIL]   Failed to update DNS record for $record_name: $error_message"
      fi
    fi
    
    echo "-----------------------------------------------"
  done
}

# Ensure a YAML file is provided as the first argument
if [[ -z "$1" ]]; then
  echo "Error: YAML file is missing."
  exit 1
fi

# Check if the YAML file exists
yaml_file="$1"
if [[ ! -f "$yaml_file" ]]; then
  echo "Error: Cannot find the YAML file: $yaml_file"
  exit 1
fi

# Optional: second argument for override IP address
override_ip="$2"

# If overriding IP, display a message
if [[ -n "$override_ip" ]]; then
  echo "Using override IP: $override_ip"
fi

# Call the function to update DNS records
update_cloudflare_dns "$yaml_file" "$override_ip"

