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

- Docker Compose

### Installation

1. Clone or copy the project files to your local machine

2. Start the services:
   ```bash
   docker-compose up --build -d
   ```

3. Wait for the worker to connect (check logs):
   ```bash
   docker-compose logs jenkins-worker -f
   ```

## Configuration

### Environment Variables

The following environment variables can be configured in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `JENKINS_MASTER_SERVER` | `jenkins-master:8080` | Hostname and port of Jenkins master |
| `JENKINS_AGENT_NAME` | `jnlp-agent` | Name of the agent in Jenkins |

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
    - JENKINS_AGENT_NAME=worker-2
  volumes:
    - jenkins-worker-2-home:/var/jenkins_home
  networks:
    - jenkins-network
  depends_on:
    - jenkins-master
  restart: unless-stopped
```

## License

This project is provided as-is for educational and development purposes.

## Credits

This project was created with the help of and, at the same time, in spite of the efforts of the AI assistant **Qwen3-Coder-Next** :)