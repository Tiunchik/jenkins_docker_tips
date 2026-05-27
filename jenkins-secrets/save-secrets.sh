#!/bin/bash

set -euo pipefail

# =============================================================================
# Jenkins Secrets Storage Script
# =============================================================================
# This script saves secrets to Jenkins Credentials Store
# Authentication: JENKINS_USER and JENKINS_PASSWORD (Basic Auth)

# Configuration
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASSWORD="${JENKINS_PASSWORD:-}"

# Credentials ID mapping
declare -A SECRET_IDS=(
    ["SSH_SERVER"]="SSH_SERVER"
    ["BOT_TOKEN"]="BOT_TOKEN"
    ["SSH_KEY"]="SSH_KEY"
    ["GRAFANA_USER"]="GRAFANA_USER"
    ["GRAFANA_PASSWORD"]="GRAFANA_PASSWORD"
)

# =============================================================================
# Authentication Setup
# =============================================================================
if [[ -z "${JENKINS_PASSWORD:-}" ]]; then
    echo "Error: JENKINS_PASSWORD must be provided."
    exit 1
fi

# Encode credentials in base64 for Basic Auth
AUTH_CREDENTIALS=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_PASSWORD" | base64 -w 0)
AUTH_HEADER="Authorization: Basic ${AUTH_CREDENTIALS}"

echo "Using Basic Auth for authentication with user: ${JENKINS_USER}"

# =============================================================================
# Helper Functions
# =============================================================================

# Get Jenkins home URL
get_jenkins_home() {
    local jenkins_home
    jenkins_home=$(curl -sf "${JENKINS_URL}/api/json" -H "${AUTH_HEADER}" 2>/dev/null | jq -r '.homeAtom.href' 2>/dev/null)
    echo "${jenkins_home:-${JENKINS_URL}}"
}

# Check if Jenkins is reachable
check_jenkins_connection() {
    echo "Checking Jenkins connection at ${JENKINS_URL}..."
    if ! curl -sf "${JENKINS_URL}" -H "${AUTH_HEADER}" >/dev/null 2>&1; then
        echo "Error: Cannot connect to Jenkins at ${JENKINS_URL}"
        echo "Make sure Jenkins is running and accessible."
        exit 1
    fi
    echo "Jenkins is accessible."
}

# =============================================================================
# Secret Storage Functions
# =============================================================================

# Store a string secret (Username/Password type)
store_string_secret() {
    local id="$1"
    local secret="$2"
    local description="${3:-Secret for ${id}}"
    
    echo ""
    echo "Storing string secret: ${id}"
    
    local jenkins_home
    jenkins_home=$(get_jenkins_home)
    
    local response
    response=$(curl -sf -w "\n%{http_code}" -X POST "${jenkins_home}/credentials/store/system/domain/_/createCredentials" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "${AUTH_HEADER}" \
        --data-urlencode "json={
            \"scope\": \"SYSTEM\",
            \"id\": \"${id}\",
            \"description\": \"${description}\",
            \"secret\": \"${secret}\",
            \"stapler-class\": \"org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl\",
            \"_class\": \"org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl\"
        }")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n-1)
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "✓ Secret '${id}' stored successfully."
    elif [[ "$http_code" == "400" ]]; then
        echo "Warning: Secret may already exist, updating..." >&2
        update_string_secret "$id" "$secret" "$description"
    else
        echo "Error: Failed to store secret (HTTP ${http_code})" >&2
        echo "Response: ${body}" >&2
        return 1
    fi
}

# Update an existing string secret
update_string_secret() {
    local id="$1"
    local secret="$2"
    local description="${3:-Secret for ${id}}"
    
    echo "Updating secret: ${id}"
    
    local jenkins_home
    jenkins_home=$(get_jenkins_home)
    
    local escaped_secret
    escaped_secret=$(printf '%s' "$secret" | sed 's/"/\\"/g')
    
    local response
    response=$(curl -sf -w "\n%{http_code}" -X POST "${jenkins_home}/credentials/store/system/domain/_/updateCredentials" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "${AUTH_HEADER}" \
        --data-urlencode "oldId=${id}" \
        --data-urlencode "newId=${id}" \
        --data-urlencode "json={
            \"scope\": \"SYSTEM\",
            \"id\": \"${id}\",
            \"description\": \"${description}\",
            \"secret\": \"${escaped_secret}\",
            \"stapler-class\": \"org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl\",
            \"_class\": \"org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl\"
        }" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "✓ Secret '${id}' updated successfully."
    else
        echo "Warning: Could not update secret via update endpoint." >&2
        echo "Attempting delete and recreate..." >&2
        delete_secret "$id" 2>/dev/null || true
        store_string_secret "$id" "$secret" "$description"
    fi
}

# Store SSH key credential (username + private key)
store_ssh_key() {
    local id="$1"
    local username="$2"
    local private_key="$3"
    local description="${4:-SSH Key for ${username}}"
    
    echo ""
    echo "Storing SSH key credential: ${id}"
    
    local jenkins_home
    jenkins_home=$(get_jenkins_home)
    
    # Escape special characters for JSON
    local escaped_key
    escaped_key=$(printf '%s' "$private_key" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
    local escaped_username
    escaped_username=$(printf '%s' "$username" | sed 's/"/\\"/g')
    
    local response
    response=$(curl -sf -w "\n%{http_code}" -X POST "${jenkins_home}/credentials/store/system/domain/_/createCredentials" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "${AUTH_HEADER}" \
        --data-urlencode "json={
            \"scope\": \"SYSTEM\",
            \"id\": \"${id}\",
            \"description\": \"${description}\",
            \"username\": \"${escaped_username}\",
            \"privateKey\": \"${escaped_key}\",
            \"stapler-class\": \"com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\",
            \"_class\": \"com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\",
            \"usernameCredentialType\": \"BasicSSHUserPrivateKey\",
            \"passphraseCredential\": null,
            \"privateKeySource\": [
                {
                    \"type\": \"directEntry\",
                    \"privateKey\": \"${escaped_key}\"
                }
            ]
        }" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "✓ SSH Key '${id}' stored successfully."
    elif [[ "$http_code" == "400" ]]; then
        echo "Warning: Secret may already exist, updating..." >&2
        update_ssh_key "$id" "$username" "$private_key" "$description"
    else
        echo "Error: Failed to store SSH key (HTTP ${http_code})" >&2
        echo "Response: ${response}" >&2
        return 1
    fi
}

# Update SSH key credential
update_ssh_key() {
    local id="$1"
    local username="$2"
    local private_key="$3"
    local description="${4:-SSH Key for ${username}}"
    
    echo "Updating SSH key: ${id}"
    
    local jenkins_home
    jenkins_home=$(get_jenkins_home)
    
    local escaped_key
    escaped_key=$(printf '%s' "$private_key" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
    local escaped_username
    escaped_username=$(printf '%s' "$username" | sed 's/"/\\"/g')
    
    local response
    response=$(curl -sf -w "\n%{http_code}" -X POST "${jenkins_home}/credentials/store/system/domain/_/updateCredentials" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "${AUTH_HEADER}" \
        --data-urlencode "oldId=${id}" \
        --data-urlencode "newId=${id}" \
        --data-urlencode "json={
            \"scope\": \"SYSTEM\",
            \"id\": \"${id}\",
            \"description\": \"${description}\",
            \"username\": \"${escaped_username}\",
            \"privateKey\": \"${escaped_key}\",
            \"stapler-class\": \"com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\",
            \"_class\": \"com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\"
        }" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "✓ SSH Key '${id}' updated successfully."
    else
        echo "Warning: Could not update SSH key, recreating..." >&2
        delete_secret "$id" 2>/dev/null || true
        store_ssh_key "$id" "$username" "$private_key" "$description"
    fi
}

# Delete a secret
delete_secret() {
    local id="$1"
    
    echo "Deleting secret: ${id}"
    
    local jenkins_home
    jenkins_home=$(get_jenkins_home)
    
    local response
    response=$(curl -sf -w "\n%{http_code}" -X DELETE "${jenkins_home}/credentials/store/system/credentials/${id}" \
        -H "${AUTH_HEADER}" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" || "$http_code" == "204" || "$http_code" == "202" ]]; then
        echo "✓ Secret '${id}' deleted."
    else
        echo "Warning: Could not delete secret '${id}' (HTTP ${http_code})" >&2
    fi
}

# List all stored secrets
list_secrets() {
    echo ""
    echo "Listing stored secrets..."
    
    local jenkins_home
    jenkins_home=$(get_jenkins_home)
    
    curl -sf "${jenkins_home}/credentials/store/system/credentials/api/json" \
        -H "${AUTH_HEADER}" | jq '.' 2>/dev/null || echo "Could not list secrets (may need permissions)"
}

# =============================================================================
# Main Function
# =============================================================================
main() {
    echo "============================================================"
    echo "Jenkins Secrets Storage Script"
    echo "============================================================"
    echo "Jenkins URL: ${JENKINS_URL}"
    echo "Username: ${JENKINS_USER}"
    echo "============================================================"
    
    # Check Jenkins connection
    check_jenkins_connection
    
    # Store SSH_SERVER secret
    if [[ -n "${SSH_SERVER:-}" ]]; then
        store_string_secret "${SECRET_IDS[SSH_SERVER]}" "${SSH_SERVER}" "SSH Server address"
    else
        echo "No SSH_SERVER provided, skipping..."
    fi
    
    # Store BOT_TOKEN secret
    if [[ -n "${BOT_TOKEN:-}" ]]; then
        store_string_secret "${SECRET_IDS[BOT_TOKEN]}" "${BOT_TOKEN}" "Bot Token (Telegram/Messenger)"
    else
        echo "No BOT_TOKEN provided, skipping..."
    fi
    
    # Store SSH_KEY secret (requires SSH_USERNAME and SSH_PRIVATE_KEY)
    if [[ -n "${SSH_KEY:-}" && -n "${SSH_USERNAME:-}" ]]; then
        store_ssh_key "${SECRET_IDS[SSH_KEY]}" "${SSH_USERNAME:}" "${SSH_KEY}" "SSH private key for ${SSH_USERNAME}"
    elif [[ -n "${SSH_KEY:-}" ]]; then
        # SSH_KEY variable may contain both username and key, try to parse it
        echo "SSH_KEY provided without SSH_USERNAME, attempting to parse..."
        # If SSH_KEY contains a username prefix, try to extract it
        if echo "$SSH_KEY" | head -1 | grep -q "^[a-zA-Z]"; then
            # First line might be the username
            local parsed_username
            parsed_username=$(echo "$SSH_KEY" | head -1)
            local parsed_key
            parsed_key=$(echo "$SSH_KEY" | tail -n +2)
            store_ssh_key "${SECRET_IDS[SSH_KEY]}" "root" "${parsed_key}" "SSH private key for ${parsed_username}"
        else
            echo "Cannot parse SSH_KEY - please provide SSH_USERNAME separately" >&2
            exit 1
        fi
    else
        echo "No SSH_KEY provided, skipping..."
    fi
    
    # Store GRAFANA_USER secret
    if [[ -n "${GRAFANA_USER:-}" ]]; then
        store_string_secret "${SECRET_IDS[GRAFANA_USER]}" "${GRAFANA_USER}" "Grafana username"
    else
        echo "No GRAFANA_USER provided, skipping..."
    fi
    
    # Store GRAFANA_PASSWORD secret
    if [[ -n "${GRAFANA_PASSWORD:-}" ]]; then
        store_string_secret "${SECRET_IDS[GRAFANA_PASSWORD]}" "${GRAFANA_PASSWORD}" "Grafana password"
    else
        echo "No GRAFANA_PASSWORD provided, skipping..."
    fi
    
    echo ""
    echo "============================================================"
    echo "Secrets storage completed!"
    echo "============================================================"
    echo ""
    echo "You can now use these secrets in your Jenkins jobs:"
    echo "  - SSH_SERVER: credentialsId='${SECRET_IDS[SSH_SERVER]}'"
    echo "  - BOT_TOKEN:  credentialsId='${SECRET_IDS[BOT_TOKEN]}'"
    echo "  - SSH_KEY:    credentialsId='${SECRET_IDS[SSH_KEY]}'"
    echo "  - GRAFANA_USER: credentialsId='${SECRET_IDS[GRAFANA_USER]}'"
    echo "  - GRAFANA_PASSWORD: credentialsId='${SECRET_IDS[GRAFANA_PASSWORD]}'"
    echo ""
    echo "Example Jenkinsfile usage:"
    echo "  withCredentials([string(credentialsId: '${SECRET_IDS[BOT_TOKEN]}', variable: 'TOKEN')]) {"
    echo "    sh 'curl -X POST \\\"https://api.telegram.org/bot\${TOKEN}/sendMessage\\\" ...'"
    echo "  }"
    echo ""
    
    # List secrets if requested
    if [[ "${LIST_SECRETS:-false}" == "true" ]]; then
        list_secrets
    fi
}

# Run main function
main "$@"