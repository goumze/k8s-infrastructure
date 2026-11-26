"""Flask API front door for the financial-advisor orchestrator.

Runs as its own pod (not an agent). Every request is forwarded to the
orchestrator through Agent Gateway, authenticated with this pod's projected
ServiceAccount token (audience agent-gateway), the same way the agents call
each other. Swagger UI is served at /apidocs/.
"""
from __future__ import annotations

import os
from pathlib import Path

import requests
from flasgger import Swagger
from flask import Flask, jsonify, request

GATEWAY_URL = os.getenv(
    "A2A_GATEWAY_URL",
    "http://agent-gateway-proxy.agentgateway-system.svc.cluster.local:8080",
)
TARGET_AGENT = os.getenv("TARGET_AGENT", "financial-advisor")
TOKEN_PATH = Path(
    os.getenv("AGENT_GATEWAY_TOKEN_PATH", "/var/run/secrets/agent-gateway/token")
)
TIMEOUT_SECONDS = float(os.getenv("ORCHESTRATOR_TIMEOUT_SECONDS", "180"))

app = Flask(__name__)
Swagger(
    app,
    template={
        "info": {
            "title": "Financial Services API",
            "description": "Entry point that forwards requests to the financial-advisor orchestrator via Agent Gateway.",
            "version": "1.0.0",
        },
    },
)


def _read_token() -> str:
    # Read per request: the kubelet rotates projected tokens.
    try:
        return TOKEN_PATH.read_text().strip()
    except FileNotFoundError:
        return ""


@app.get("/healthz")
def healthz():
    """Liveness and readiness probe.
    ---
    tags:
      - health
    responses:
      200:
        description: Service is up.
    """
    return jsonify(status="healthy")


@app.post("/api/v1/advise")
def advise():
    """Send a task to the financial-advisor orchestrator.
    ---
    tags:
      - advisor
    consumes:
      - application/json
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - task
          properties:
            task:
              type: string
              example: "Review my portfolio of AAPL and GOOGL and assess risk."
    responses:
      200:
        description: Orchestrator result.
        schema:
          type: object
          properties:
            result:
              type: string
      400:
        description: Missing or invalid task.
      401:
        description: Agent Gateway rejected this pod's token.
      403:
        description: Agent Gateway denied this pod access to the orchestrator.
      502:
        description: Orchestrator or gateway unreachable, or returned an error.
    """
    body = request.get_json(silent=True) or {}
    task = body.get("task")
    if not isinstance(task, str) or not task.strip():
        return jsonify(error="'task' must be a non-empty string"), 400

    headers = {"Content-Type": "application/json"}
    token = _read_token()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        upstream = requests.post(
            f"{GATEWAY_URL}/agents/{TARGET_AGENT}",
            headers=headers,
            json={"task": task},
            timeout=TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        return jsonify(error=f"gateway unreachable: {exc}"), 502

    if upstream.status_code in (401, 403):
        return jsonify(error="gateway denied request", status=upstream.status_code), upstream.status_code
    if not upstream.ok:
        return jsonify(error=f"orchestrator returned HTTP {upstream.status_code}"), 502

    payload = upstream.json()
    if "error" in payload:
        return jsonify(error=payload["error"]), 502
    return jsonify(result=payload.get("result", ""))
