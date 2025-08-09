#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "env.example" ]]; then
  fail "env.example não encontrado no diretório raiz"
fi

# Não dar source em env.example (pode conter caracteres especiais). Em vez disso, validar por parsing seguro
required_vars=(
  NETWORK_NAME
  POSTGRES_USER POSTGRES_PASSWORD POSTGRES_PORT PGADMIN_EMAIL PGADMIN_PASSWORD PGADMIN_PORT
  MONGO_ROOT_USERNAME MONGO_ROOT_PASSWORD MONGO_PORT MONGO_EXPRESS_USERNAME MONGO_EXPRESS_PASSWORD MONGO_EXPRESS_PORT
  REDIS_PORT REDIS_INSIGHT_PORT
  KAFKA_PORT KAFDROP_PORT KAFKA_UI_PORT
  AIRFLOW_PORT AIRFLOW_DB_CONNECTION
  WORKSPACE_PATH GESTOR_PESSOAL_PATH
)

# Função para obter valor de uma variável no env.example sem expandir
get_var() {
  local key="$1"
  # Pega a primeira ocorrência da linha que começa com KEY=
  local line
  line=$(grep -E "^${key}=" env.example | head -n 1 || true)
  if [[ -z "$line" ]]; then
    echo ""
    return 0
  fi
  # Remove o prefixo KEY=
  local val="${line#${key}=}"
  # Remove comentário inline e trim
  val="${val%%#*}"
  # trim simples (remove espaços à direita/esquerda)
  val="$(echo -n "$val" | sed -e 's/^\s*//' -e 's/\s*$//')"
  echo "$val"
}

missing=()
for v in "${required_vars[@]}"; do
  val="$(get_var "$v")"
  if [[ -z "$val" ]]; then
    missing+=("$v")
  fi
done

if (( ${#missing[@]} > 0 )); then
  fail "Variáveis ausentes em env.example: ${missing[*]}"
else
  ok "Todas as variáveis obrigatórias estão definidas em env.example"
fi

# Verifica existência de docker-compose por serviço
compose_files=(
  "PostgreSQL/docker-compose.yml"
  "MongoDb/docker-compose.yml"
  "Redis/docker-compose.yml"
  "kafka/docker-compose.yml"
  "AirFLow/docker-compose.yaml"
  "Sonar/docker-compose.yml"
)

for f in "${compose_files[@]}"; do
  if [[ -f "$f" ]]; then ok "Encontrado $f"; else fail "Arquivo ausente: $f"; fi
done

# Verifica diretórios de volume essenciais
vol_dirs=(
  "PostgreSQL/DataBase"
  "MongoDb/DataBase"
  "AirFLow/dags" "AirFLow/logs" "AirFLow/plugins" "AirFLow/config"
)
for d in "${vol_dirs[@]}"; do
  if [[ -d "$d" ]]; then ok "Diretório presente: $d"; else fail "Diretório ausente: $d"; fi
done

# Verifica que Sonar usa a mesma NETWORK_NAME ou alerta
if grep -q "local-services-network" Sonar/docker-compose.yml; then
  net_val="$(get_var NETWORK_NAME)"
  if [[ "$net_val" != "local-services-network" ]]; then
    warn "Sonar/docker-compose.yml usa rede fixa 'local-services-network' (NETWORK_NAME atual: '${net_val:-unset}'). Ajuste se necessário."
  else
    ok "Sonar usa 'local-services-network' e NETWORK_NAME corresponde"
  fi
else
  warn "Não foi possível detectar rede fixa em Sonar/docker-compose.yml"
fi

# Verifica que Airflow connection string referencia host.docker.internal e POSTGRES_PORT
AIRFLOW_CONN_VAL="$(get_var AIRFLOW_DB_CONNECTION)"
POSTGRES_PORT_VAL="$(get_var POSTGRES_PORT)"
if [[ "$AIRFLOW_CONN_VAL" == *"host.docker.internal:"*"$POSTGRES_PORT_VAL"* ]]; then
  ok "AIRFLOW_DB_CONNECTION parece apontar para host.docker.internal:$POSTGRES_PORT_VAL"
else
  warn "AIRFLOW_DB_CONNECTION pode não apontar para host.docker.internal:$POSTGRES_PORT_VAL -> $AIRFLOW_CONN_VAL"
fi

# Verifica presença de script de gerenciamento
if [[ -f "scripts/manage-services.sh" ]]; then
  ok "scripts/manage-services.sh encontrado"
else
  warn "scripts/manage-services.sh não encontrado"
fi

echo -e "${BLUE}Validações concluídas com sucesso.${NC}"