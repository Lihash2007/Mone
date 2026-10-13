import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.db.base import Base
from app.db.session import get_db

# Setup a test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_money_os.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Welcome to Personal Money OS API"}

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

import uuid

def test_create_user(email=None):
    email = email or f"test_{uuid.uuid4()}@example.com"
    response = client.post(
        "/api/v1/users/",
        json={"email": email, "password": "password123"}
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["email"] == email
    assert "id" in data
    
    return data["id"]

def test_create_account():
    # first create a user
    user_id = test_create_user()
    
    response = client.post(
        f"/api/v1/accounts/?user_id={user_id}",
        json={
            "user_id": user_id,
            "institution": "HDFC",
            "type": "BANK",
            "currency": "INR"
        }
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["institution"] == "HDFC"
    assert "id" in data
    
    return user_id, data["id"]

def test_create_transaction():
    user_id, account_id = test_create_account()
    
    response = client.post(
        f"/api/v1/transactions/?user_id={user_id}",
        json={
            "amount": 500.0,
            "merchant": "Swiggy",
            "type": "EXPENSE",
            "account_id": account_id,
            "category": "Food"
        }
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["amount"] == 500.0
    assert data["merchant"] == "Swiggy"
