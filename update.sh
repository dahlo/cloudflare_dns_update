#!/bin/bash

# update.sh - Update Cloudflare DNS record using YAML configuration
# Usage: ./update.sh <config.yaml> [override_ip]

set -e

# Check if required argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <config.yaml> [override_ip]"
    echo "  config.yaml: Path to YAML configuration file"
    echo "  override_ip: Optional IP address to use instead of detecting external IP"
    exit 1
fi

CONFIG_FILE="$1"
OVERRIDE_IP="$2"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found"
    exit 1
fi

echo "Starting Cloudflare DNS update process..."
echo "Configuration file: $CONFIG_FILE"

# Function to parse YAML (simple key: value pairs)
parse_yaml() {
    local file="$1"
    local key="$2"
    grep -E "^[[:space:]]*${key}[[:space:]]*:" "$file" | sed -E "s/^[[:space:]]*${key}[[:space:]]*:[[:space:]]*//" | sed 's/#.*//' | sed 's/[[:space:]]*$//' | tr -d '"'"'"
}

# Parse configuration from YAML
echo "Parsing configuration..."
API_TOKEN=$(parse_yaml "$CONFIG_FILE" "api_token")
ZONE_ID=$(parse_yaml "$CONFIG_FILE" "zone_id")
RECORD_NAMES_RAW=$(parse_yaml "$CONFIG_FILE" "record_name")
RECORD_TYPE=$(parse_yaml "$CONFIG_FILE" "record_type")

# Set default record type if not specified
if [ -z "$RECORD_TYPE" ]; then
    RECORD_TYPE="A"
fi

# Validate required fields
if [ -z "$API_TOKEN" ] || [ -z "$ZONE_ID" ] || [ -z "$RECORD_NAMES_RAW" ]; then
    echo "Error: Missing required configuration fields in $CONFIG_FILE"
    echo "Required fields: api_token, zone_id, record_name"
    exit 1
fi

# Parse comma-separated record names and trim whitespace
IFS=',' read -ra RECORD_NAMES <<< "$RECORD_NAMES_RAW"
for i in "${!RECORD_NAMES[@]}"; do
    RECORD_NAMES[i]=$(echo "${RECORD_NAMES[i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
done

echo "Record(s): ${RECORD_NAMES[*]} ($RECORD_TYPE)"
echo "Zone ID: $ZONE_ID"

# Determine IP address to use
if [ -n "$OVERRIDE_IP" ]; then
    IP_ADDRESS="$OVERRIDE_IP"
    echo "Using override IP: $IP_ADDRESS"
else
    echo "Detecting external IP address..."
    IP_ADDRESS=$(curl -s https://ipv4.icanhazip.com/ || curl -s https://api.ipify.org)
    if [ -z "$IP_ADDRESS" ]; then
        echo "Error: Failed to detect external IP address"
        exit 1
    fi
    echo "Detected IP: $IP_ADDRESS"
fi

# Validate Zone ID by checking if zone exists
echo "Validating Zone ID..."
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

if ! echo "$ZONE_RESPONSE" | grep -q '"success":true'; then
    echo "Error: Invalid Zone ID or API token permissions"
    echo "Zone validation response: $ZONE_RESPONSE"
    echo ""
    echo "Common issues:"
    echo "1. Zone ID is incorrect"
    echo "2. API token doesn't have Zone:Read permissions"
    echo "3. API token doesn't have access to this zone"
    exit 1
fi

ZONE_NAME=$(echo "$ZONE_RESPONSE" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Zone validated: $ZONE_NAME"

# Initialize counters for multiple records
TOTAL_RECORDS=${#RECORD_NAMES[@]}
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_RECORDS=()

echo "Processing $TOTAL_RECORDS record(s)..."
echo

# Process each record name
for RECORD_NAME in "${RECORD_NAMES[@]}"; do
    echo "Processing record: $RECORD_NAME"
    
    # Get existing DNS record
    echo "  Fetching current DNS record..."
    RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME&type=$RECORD_TYPE" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    # Check if API call was successful
    if ! echo "$RECORD_RESPONSE" | grep -q '"success":true'; then
        echo "  ✗ Error: Failed to fetch DNS record for $RECORD_NAME"
        echo "  Response: $RECORD_RESPONSE"
        echo ""
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_RECORDS+=("$RECORD_NAME")
        continue
    fi

    # Extract record ID and current IP
    RECORD_ID=$(echo "$RECORD_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    CURRENT_IP=$(echo "$RECORD_RESPONSE" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$RECORD_ID" ]; then
        echo "  ✗ Error: DNS record '$RECORD_NAME' not found"
        echo ""
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_RECORDS+=("$RECORD_NAME")
        continue
    fi

    echo "  Current IP in DNS: $CURRENT_IP"
    echo "  Target IP: $IP_ADDRESS"

    # Check if update is needed
    if [ "$CURRENT_IP" = "$IP_ADDRESS" ]; then
        echo "  ✓ DNS record is already up to date. No changes needed."
        echo ""
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        continue
    fi

    # Update DNS record
    echo "  Updating DNS record..."
    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$IP_ADDRESS\"}")

    # Check if update was successful
    if echo "$UPDATE_RESPONSE" | grep -q '"success":true'; then
        echo "  ✓ DNS record updated successfully!"
        echo "    $RECORD_NAME → $IP_ADDRESS"
        echo ""
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "  ✗ Error: Failed to update DNS record for $RECORD_NAME"
        echo "  Response: $UPDATE_RESPONSE"
        echo ""
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_RECORDS+=("$RECORD_NAME")
    fi
done

# Print summary
echo "Update process complete!"
echo "Summary:"
echo "  Total records processed: $TOTAL_RECORDS"
echo "  Successful updates: $SUCCESS_COUNT"
echo "  Failed updates: $FAILED_COUNT"

if [ $FAILED_COUNT -gt 0 ]; then
    echo
    echo "Failed records:"
    for failed_record in "${FAILED_RECORDS[@]}"; do
        echo "  - $failed_record"
    done
    exit 1
fi

echo
echo "All DNS records processed successfully!"
