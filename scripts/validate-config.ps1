#!/usr/bin/env pwsh
<#!
Validation script for Windows (PowerShell). Mirrors scripts/validate-config.sh checks.
Usage:
  pwsh scripts/validate-config.ps1
#>

$ErrorActionPreference = 'Stop'

function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

# Move to repo root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir '..')
Set-Location $RootDir

if(-not (Test-Path 'env.example')){ Fail 'env.example não encontrado no diretório raiz' }

$required = @(
  'NETWORK_NAME',
  'POSTGRES_USER','POSTGRES_PASSWORD','POSTGRES_PORT','PGADMIN_EMAIL','PGADMIN_PASSWORD','PGADMIN_PORT',
  'MONGO_ROOT_USERNAME','MONGO_ROOT_PASSWORD','MONGO_PORT','MONGO_EXPRESS_USERNAME','MONGO_EXPRESS_PASSWORD','MONGO_EXPRESS_PORT',
  'REDIS_PORT','REDIS_INSIGHT_PORT',
  'KAFKA_PORT','KAFDROP_PORT','KAFKA_UI_PORT',
  'AIRFLOW_PORT','AIRFLOW_DB_CONNECTION',
  'WORKSPACE_PATH','GESTOR_PESSOAL_PATH'
)

function Get-VarFromEnvExample([string]$key){
  $line = Select-String -Path 'env.example' -Pattern "^$key=" -SimpleMatch | Select-Object -First 1
  if(-not $line){ return '' }
  $val = ($line.Line -replace "^$key=", '')
  # strip inline comment
  if($val -match '^(.*?)(\s*#.*)$'){ $val = $Matches[1] }
  $val.Trim()
}

$missing = @()
foreach($k in $required){
  $val = Get-VarFromEnvExample $k
  if([string]::IsNullOrEmpty($val)){
    $missing += $k
  }
}
if($missing.Count -gt 0){
  Fail "Variáveis ausentes em env.example: $($missing -join ', ')"
} else {
  Ok 'Todas as variáveis obrigatórias estão definidas em env.example'
}

$compose = @(
  'PostgreSQL/docker-compose.yml',
  'MongoDb/docker-compose.yml',
  'Redis/docker-compose.yml',
  'kafka/docker-compose.yml',
  'AirFLow/docker-compose.yaml',
  'Sonar/docker-compose.yml'
)
foreach($f in $compose){ if(Test-Path $f){ Ok "Encontrado $f" } else { Fail "Arquivo ausente: $f" } }

$vols = @(
  'PostgreSQL/DataBase',
  'MongoDb/DataBase',
  'AirFLow/dags','AirFLow/logs','AirFLow/plugins','AirFLow/config'
)
foreach($d in $vols){ if(Test-Path $d){ Ok "Diretório presente: $d" } else { Fail "Diretório ausente: $d" } }

# Sonar network name warning
$sonarText = Get-Content 'Sonar/docker-compose.yml' -ErrorAction SilentlyContinue -Raw
if($sonarText -and $sonarText -match 'local-services-network'){
  $net = Get-VarFromEnvExample 'NETWORK_NAME'
  if($net -ne 'local-services-network'){
    Warn "Sonar/docker-compose.yml usa rede fixa 'local-services-network' (NETWORK_NAME atual: '${net}'). Ajuste se necessário."
  } else {
    Ok "Sonar usa 'local-services-network' e NETWORK_NAME corresponde"
  }
} else {
  Warn 'Não foi possível detectar rede fixa em Sonar/docker-compose.yml'
}

# Airflow connection check
$airConn = Get-VarFromEnvExample 'AIRFLOW_DB_CONNECTION'
$pgPort = Get-VarFromEnvExample 'POSTGRES_PORT'
if(($airConn -like "*host.docker.internal:*$pgPort*") -or ($airConn -like "*localhost:*$pgPort*")){
  Ok "AIRFLOW_DB_CONNECTION parece apontar para host.docker.internal:$pgPort"
} else {
  Warn "AIRFLOW_DB_CONNECTION pode não apontar para host.docker.internal:$pgPort -> $airConn"
}

if(Test-Path 'scripts/manage-services.ps1'){
  Ok 'scripts/manage-services.ps1 encontrado'
} else {
  Warn 'scripts/manage-services.ps1 não encontrado'
}

Write-Host 'Validações concluídas com sucesso.' -ForegroundColor Cyan