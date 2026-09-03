FROM python:3.12-slim@sha256:af4e85f1cac90dd3771e47292ea7c6531ce028f3cf0e7756d5023b179ee9066

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

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
