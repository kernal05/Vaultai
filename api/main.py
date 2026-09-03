from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, make_asgi_app
import logging
import os
from anthropic import Anthropic

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


anthropic_client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))


@app.post("/api/v1/caption")
def generate_caption(payload: dict):
    REQUEST_COUNT.labels(endpoint="caption").inc()
    topic = payload.get("topic", "")
    log.info(f"caption request topic={topic!r}")

    if not topic:
        return {"caption": ""}

    try:
        response = anthropic_client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=100,
            messages=[{
                "role": "user",
                "content": (
                    f"Write one short, warm caption (under 20 words) for a "
                    f"'{topic}' status poster someone will share with friends "
                    f"or family. Return only the caption text, nothing else."
                ),
            }],
        )
        caption = response.content[0].text.strip()
    except Exception as e:
        log.error(f"caption generation failed: {e}")
        caption = f"Wishing you a wonderful {topic.lower()}!"

    return {"caption": caption}
