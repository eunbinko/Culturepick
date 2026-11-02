FROM python:3.13-slim
WORKDIR /workspace
COPY requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY alembic.ini ./
COPY alembic ./alembic
COPY scripts ./scripts
