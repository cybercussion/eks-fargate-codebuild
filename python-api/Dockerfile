FROM public.ecr.aws/docker/library/python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN apt-get update && apt-get install -y curl \
    && pip install --no-cache-dir -r requirements.txt \
    && useradd -m -r appuser \
    && chown appuser:appuser /app \
    && rm -rf /var/lib/apt/lists/*

COPY app ./app

USER appuser
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:5000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]