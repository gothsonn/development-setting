from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import os
import sys

# Permitir importar app do gestor pessoal
sys.path.append("/app")

from app.chatgpt.processor import process_message
from app.db.mongo_client import save_to_mongo
from app.whatsapp.webhook_listener import get_latest_message

default_args = {
    'owner': 'rafael',
    'depends_on_past': False,
    'start_date': datetime(2025, 7, 28),
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

def executar_pipeline():
    msg = get_latest_message()
    if not msg:
        raise ValueError("Nenhuma mensagem recebida")

    result = process_message(msg)

    if result["status"] == "success":
        save_to_mongo(result["data"])
    else:
        raise ValueError(f"Erro: {result.get('error', 'Falha genérica')}")

with DAG(
    dag_id='dag_processa_mensagens',
    default_args=default_args,
    schedule_interval='*/5 * * * *',
    catchup=False,
    tags=['financas', 'chatgpt'],
) as dag:

    processar_mensagem = PythonOperator(
        task_id='processar_mensagem',
        python_callable=executar_pipeline
    )