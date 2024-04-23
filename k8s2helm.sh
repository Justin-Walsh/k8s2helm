#!/bin/bash

# Kubernetes version to check
k8s_version="1.16" 

# Helm documentation URL
compatibility_table_url="https://raw.githubusercontent.com/helm/helm-www/main/content/en/docs/topics/version_skew.md"

# Function to check if a version is within a version range (inclusive) without considering patch versions
is_version_within_range() {
    local version=$1
    local min_version=$2
    local max_version=$3

    # Sort versions numerically
    version=$(printf "%s\n%s\n%s\n" "$min_version" "$version" "$max_version" | sort -V | sed -n '2p')

    # Check if the sorted version is the specified version
    if [[ "$version" == "$1" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to loop down from a defined value and attempt to hit the GitHub API endpoint for each version
## This is kinda hacky, but the `releases` endpoint is massive
loop_down_versions() {
    local major_minor=$1
    local start_iteration=$2

    # Extract major and minor version
    local major=$(echo "$major_minor" | cut -d '.' -f 1)
    local minor=$(echo "$major_minor" | cut -d '.' -f 2)

    # Define the base URL for the GitHub API
    local base_url="https://api.github.com/repos/helm/helm/releases/tags/v"

    # Loop down from the defined value and attempt to hit the GitHub API endpoint for each version
    for ((i = start_iteration; i >= 0; i--)); do
        local version="${major}.${minor}.${i}"
        local url="${base_url}${version}"

        # Attempt to hit the GitHub API endpoint
        local response=$(curl -s -o /dev/null -w "%{http_code}" "$url")

        if [[ $response -eq 200 ]]; then
            echo "$version"
            break
        fi
	sleep 1
    done
}

# Fetch the Helm version compatibility table from the specified URL
compatibility_table=$(curl -s "$compatibility_table_url")

# Parse the compatibility table to find the highest compatible Helm version
highest_helm_version=""
while IFS= read -r line; do
    if [[ "$line" =~ ^\|[[:space:]]+[0-9] ]]; then
        # Extract Helm version and Kubernetes version range
        helm_version=$(echo "$line" | awk -F '|' '{print $2}' | tr -d '[:space:]' | sed 's/\.x$//')
        k8s_range=$(echo "$line" | awk -F '|' '{print $3}' | tr -d '[:space:]')

        # Extract minimum and maximum Kubernetes versions
        min_k8s_version=$(echo "$k8s_range" | awk -F '-' '{print $2}' | sed 's/\.x$//')
        max_k8s_version=$(echo "$k8s_range" | awk -F '-' '{print $1}' | sed 's/\.x$//')

	if [[ "$(is_version_within_range "$k8s_version" "$min_k8s_version" "$max_k8s_version")" == "true" ]]; then
	    break
	fi
    fi
done <<< "$compatibility_table"

# Now that we know the Helm version, let's get the latest patch for it.
loop_down_versions "$helm_version" 10
