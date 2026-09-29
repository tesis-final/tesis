# ATLAS — contenedor atlas-analysis (PDF Tabla 15: python:3.11-slim).
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /srv/atlas/analysis
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app ./app

# Corre sin privilegios (CT-11); no escribe archivos.
USER 65534:65534
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--no-server-header"]
