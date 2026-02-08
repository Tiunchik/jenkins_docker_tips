FROM jenkins/inbound-agent:latest-jdk25

USER root

# Install curl and jq for API work
RUN apt-get update && \
    apt-get install -y curl jq && \
    apt-get install -y xmlstarlet && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jenkins

ENTRYPOINT ["/entrypoint.sh"]
