#!/bin/bash

# Check if the folder path argument is provided
if [[ -z "$1" ]]; then
  echo "Folder path argument is missing"
  exit 1
fi

# Get the absolute path to the wrapper script
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)

# Get the absolute path to the cloudflare_dns_update.sh script
update_script="$script_dir/cloudflare_dns_update.sh"

# Check if the specified folder exists
if [[ ! -d "$1" ]]; then
  echo "Invalid folder path: $1"
  exit 1
fi

# Iterate over each YAML file in the folder
for yaml_file in "$1"/*.yaml; do
  echo "Updating DNS record using $yaml_file"
  "$update_script" "$yaml_file"
  echo "-----------------------------"
done

