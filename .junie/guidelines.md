Development Environment Guidelines

Purpose
- This repo provides a local, dockerized environment for common services used during development (databases, Airflow, Kafka, Redis, Sonar, etc.).
- Use it to spin up dependencies quickly and keep them isolated from your app codebases.

Tech Stack
- Docker + Docker Compose (per-service compose files)
- Services:
  - Airflow (AirFLow/) with custom Dockerfile and Python requirements
  - Databases: PostgreSQL (+pgAdmin), MongoDB (+Mongo Express), MySQL, MSSQL, Oracle
  - Messaging: Kafka (+Zookeeper, Kafdrop, Kafka UI)
  - Cache: Redis (+RedisInsight)
  - Code Quality: SonarQube
- Shell helper scripts in scripts/ for validation and service management

Repository Structure (top-level)
- AirFLow/: Airflow Dockerfile, compose, dags, logs, plugins, config
- PostgreSQL/, MongoDb/, Redis/, kafka/, Sonar/: docker-compose + data/volumes
- env.example: template for .env configuration
- scripts/: helper scripts (manage-services.sh, validate-config.sh)

Getting Started
1) Requirements
- Docker and Docker Compose installed
- macOS/Linux shell (Bash)

2) Configure environment
- From repo root:
  - cp env.example .env
  - Edit .env to set desired ports, paths, and NETWORK_NAME
  - Important paths:
    - WORKSPACE_PATH: absolute path to this repo on your machine
    - GESTOR_PESSOAL_PATH: optional path mounted into Airflow container (PYTHONPATH)

3) Validate configuration (recommended)
- bash scripts/validate-config.sh
  - Checks required env vars, ensures compose files and volume folders exist, and warns about Sonar network name.

Running Services
Option A: Use helper script (recommended)
- Show help: bash scripts/manage-services.sh help
- Start all: bash scripts/manage-services.sh start all
- Stop all: bash scripts/manage-services.sh stop all
- Status: bash scripts/manage-services.sh status all
- Logs (example): bash scripts/manage-services.sh logs airflow
- Clean unused Docker resources: bash scripts/manage-services.sh clean
- Backup data folders: bash scripts/manage-services.sh backup

Option B: Use Docker Compose directly (per service)
- cd SERVICE_DIR && docker-compose up -d
- Examples:
  - cd PostgreSQL && docker-compose up -d
  - cd MongoDb && docker-compose up -d
  - cd AirFLow && docker-compose up -d
- Stop: docker-compose down

Service Notes
- Airflow
  - Build uses AirFLow/Dockerfile and AirFLow/requirements.txt
  - Mounts host folders: dags, logs, plugins, config from WORKSPACE_PATH/AirFlow/*
  - Web UI: http://localhost:${AIRFLOW_PORT} (defaults to 8080)
  - DB connection string comes from AIRFLOW_DB_CONNECTION (env). Default points to host.docker.internal:${POSTGRES_PORT}
- PostgreSQL + pgAdmin
  - Ports from .env (e.g., POSTGRES_PORT -> 15432, PGADMIN_PORT -> 16543)
  - Data persisted under PostgreSQL/DataBase
- MongoDB + Mongo Express
  - Mongo Express UI on ${MONGO_EXPRESS_PORT} (default 8081)
  - Data persisted under MongoDb/DataBase
- Kafka
  - Broker advertised to localhost:${KAFKA_PORT}; UIs at Kafdrop (${KAFDROP_PORT}) and Kafka UI (${KAFKA_UI_PORT})
- Redis + RedisInsight
  - RedisInsight at ${REDIS_INSIGHT_PORT} (default 5540)
- SonarQube
  - Default network name in Sonar/docker-compose.yml is local-services-network. Keep NETWORK_NAME consistent or adjust compose accordingly.

Executing Scripts
- Validation: bash scripts/validate-config.sh
- Management: bash scripts/manage-services.sh [start|stop|restart|status|logs|clean|backup] [SERVICE|all]
  - SERVICES: postgres, mongo, redis, kafka, airflow, mysql, mssql, oracle, ftp, sonar

Running Tests
- This repository hosts infra/services; there are no unit/integration tests here.
- Use the validation script as a sanity check: bash scripts/validate-config.sh
- Optional compose validation: cd SERVICE_DIR && docker-compose config -q

Best Practices
- Do not commit secrets: keep real credentials only in your local .env (never commit .env)
- Keep ports and NETWORK_NAME consistent across services; update env.example if you add services
- Use volumes for data persistence and commit only necessary config, not data dumps
- Name services clearly and keep compose files minimal and readable
- Prefer helper scripts for common tasks to ensure consistency
- When adding a new service:
  - Create a SERVICE_DIR with docker-compose.yml
  - Use ${NETWORK_NAME} in compose networks
  - Add required vars to env.example (with safe defaults)
  - Add checks into scripts/validate-config.sh if relevant

Troubleshooting
- Port already in use: change the port in .env and restart the service
- Network issues between containers and host: ensure extra_hosts has host.docker.internal mapping if needed
- Files not mounting: verify WORKSPACE_PATH and other host paths in .env are correct absolute paths
- Containers restart loop: check logs via manage-services.sh logs SERVICE

Conventions
- Directory names match service names (case-sensitive as in repo)
- Use docker-compose up -d for background services
- Keep Airflow DAGs under AirFLow/dags; logs and plugins under respective folders

Support
- See scripts/ for common operations
- When in doubt, run the validator: bash scripts/validate-config.sh