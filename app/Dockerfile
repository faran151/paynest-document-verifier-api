FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

ENV PORT=8000
ENV LOG_LEVEL=info
ENV ENVIRONMENT=local

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
