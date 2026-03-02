import os
import time
import random

import requests as http_requests
from flask import Flask, jsonify
from opentelemetry import trace

from otel_setup import init_telemetry

app = Flask(__name__)
init_telemetry("api-gateway", app)

tracer = trace.get_tracer(__name__)

BACKEND_SERVICE_URL = os.environ.get("BACKEND_SERVICE_URL", "http://localhost:5002")

ITEMS = [
    {"id": 1, "name": "Widget A", "price": 9.99},
    {"id": 2, "name": "Widget B", "price": 19.99},
    {"id": 3, "name": "Widget C", "price": 29.99},
]


@app.route("/")
def health():
    return jsonify({"status": "ok"})


@app.route("/items")
def get_items():
    # Simulate a slow DB query
    time.sleep(random.uniform(0.05, 0.2))
    return jsonify(ITEMS)


@app.route("/items/<int:item_id>")
def get_item(item_id):
    # Simulate a slow DB lookup
    time.sleep(random.uniform(0.02, 0.1))

    item = next((i for i in ITEMS if i["id"] == item_id), None)
    if item is None:
        return jsonify({"error": "not found"}), 404

    # Manual span to show custom instrumentation
    with tracer.start_as_current_span("process-item") as span:
        span.set_attribute("item.id", item_id)
        span.set_attribute("item.name", item["name"])
        time.sleep(random.uniform(0.01, 0.05))

    return jsonify(item)


@app.route("/order/<int:item_id>")
def create_order(item_id):
    """Calls backend-service for user info, then combines with local item data.

    This creates a cross-service trace:
        client -> api-gateway (/order) -> backend-service (/users/<id>)
    """
    # Look up item locally
    item = next((i for i in ITEMS if i["id"] == item_id), None)
    if item is None:
        return jsonify({"error": "item not found"}), 404

    # Call the backend service for user info (trace context propagates automatically)
    user_resp = http_requests.get(BACKEND_SERVICE_URL + "/users/1")
    if user_resp.status_code != 200:
        return jsonify({"error": "failed to fetch user"}), 502

    with tracer.start_as_current_span("build-order") as span:
        span.set_attribute("order.item_id", item_id)
        span.set_attribute("order.user_id", 1)
        time.sleep(random.uniform(0.01, 0.03))
        order = {
            "item": item,
            "user": user_resp.json(),
            "total": item["price"],
        }

    return jsonify(order)


if __name__ == "__main__":
    app.run(port=5001)
