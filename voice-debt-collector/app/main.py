from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.db import init_db
from app.routes.calls import router as calls_router
from app.routes.twilio_webhooks import router as twilio_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="AI Debt Collection Voice Bot",
    description="Autonomous outbound voice agent that calls customers about overdue payments.",
    lifespan=lifespan,
)

app.include_router(calls_router)
app.include_router(twilio_router)


@app.get("/health")
def health():
    return {"status": "ok"}
