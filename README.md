# Jenkins Worker Setup

This project provides a Docker-based solution for automatically connecting Jenkins agents (workers) to a Jenkins master without using the web UI. All configuration and agent registration is done through scripts and environment variables.

## Overview

The solution consists of:
- **Jenkins Master** - The main Jenkins server that coordinates builds and jobs
- **Jenkins Worker** - A Docker container that automatically registers as an agent and connects to the master

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Docker Network                               │
│                                                                     │
│  ┌──────────────────┐         ┌──────────────────┐                 │
│  │  Jenkins Master  │────────>│  Jenkins Worker  │                 │
│  │  (jenkins-master)│  API    │  (jenkins-worker)│                 │
│  │                  │         │                  │                 │
│  │  - Web UI: 8080  │         │  - Registers as  │                 │
│  │  - Agent Port:   │         │    agent via API │                 │
│  │    50000         │         │  - Downloads     │                 │
│  └──────────────────┘         │    agent.jar     │                 │
│                               │  - Connects via  │                 │
│                               │    JNLP          │                 │
│                               └──────────────────┘                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker
- Docker Compose

### Installation

1. Clone or copy the project files to your local machine

2. Start the services:
   ```bash
   docker-compose up -d
   ```

3. Wait for the worker to connect (check logs):
   ```bash
   docker-compose logs -f jenkins-worker
   ```

## Configuration

### Environment Variables

The following environment variables can be configured in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `JENKINS_MASTER_SERVER` | `jenkins-master:8080` | Hostname and port of Jenkins master |
| `JENKINS_USER` | (required) | Jenkins admin username |
| `JENKINS_PASSWORD` | (required) | Jenkins admin password |
| `JENKINS_AGENT_NAME` | `jnlp-agent` | Name of the agent in Jenkins |

### Default Credentials

The default Jenkins setup uses:
- Username: `admin`
- Password: `admin`

**Important**: Change these credentials in production environments!

## How It Works

### 1. Wait for Jenkins Master

The worker script first waits for the Jenkins master to become available:
```bash
until curl -sf "${JENKINS_URL}" >/dev/null 2>&1; do
  sleep 5
done
```

### 2. Retrieve CSRF Crumb

Jenkins requires a CSRF crumb for POST requests. The script retrieves it:
```bash
CRUMB=$(curl -sf -c cookies.txt "${JENKINS_MASTER_URL}/crumbIssuer/api/json" | jq -r '.crumb')
```

### 3. Register Agent

The script checks if the agent already exists. If not, it registers a new agent via the Jenkins API:
```bash
curl -X POST "${JENKINS_MASTER_URL}/computer/doCreateItem?name=${AGENT_NAME}&type=hudson.slaves.DumbSlave"
```

### 4. Retrieve Agent Secret

After registration, the script retrieves the agent's secret token:
```bash
SECRET=$(curl -sf "${JENKINS_MASTER_URL}/computer/${AGENT_NAME}/slave-agent.jnlp"  | xmlstarlet sel -t -v '(//argument)[1]')
```

### 5. Download and Start Agent

The script downloads `agent.jar` and starts the agent:
```bash
java -jar agent.jar \
  -url "${JENKINS_URL}" \
  -secret "${SECRET}" \
  -name "${AGENT_NAME}" \
  -webSocket \
  -workDir "/home/jenkins"
```

## Files Structure

```
jenkins-worker/
├── Dockerfile           # Docker image definition
├── entrypoint.sh        # Main script for agent registration
└── README.md            # This file

jenkins-master/
├── Dockerfile           # Jenkins master Dockerfile
├── plugins.txt          # List of plugins to install
└── README.md            # Master setup documentation

docker-compose.yml       # Service orchestration
```

## Troubleshooting

### Worker cannot connect to Master

1. Check if both containers are on the same Docker network:
   ```bash
   docker network inspect jenkins-network
   ```

2. Verify Jenkins master is running:
   ```bash
   docker-compose ps
   ```

3. Check Jenkins master logs:
   ```bash
   docker-compose logs jenkins-master
   ```

### Agent already exists

If the agent is already registered, the script will skip registration and use the existing agent.

### Secret retrieval fails

1. Verify the agent name is correct
2. Check Jenkins master logs for registration errors
3. Ensure the agent has been properly registered in Jenkins

## Customization

### Adding more workers

Add additional services to `docker-compose.yml`:
```yaml
jenkins-worker-2:
  build:
    context: ./jenkins-worker
    dockerfile: Dockerfile
  container_name: jenkins-worker-2
  environment:
    - JENKINS_USER=admin
    - JENKINS_PASSWORD=admin
    - JENKINS_AGENT_NAME=worker-2
  volumes:
    - jenkins-worker-2-home:/var/jenkins_home
  networks:
    - jenkins-network
  depends_on:
    - jenkins-master
  restart: unless-stopped
```

### Modifying agent configuration

Edit the JSON payload in `entrypoint.sh` to customize:
- Number of executors
- Remote file system path
- Labels
- Work directory settings

## License

This project is provided as-is for educational and development purposes.

## Credits

This project was created and maintained using **Qwen3-Coder-Next** AI assistant.