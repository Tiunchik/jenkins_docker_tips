#!/bin/bash

set -euo pipefail

# =============================================================================
# Jenkins Master Configuration
# =============================================================================
JENKINS_MASTER_SERVER="${JENKINS_MASTER_SERVER:-jenkins-master:8080}"
JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-jnlp-agent}"
JENKINS_URL="http://${JENKINS_MASTER_SERVER}"

# =============================================================================
# Authentication URL Formation
# =============================================================================
if [[ -n "${JENKINS_USER:-}" && -n "${JENKINS_PASSWORD:-}" ]]; then
  # Encode credentials in base64 for Basic Auth
  AUTH_CREDENTIALS=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_PASSWORD" | base64 -w 0)
  JENKINS_MASTER_URL="http://${AUTH_CREDENTIALS}@${JENKINS_MASTER_SERVER}"
  echo "Jenkins credentials provided."
else
  JENKINS_MASTER_URL="$JENKINS_URL"
  echo "Jenkins credentials not provided."
fi
echo "Jenkins Master URL: ${JENKINS_MASTER_URL}"

# =============================================================================
# Wait for Jenkins Master to become available
# =============================================================================
echo "Waiting for Jenkins Master to become available..."
until curl -sf "${JENKINS_URL}" >/dev/null 2>&1; do
  sleep 5
  echo "Waiting for Jenkins Master to become available..."
done
echo "Jenkins Master is online."

# =============================================================================
# Retrieve Jenkins Crumb (CSRF protection)
# =============================================================================
echo "Retrieving Jenkins crumb..."
CRUMB=$(curl -sf -c cookies.txt "${JENKINS_MASTER_URL}/crumbIssuer/api/json" | jq -r '.crumb')

if [[ -z "$CRUMB" || "$CRUMB" == "null" ]]; then
  echo "Failed to retrieve Jenkins crumb!"
  exit 1
fi
echo "Crumb: ${CRUMB}"

# =============================================================================
# Register agent in Jenkins
# =============================================================================
echo "Registering Jenkins agent: ${JENKINS_AGENT_NAME}"

# Check if agent already exists
if curl -sf "${JENKINS_MASTER_URL}/computer/${JENKINS_AGENT_NAME}/api/json" >/dev/null 2>&1; then
  echo "Agent '${JENKINS_AGENT_NAME}' already exists. Skipping registration."
else
  # Create agent
  HTTP_CODE=$(curl -sS -w "%{http_code}" -b cookies.txt -X POST \
    "${JENKINS_MASTER_URL}/computer/doCreateItem?name=${JENKINS_AGENT_NAME}&type=hudson.slaves.DumbSlave" \
    -H "Jenkins-Crumb: ${CRUMB}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode json="{
      \"name\": \"${JENKINS_AGENT_NAME}\",
      \"nodeDescription\": \"Docker agent node\",
      \"numExecutors\": \"1\",
      \"remoteFS\": \"/home/jenkins\",
      \"labelString\": \"linux\",
      \"mode\": \"NORMAL\",
      \"launcher\": {
        \"stapler-class\": \"hudson.slaves.JNLPLauncher\",
        \"workDirSettings\": {
          \"disabled\": false,
          \"workDirPath\": \"\",
          \"internalDir\": \"remoting\",
          \"failIfWorkDirIsMissing\": false
        }
      },
      \"retentionStrategy\": {
        \"stapler-class\": \"hudson.slaves.RetentionStrategy\\$Always\"
      },
      \"nodeProperties\": {
        \"stapler-class-bag\": \"true\"
      }
    }" 2>/dev/null)

  if [[ "$HTTP_CODE" -eq 200 || "$HTTP_CODE" -eq 201 ]]; then
    echo "Agent '${JENKINS_AGENT_NAME}' registered successfully."
  else
    echo "Warning: Failed to register agent (HTTP ${HTTP_CODE}). Agent may already exist."
  fi
fi

# =============================================================================
# Retrieve agent secret
# =============================================================================
echo "Retrieving agent secret..."
SECRET=$(curl -sf "${JENKINS_MASTER_URL}/computer/${JENKINS_AGENT_NAME}/slave-agent.jnlp" | xmlstarlet sel -t -v '(//argument)[1]')

if [[ -z "$SECRET" || "$SECRET" == "null" ]]; then
  echo "Failed to retrieve agent secret!"
  exit 1
fi

echo "Retrieved agent secret successfully."

# =============================================================================
# Download and start agent
# =============================================================================
echo "Downloading agent.jar..."
if [[ ! -f agent.jar ]]; then
  curl -sfO "${JENKINS_MASTER_URL}/jnlpJars/agent.jar" || {
    echo "Failed to download agent.jar!"
    exit 1
  }
fi

echo "Starting Jenkins agent..."
exec java -jar agent.jar \
  -url "${JENKINS_URL}" \
  -secret "${SECRET}" \
  -name "${JENKINS_AGENT_NAME}" \
  -webSocket \
  -workDir "/home/jenkins"
