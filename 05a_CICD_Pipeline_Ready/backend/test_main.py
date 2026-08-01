# -*- coding: utf-8 -*-
"""Unit tests for StoryGen Backend API.

This module contains unit tests for FastAPI endpoints in main.py,
including root and health check endpoints.
"""

from typing import Dict, Any
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_read_root() -> None:
    """Test the root endpoint (/) returns correct version and message."""
    response = client.get("/")
    assert response.status_code == 200
    
    data: Dict[str, Any] = response.json()
    assert data["message"] == "StoryGen Backend API"
    assert "version" in data
    assert "workflow" in data


def test_health_check() -> None:
    """Test the health check endpoint (/health) returns healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    
    data: Dict[str, Any] = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "storygen-backend"
