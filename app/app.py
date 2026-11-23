"""
Task Manager API - the sample application deployed by the CI/CD pipeline.

It is intentionally small: the point of this project is the pipeline that
tests, containerises and deploys it automatically on every Git change.

Endpoints
---------
GET    /                 simple status page showing the deployed build
GET    /health           health check used by Docker and the pipeline
GET    /api/version      version + Jenkins build number of the running container
GET    /api/tasks        list tasks
POST   /api/tasks        create a task   {"title": "..."}
PATCH  /api/tasks/<id>   update a task   {"title": "...", "done": true}
DELETE /api/tasks/<id>   delete a task
"""

import os
import threading
from datetime import datetime, timezone

from flask import Flask, jsonify, request

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
BUILD_NUMBER = os.getenv("BUILD_NUMBER", "local")
GIT_COMMIT = os.getenv("GIT_COMMIT", "unknown")[:7]
STARTED_AT = datetime.now(timezone.utc).isoformat(timespec="seconds")


def create_app():
    app = Flask(__name__)
    tasks = {}
    counter = {"next_id": 1}
    lock = threading.Lock()   # gunicorn runs several threads; keep ids safe

    def error(message, status=400):
        return jsonify({"error": message}), status

    @app.get("/")
    def index():
        return (
            "<h1>Task Manager API</h1>"
            f"<p>Version <b>{APP_VERSION}</b> · Jenkins build <b>#{BUILD_NUMBER}</b> · "
            f"commit <code>{GIT_COMMIT}</code></p>"
            f"<p>Container started at {STARTED_AT}</p>"
            "<p>Try <a href='/api/tasks'>/api/tasks</a> or <a href='/health'>/health</a></p>"
        )

    @app.get("/health")
    def health():
        return jsonify({"status": "healthy", "build": BUILD_NUMBER})

    @app.get("/api/version")
    def version():
        return jsonify({
            "version": APP_VERSION,
            "build_number": BUILD_NUMBER,
            "git_commit": GIT_COMMIT,
            "started_at": STARTED_AT,
        })

    @app.get("/api/tasks")
    def list_tasks():
        done = request.args.get("done")
        items = list(tasks.values())
        if done in ("true", "false"):
            items = [t for t in items if t["done"] == (done == "true")]
        return jsonify(items)

    @app.post("/api/tasks")
    def create_task():
        data = request.get_json(silent=True) or {}
        title = (data.get("title") or "").strip()
        if not title:
            return error("'title' is required")
        if len(title) > 120:
            return error("'title' must be 120 characters or fewer")
        with lock:
            task_id = counter["next_id"]
            counter["next_id"] += 1
            task = {"id": task_id, "title": title, "done": False,
                    "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds")}
            tasks[task_id] = task
        return jsonify(task), 201

    @app.patch("/api/tasks/<int:task_id>")
    def update_task(task_id):
        task = tasks.get(task_id)
        if not task:
            return error("Task not found", 404)
        data = request.get_json(silent=True) or {}
        if "title" in data:
            title = str(data["title"]).strip()
            if not title:
                return error("'title' cannot be empty")
            task["title"] = title
        if "done" in data:
            if not isinstance(data["done"], bool):
                return error("'done' must be true or false")
            task["done"] = data["done"]
        return jsonify(task)

    @app.delete("/api/tasks/<int:task_id>")
    def delete_task(task_id):
        if tasks.pop(task_id, None) is None:
            return error("Task not found", 404)
        return "", 204

    return app


app = create_app()   # used by gunicorn: "app:app"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
