# Development Setting – Local Dockerized Services

A ready-to-use, dockerized environment for common services used during application development. Spin up databases, Airflow, Kafka, Redis, SonarQube, and more in isolation from your app codebases.


## Table of Contents
- Purpose and Features
- Tech Stack
- Repository Layout
- Prerequisites
- Quick Start
  - Configure environment (.env)
  - Validate configuration
  - Start/Stop services
  - Logs, Status, Cleanup, Backup
- Services Overview
  - Airflow
  - PostgreSQL + pgAdmin
  - MongoDB + Mongo Express
  - Kafka (+Zookeeper, Kafdrop, Kafka UI)
  - Redis + RedisInsight
  - SonarQube
  - (Optional) MySQL, MSSQL, Oracle, FTP
- Environment Variables
- Troubleshooting
- Best Practices
- FAQ


## Purpose and Features
This repository provides a local infrastructure sandbox for development:
- Run common dependencies with Docker Compose, isolated from application repos
- Per-service docker-compose files for modular bring-up
- Helper shell scripts for validation and service management
- Data persistence via volumes under each service directory


## Tech Stack
- Docker + Docker Compose (per-service compose files)
- Services:
  - Airflow (AirFLow/) with custom Dockerfile and Python requirements
  - Databases: PostgreSQL (+pgAdmin), MongoDB (+Mongo Express), MySQL, MSSQL, Oracle
  - Messaging: Kafka (+Zookeeper, Kafdrop, Kafka UI)
  - Cache: Redis (+RedisInsight)
  - Code Quality: SonarQube
- Helper scripts in scripts/


## Repository Layout
Top-level directories (case-sensitive as in repo):
- AirFLow/: Airflow Dockerfile, compose, dags, logs, plugins, config
- PostgreSQL/, MongoDb/, Redis/, kafka/, Sonar/: docker-compose + data/volumes
- Ftp/, Mysql/, MSSQL/, Oracle/: optional services (compose/config)
- scripts/: helper scripts (manage-services.sh, validate-config.sh)
- env.example: template for .env configuration

Data volumes live under each service, for example:
- PostgreSQL/DataBase
- MongoDb/DataBase


## Prerequisites
- Docker and Docker Compose installed
- macOS/Linux shell (Bash)


## Quick Start
1) Create your .env file
```
cp env.example .env
```
Edit .env and set desired ports, paths, and NETWORK_NAME.

Important variables:
- WORKSPACE_PATH: absolute path to this repo on your machine
- NETWORK_NAME: shared docker network name (e.g., local-services-network)
- Service ports: POSTGRES_PORT, PGADMIN_PORT, AIRFLOW_PORT, MONGO_EXPRESS_PORT, KAFKA_PORT, KAFDROP_PORT, KAFKA_UI_PORT, REDIS_INSIGHT_PORT, etc.
- Optional: GESTOR_PESSOAL_PATH (mounted into Airflow PYTHONPATH)

2) Validate configuration (recommended)
```
bash scripts/validate-config.sh
```
This checks required env vars, ensures compose files and volume folders exist, and warns if Sonar network differs.

3) Start services
Option A: Helper script (recommended)
```
# Show help
bash scripts/manage-services.sh help

# Start all services
bash scripts/manage-services.sh start all

# Start a single service (examples)
bash scripts/manage-services.sh start postgres
bash scripts/manage-services.sh start airflow
```
Option B: Docker Compose directly
```
cd PostgreSQL && docker-compose up -d
cd MongoDb && docker-compose up -d
cd AirFLow && docker-compose up -d
```

4) Stop services
```
# Stop all
bash scripts/manage-services.sh stop all

# Stop a single service
bash scripts/manage-services.sh stop kafka
```

5) Status, logs, cleanup, backup
```
# Status
bash scripts/manage-services.sh status all

# Logs (examples)
bash scripts/manage-services.sh logs airflow
bash scripts/manage-services.sh logs postgres

# Clean unused Docker resources
bash scripts/manage-services.sh clean

# Backup data folders
bash scripts/manage-services.sh backup
```


## Services Overview

### Airflow (AirFLow/)
- Build uses AirFLow/Dockerfile and AirFLow/requirements.txt
- Mounts host folders under WORKSPACE_PATH/AirFLow: dags, logs, plugins, config
- Web UI: http://localhost:${AIRFLOW_PORT} (default 8080 if not changed)
- DB connection string taken from AIRFLOW_DB_CONNECTION (.env). Default points to host.docker.internal:${POSTGRES_PORT}
- Put DAGs under AirFLow/dags; logs and plugins under their respective folders

### PostgreSQL + pgAdmin (PostgreSQL/)
- Ports configured in .env: POSTGRES_PORT (e.g., 15432), PGADMIN_PORT (e.g., 16543)
- Data persisted under PostgreSQL/DataBase
- Example compose services: postgres-compose, pgadmin-compose

### MongoDB + Mongo Express (MongoDb/)
- Mongo Express UI: http://localhost:${MONGO_EXPRESS_PORT} (default 8081 if using default config)
- Data persisted under MongoDb/DataBase

### Kafka (+Zookeeper, Kafdrop, Kafka UI) (kafka/)
- Broker advertised to localhost:${KAFKA_PORT}
- Kafdrop UI at http://localhost:${KAFDROP_PORT}
- Kafka UI at http://localhost:${KAFKA_UI_PORT}

### Redis + RedisInsight (Redis/)
- RedisInsight at http://localhost:${REDIS_INSIGHT_PORT} (default 5540)

### SonarQube (Sonar/)
- Default network name in Sonar/docker-compose.yml is local-services-network
- Keep NETWORK_NAME in .env consistent or adjust compose accordingly

### Optional services
- MySQL (Mysql/), MSSQL (MSSQL/), Oracle (Oracle/), FTP (Ftp/)
- Start with the helper script or via docker-compose within each directory


## Environment Variables
Key variables to review in .env:
- WORKSPACE_PATH: absolute path to this repository
- NETWORK_NAME: shared Docker network (e.g., local-services-network)
- AIRFLOW_PORT, POSTGRES_PORT, PGADMIN_PORT, MONGO_EXPRESS_PORT, KAFKA_PORT, KAFDROP_PORT, KAFKA_UI_PORT, REDIS_INSIGHT_PORT
- AIRFLOW_DB_CONNECTION (Airflow connection string)
- POSTGRES_USER, POSTGRES_PASSWORD, PGADMIN_EMAIL, PGADMIN_PASSWORD
- Add or adjust others as you enable more services

Never commit your real .env. Use env.example as a template and keep secrets local.


## Troubleshooting
- Port already in use: change the port in .env and restart the service
- Network issues between containers and host: ensure extra_hosts includes host.docker.internal if needed
- Files/volumes not mounting: verify WORKSPACE_PATH and other host paths in .env are correct absolute paths
- Containers in restart loop: check logs
  - Via script: `bash scripts/manage-services.sh logs SERVICE`
  - Or directly: `docker-compose logs -f` in the service directory
- Compose validation: `cd SERVICE_DIR && docker-compose config -q`


## Best Practices
- Do not commit secrets: keep real credentials only in your local .env
- Keep ports and NETWORK_NAME consistent across services
- Use volumes for data persistence and commit only necessary config, not data dumps
- Prefer helper scripts for consistency
- When adding a new service:
  - Create a SERVICE_DIR with docker-compose.yml
  - Use ${NETWORK_NAME} in compose networks
  - Add required vars to env.example (with safe defaults)
  - Add checks into scripts/validate-config.sh if relevant


## FAQ
Q: Can I run only one service?
A: Yes. Use the helper script (e.g., `bash scripts/manage-services.sh start postgres`) or `docker-compose up -d` inside the service directory.

Q: Where do Airflow DAGs live?
A: Place them under AirFLow/dags on the host; they’re mounted into the container. Logs and plugins live under AirFLow/logs and AirFLow/plugins.

Q: How do I change ports?
A: Edit .env (e.g., POSTGRES_PORT, AIRFLOW_PORT, etc.) and restart the service.

Q: How do I clean up Docker leftovers?
A: `bash scripts/manage-services.sh clean` to prune unused resources.


---
Last updated: 2025-08-09