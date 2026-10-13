from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Personal Money OS API",
    description="Backend API for the India-first personal finance platform",
    version="1.0.0",
)

from app.api.api import api_router

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins, update for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "Welcome to Personal Money OS API"}

@app.get("/health")
async def health_check():
    return {"status": "ok"}
