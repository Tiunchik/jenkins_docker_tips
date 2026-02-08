FROM jenkins/inbound-agent:latest

USER root

# Установка curl и jq для работы с API
RUN apt-get update && \
    apt-get install -y curl jq && \
    apt-get install -y xmlstarlet && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN java --version

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jenkins

ENTRYPOINT ["/entrypoint.sh"]