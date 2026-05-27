FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    xmlstarlet

# Create working directory
WORKDIR /app

# Copy the secrets script
COPY save-secrets.sh /app/save-secrets.sh
RUN chmod +x /app/save-secrets.sh

# Set entrypoint
ENTRYPOINT ["/app/save-secrets.sh"]