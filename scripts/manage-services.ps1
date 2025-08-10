#!/usr/bin/env pwsh
<#!
Cross-platform service manager for Windows (PowerShell). Parity with scripts/manage-services.sh
Usage:
  pwsh scripts/manage-services.ps1 help
  pwsh scripts/manage-services.ps1 start all|postgres|mongo|redis|kafka|airflow|mysql|mssql|oracle|ftp|sonar
#>

param(
  [Parameter(Mandatory=$true)][ValidateSet('start','stop','restart','status','logs','clean','backup','help')]
  [string]$Command,
  [string]$Service = 'all'
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg){ Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg){ Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host $msg -ForegroundColor Red }

# Ensure we run from repo root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir '..')
Set-Location $RootDir

function Show-Help(){
  Write-Info "=== GERENCIADOR DE SERVIÇOS (PowerShell) ==="
  @'
Uso:
  pwsh scripts/manage-services.ps1 [COMANDO] [SERVIÇO]

COMANDOS:
  start     - Iniciar serviços
  stop      - Parar serviços
  restart   - Reiniciar serviços
  status    - Verificar status dos serviços
  logs      - Ver logs dos serviços
  clean     - Limpar containers e volumes
  backup    - Fazer backup dos dados
  help      - Mostrar esta ajuda

SERVIÇOS:
  all | postgres | mongo | redis | kafka | airflow | mysql | mssql | oracle | ftp | sonar
'@
}

function Ensure-DotEnv(){
  if(-not (Test-Path ".env")){
    Write-Warn ".env não encontrado. Copiando de env.example..."
    Copy-Item env.example .env
    Write-Ok ".env criado. Ajuste as configurações conforme necessário."
  }
}

function Load-DotEnv(){
  # Basic .env loader (key=value, ignore comments)
  if(Test-Path .env){
    Get-Content .env | Where-Object { $_ -and ($_ -notmatch '^#') } | ForEach-Object {
      if($_ -match '^(?<k>[^=]+)=(?<v>.*)$'){
        $k = $Matches['k'].Trim()
        $v = $Matches['v']
        # Remove inline comments
        if($v -match '^(.*?)(\s*#.*)$'){ $v = $Matches[1] }
        $v = $v.Trim()
        $env:$k = $v
      }
    }
  }
}

# Prefer docker compose v2 CLI, fallback to legacy docker-compose
function Invoke-Compose($Args){
  try {
    & docker compose @Args
  } catch {
    & docker-compose @Args
  }
}

function Get-ServiceDir($name){
  switch ($name) {
    'postgres' { 'PostgreSQL' }
    'mongo'    { 'MongoDb' }
    'redis'    { 'Redis' }
    'kafka'    { 'kafka' }
    'airflow'  { 'AirFLow' }
    'mysql'    { 'Mysql' }
    'mssql'    { 'MSSQL' }
    'oracle'   { 'Oracle' }
    'ftp'      { 'Ftp' }
    'sonar'    { 'Sonar' }
    default { throw "Serviço '$name' não reconhecido." }
  }
}

function Run-ServiceCommand($composeArgs, $name){
  $dir = Get-ServiceDir $name
  if(Test-Path $dir){
    Push-Location $dir
    Invoke-Compose $composeArgs
    Pop-Location
  } else {
    throw "Diretório do serviço '$name' não encontrado."
  }
}

function Run-All($composeArgs){
  $services = @('postgres','mongo','redis','kafka','airflow','mysql','mssql','oracle','ftp','sonar')
  foreach($s in $services){
    $dir = Get-ServiceDir $s
    if(Test-Path $dir){
      Write-Info "Executando $($composeArgs -join ' ') em $s..."
      Run-ServiceCommand $composeArgs $s
    }
  }
}

function Do-Backup(){
  $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $backupDir = Join-Path 'backups' $timestamp
  New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

  Write-Info 'Fazendo backup dos dados...'
  $pairs = @(
    @{ src='PostgreSQL/DataBase'; name='PostgreSQL' }
    @{ src='MongoDb/DataBase';   name='MongoDB' }
    @{ src='Mysql/DataBase';     name='MySQL' }
    @{ src='MSSQL/DataBase';     name='MSSQL' }
    @{ src='Oracle/DataBase';    name='Oracle' }
  )
  foreach($p in $pairs){
    if(Test-Path $p.src){
      Write-Host "Backup $($p.name)..."
      Copy-Item -Recurse -Force $p.src $backupDir
    }
  }
  Write-Ok "Backup concluído em: $backupDir"
}

function Do-Clean(){
  Write-Warn 'Limpando containers, volumes e redes não utilizadas...'
  Run-All @('down')
  & docker container prune -f | Out-Null
  & docker volume prune -f | Out-Null
  & docker network prune -f | Out-Null
  Write-Ok 'Limpeza concluída!'
}

function Show-Status($name){
  if($name -eq 'all'){
    Write-Info '=== STATUS DE TODOS OS SERVIÇOS ==='
    Run-All @('ps')
  } else {
    Write-Info "=== STATUS DO SERVIÇO: $name ==="
    Run-ServiceCommand @('ps') $name
  }
}

function Show-Logs($name){
  if($name -eq 'all'){
    Write-Err 'Para ver logs de todos, especifique um serviço específico.'
    exit 1
  }
  Write-Info "=== LOGS DO SERVIÇO: $name ==="
  Run-ServiceCommand @('logs','-f') $name
}

if($Command -eq 'help'){
  Show-Help
  exit 0
}

Ensure-DotEnv
Load-DotEnv

switch ($Command) {
  'start'   { if($Service -eq 'all'){ Run-All @('up','-d') } else { Run-ServiceCommand @('up','-d') $Service } }
  'stop'    { if($Service -eq 'all'){ Run-All @('down') } else { Run-ServiceCommand @('down') $Service } }
  'restart' { if($Service -eq 'all'){ Run-All @('restart') } else { Run-ServiceCommand @('restart') $Service } }
  'status'  { Show-Status $Service }
  'logs'    { Show-Logs $Service }
  'clean'   { Do-Clean }
  'backup'  { Do-Backup }
  default   { Show-Help; exit 1 }
}