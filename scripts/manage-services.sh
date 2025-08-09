#!/bin/bash

# ========================================
# SCRIPT DE GERENCIAMENTO DE SERVIÇOS
# ========================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir ajuda
show_help() {
    echo -e "${BLUE}=== GERENCIADOR DE SERVIÇOS DE DESENVOLVIMENTO ===${NC}"
    echo ""
    echo "Uso: $0 [COMANDO] [SERVIÇO]"
    echo ""
    echo "COMANDOS:"
    echo "  start     - Iniciar serviços"
    echo "  stop      - Parar serviços"
    echo "  restart   - Reiniciar serviços"
    echo "  status    - Verificar status dos serviços"
    echo "  logs      - Ver logs dos serviços"
    echo "  clean     - Limpar containers e volumes"
    echo "  backup    - Fazer backup dos dados"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "SERVIÇOS:"
    echo "  all       - Todos os serviços"
    echo "  postgres  - PostgreSQL + pgAdmin"
    echo "  mongo     - MongoDB + Mongo Express"
    echo "  redis     - Redis + RedisInsight"
    echo "  kafka     - Kafka + Zookeeper + Kafdrop + Kafka UI"
    echo "  airflow   - Apache Airflow"
    echo "  mysql     - MySQL"
    echo "  mssql     - Microsoft SQL Server"
    echo "  oracle    - Oracle Database"
    echo "  ftp       - Servidor FTP"
    echo "  sonar     - SonarQube"
    echo ""
    echo "EXEMPLOS:"
    echo "  $0 start all          # Iniciar todos os serviços"
    echo "  $0 start postgres     # Iniciar apenas PostgreSQL"
    echo "  $0 status all         # Verificar status de todos"
    echo "  $0 logs airflow       # Ver logs do Airflow"
}

# Função para verificar se o arquivo .env existe
check_env() {
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}Arquivo .env não encontrado. Copiando de env.example...${NC}"
        cp env.example .env
        echo -e "${GREEN}Arquivo .env criado. Ajuste as configurações conforme necessário.${NC}"
    fi
}

# Função para carregar variáveis de ambiente
load_env() {
    if [ -f ".env" ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi
}

# Função para executar comando em um serviço
run_service_command() {
    local command=$1
    local service=$2
    local service_dir=""
    
    case $service in
        "postgres")
            service_dir="PostgreSQL"
            ;;
        "mongo")
            service_dir="MongoDb"
            ;;
        "redis")
            service_dir="Redis"
            ;;
        "kafka")
            service_dir="kafka"
            ;;
        "airflow")
            service_dir="AirFLow"
            ;;
        "mysql")
            service_dir="Mysql"
            ;;
        "mssql")
            service_dir="MSSQL"
            ;;
        "oracle")
            service_dir="Oracle"
            ;;
        "ftp")
            service_dir="Ftp"
            ;;
        "sonar")
            service_dir="Sonar"
            ;;
        *)
            echo -e "${RED}Serviço '$service' não reconhecido.${NC}"
            exit 1
            ;;
    esac
    
    if [ -d "$service_dir" ]; then
        cd "$service_dir"
        docker-compose $command
        cd ..
    else
        echo -e "${RED}Diretório do serviço '$service' não encontrado.${NC}"
        exit 1
    fi
}

# Função para executar comando em todos os serviços
run_all_services_command() {
    local command=$1
    local services=("postgres" "mongo" "redis" "kafka" "airflow" "mysql" "mssql" "oracle" "ftp" "sonar")
    
    for service in "${services[@]}"; do
        if [ -d "$(echo $service | sed 's/^./\U&/')" ] || [ -d "$service" ]; then
            echo -e "${BLUE}Executando $command em $service...${NC}"
            run_service_command $command $service
        fi
    done
}

# Função para fazer backup
do_backup() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${BLUE}Fazendo backup dos dados...${NC}"
    
    # Backup PostgreSQL
    if [ -d "PostgreSQL/DataBase" ]; then
        echo "Backup PostgreSQL..."
        cp -r PostgreSQL/DataBase "$backup_dir/"
    fi
    
    # Backup MongoDB
    if [ -d "MongoDb/DataBase" ]; then
        echo "Backup MongoDB..."
        cp -r MongoDb/DataBase "$backup_dir/"
    fi
    
    # Backup MySQL
    if [ -d "Mysql/DataBase" ]; then
        echo "Backup MySQL..."
        cp -r Mysql/DataBase "$backup_dir/"
    fi
    
    # Backup MSSQL
    if [ -d "MSSQL/DataBase" ]; then
        echo "Backup MSSQL..."
        cp -r MSSQL/DataBase "$backup_dir/"
    fi
    
    # Backup Oracle
    if [ -d "Oracle/DataBase" ]; then
        echo "Backup Oracle..."
        cp -r Oracle/DataBase "$backup_dir/"
    fi
    
    echo -e "${GREEN}Backup concluído em: $backup_dir${NC}"
}

# Função para limpar containers e volumes
do_clean() {
    echo -e "${YELLOW}Limpando containers e volumes...${NC}"
    
    # Parar todos os serviços
    run_all_services_command "down"
    
    # Remover containers órfãos
    docker container prune -f
    
    # Remover volumes não utilizados
    docker volume prune -f
    
    # Remover redes não utilizadas
    docker network prune -f
    
    echo -e "${GREEN}Limpeza concluída!${NC}"
}

# Função para mostrar status
show_status() {
    local service=$1
    
    if [ "$service" = "all" ]; then
        echo -e "${BLUE}=== STATUS DE TODOS OS SERVIÇOS ===${NC}"
        local services=("postgres" "mongo" "redis" "kafka" "airflow" "mysql" "mssql" "oracle" "ftp" "sonar")
        
        for service in "${services[@]}"; do
            if [ -d "$(echo $service | sed 's/^./\U&/')" ] || [ -d "$service" ]; then
                echo -e "${BLUE}--- $service ---${NC}"
                run_service_command "ps" $service
                echo ""
            fi
        done
    else
        echo -e "${BLUE}=== STATUS DO SERVIÇO: $service ===${NC}"
        run_service_command "ps" $service
    fi
}

# Função para mostrar logs
show_logs() {
    local service=$1
    
    if [ "$service" = "all" ]; then
        echo -e "${RED}Para ver logs de todos os serviços, especifique um serviço específico.${NC}"
        exit 1
    else
        echo -e "${BLUE}=== LOGS DO SERVIÇO: $service ===${NC}"
        run_service_command "logs -f" $service
    fi
}

# Verificar argumentos
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Carregar configurações
check_env
load_env

# Processar comandos
case $1 in
    "start")
        if [ "$2" = "all" ]; then
            run_all_services_command "up -d"
        else
            run_service_command "up -d" $2
        fi
        ;;
    "stop")
        if [ "$2" = "all" ]; then
            run_all_services_command "down"
        else
            run_service_command "down" $2
        fi
        ;;
    "restart")
        if [ "$2" = "all" ]; then
            run_all_services_command "restart"
        else
            run_service_command "restart" $2
        fi
        ;;
    "status")
        show_status $2
        ;;
    "logs")
        show_logs $2
        ;;
    "clean")
        do_clean
        ;;
    "backup")
        do_backup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${RED}Comando '$1' não reconhecido.${NC}"
        show_help
        exit 1
        ;;
esac 