import time
import random

from flask import Flask, jsonify
from opentelemetry import trace

from otel_setup import init_telemetry

app = Flask(__name__)
init_telemetry("backend-service", app)

tracer = trace.get_tracer(__name__)

USERS = [
    {"id": 1, "name": "Alice", "email": "alice@example.com"},
    {"id": 2, "name": "Bob", "email": "bob@example.com"},
    {"id": 3, "name": "Charlie", "email": "charlie@example.com"},
]


@app.route("/")
def health():
    return jsonify({"status": "ok", "service": "backend-service"})


@app.route("/users")
def get_users():
    # Simulate DB query
    time.sleep(random.uniform(0.05, 0.15))
    return jsonify(USERS)


@app.route("/users/<int:user_id>")
def get_user(user_id):
    # Simulate DB lookup
    time.sleep(random.uniform(0.02, 0.08))

    user = next((u for u in USERS if u["id"] == user_id), None)
    if user is None:
        return jsonify({"error": "user not found"}), 404

    # Manual span: simulate enriching user data from a cache or external source
    with tracer.start_as_current_span("enrich-user") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("user.name", user["name"])
        time.sleep(random.uniform(0.01, 0.05))

    return jsonify(user)


if __name__ == "__main__":
    app.run(port=5002)
