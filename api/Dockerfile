FROM python:3.12-slim

WORKDIR /app

RUN groupadd -r vaultai && useradd -r -g vaultai vaultai

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chown -R vaultai:vaultai /app
USER vaultai

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1

CMD ["uvicorn", "metrics:app", "--host", "0.0.0.0", "--port", "8000"]
