from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, make_asgi_app
import logging
import os

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "info").upper(),
    format='{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}',
)
log = logging.getLogger("vaultai-api")

app = FastAPI(title="VaultAI API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten to real frontend origin before real prod use
    allow_methods=["*"],
    allow_headers=["*"],
)

REQUEST_COUNT = Counter("vaultai_requests_total", "Total requests", ["endpoint"])

# Prometheus scrape target
app.mount("/metrics", make_asgi_app())


@app.get("/healthz")
def healthz():
    REQUEST_COUNT.labels(endpoint="healthz").inc()
    return {"status": "ok", "service": "vaultai-api"}


@app.get("/readyz")
def readyz():
    # extend this to check DB connectivity once models are wired up
    return {"status": "ready"}


@app.post("/api/v1/caption")
def generate_caption(payload: dict):
    """
    Placeholder for AI caption generation.
    Wire this to the Anthropic API (or whichever provider) next.
    """
    REQUEST_COUNT.labels(endpoint="caption").inc()
    topic = payload.get("topic", "")
    log.info(f"caption request topic={topic!r}")
    return {"caption": f"[stub] generated caption for: {topic}"}
