"""Unit tests run by the Jenkins 'Test' stage.   Run locally:  python -m pytest -v"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest  # noqa: E402

from app import create_app  # noqa: E402


@pytest.fixture
def client():
    return create_app().test_client()


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "healthy"


def test_version(client):
    body = client.get("/api/version").get_json()
    assert {"version", "build_number", "git_commit", "started_at"} <= body.keys()


def test_index_page(client):
    assert b"Task Manager API" in client.get("/").data


def test_create_and_list_tasks(client):
    res = client.post("/api/tasks", json={"title": "Write Jenkinsfile"})
    assert res.status_code == 201
    assert res.get_json()["id"] == 1
    client.post("/api/tasks", json={"title": "Build Docker image"})
    assert len(client.get("/api/tasks").get_json()) == 2


def test_create_task_validation(client):
    assert client.post("/api/tasks", json={}).status_code == 400
    assert client.post("/api/tasks", json={"title": "x" * 121}).status_code == 400


def test_update_task(client):
    client.post("/api/tasks", json={"title": "Deploy container"})
    res = client.patch("/api/tasks/1", json={"done": True})
    assert res.get_json()["done"] is True
    assert len(client.get("/api/tasks?done=true").get_json()) == 1
    assert len(client.get("/api/tasks?done=false").get_json()) == 0
    assert client.patch("/api/tasks/1", json={"done": "yes"}).status_code == 400
    assert client.patch("/api/tasks/99", json={"done": True}).status_code == 404


def test_delete_task(client):
    client.post("/api/tasks", json={"title": "Temp"})
    assert client.delete("/api/tasks/1").status_code == 204
    assert client.delete("/api/tasks/1").status_code == 404
