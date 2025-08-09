FROM apache/airflow:3.0.3-python3.12

USER root
RUN apt-get update && apt-get install -y gcc python3-dev

COPY requirements.txt /requirements.txt

USER airflow
RUN pip install --no-cache-dir -r /requirements.txt