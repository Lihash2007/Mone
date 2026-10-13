import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Default to a local SQLite database for development if URL not provided
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "sqlite:///./personal_money_os.db"
)

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    # check_same_thread is needed for SQLite
    connect_args={"check_same_thread": False} if SQLALCHEMY_DATABASE_URL.startswith("sqlite") else {}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
