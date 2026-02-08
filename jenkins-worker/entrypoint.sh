#!/bin/bash

set -e

JENKINS_URL="http://${JENKINS_MASTER_SERVER}"
JENKINS_AGENT_NAME=${JENKINS_AGENT_NAME:jnlp-agent}

# Формирование URL с аутентификацией, если предоставлены учетные данные
if [[ -n "${JENKINS_USER:-}" && -n "${JENKINS_PASSWORD:-}" ]]; then
  # Кодируем учетные данные в base64 для Basic Auth
  AUTH_CREDENTIALS=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_PASSWORD" | base64 -w 0)
  JENKINS_MASTER_URL="http://${AUTH_CREDENTIALS}@${JENKINS_MASTER_SERVER}"
 echo "Jenkins credentials provided."
else
  JENKINS_MASTER_URL="$JENKINS_URL"
  echo "Jenkins credentials not provided."
fi
echo "Jenkins Master URL: $JENKINS_MASTER_URL"

# Ждём, пока Jenkins будет доступен
until curl -s "${JENKINS_URL}" >/dev/null; do
  echo "Waiting for Jenkins Master to become available..."
  sleep 10
done

echo "Jenkins Master is online."

# Получаем Crumb (CSRF защита Jenkins)
echo "${JENKINS_MASTER_URL}/crumbIssuer/api/json"
CRUMB=$(curl -c cookies.txt -s "${JENKINS_MASTER_URL}/crumbIssuer/api/json" | jq -r '.crumb')
echo "Crumb: $CRUMB"

# Регистрируем агент в Jenkins
echo "${JENKINS_MASTER_URL}/computer/doCreateItem?name=${JENKINS_AGENT_NAME}&type=hudson.slaves.DumbSlave&Jenkins-Crumb=${CRUMB}"
response=$(curl -b cookies.txt \
             --request POST \
             --url "${JENKINS_MASTER_URL}/computer/doCreateItem?name=${JENKINS_AGENT_NAME}&type=hudson.slaves.DumbSlave&Jenkins-Crumb=${CRUMB}" \
             --header 'content-type: application/x-www-form-urlencoded' \
             --data "json={
               \"name\": \"${JENKINS_AGENT_NAME}\",
               \"nodeDescription\": \"Dumn docker agent node\",
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
                 \"stapler-class\": \"hudson.slaves.RetentionStrategy\$Always\"
               },
               \"nodeProperties\": {
                 \"stapler-class-bag\": \"true\"
               }
             }")

if [ "$response" -eq 200 ]; then
  echo "Успешно зарегистрирован агент"
else
  echo "Возможно агент уже зарегистрирован в Jenkins"
fi

#Получаем секрет для агента
echo "$JENKINS_MASTER_URL/computer/$JENKINS_AGENT_NAME/slave-agent.jnlp"
SECRET=$(curl --request GET \
  --url "$JENKINS_MASTER_URL/computer/$JENKINS_AGENT_NAME/slave-agent.jnlp" | xmlstarlet sel -t -v '(//argument)[1]')

if [ -z "$SECRET" ] || [ "$SECRET" == "null" ]; then
  echo "Failed to retrieve agent secret!"
  exit 1
fi

echo "Retrieved agent secret: $SECRET"

# Запуск агента с полученным токеном
curl -sO "${JENKINS_MASTER_URL}/jnlpJars/agent.jar"
exec java -jar agent.jar \
  -url "${JENKINS_URL}" \
  -secret "${SECRET}" -name "$JENKINS_AGENT_NAME" -webSocket -workDir "/home/jenkins"