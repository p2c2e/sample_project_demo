# NOTE: This file is duplicated in api-gateway/ and backend-service/ -- keep them in sync
import os

from opentelemetry import trace
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Ensure the SDK is not disabled
os.environ.pop("OTEL_SDK_DISABLED", None)


def init_telemetry(service_name, flask_app):
    """Set up OpenTelemetry tracing with OTLP exporter."""
    resource = Resource.create(attributes={SERVICE_NAME: service_name})
    provider = TracerProvider(resource=resource)

    otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")
    provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=otlp_endpoint + "/v1/traces"))
    )

    trace.set_tracer_provider(provider)

    FlaskInstrumentor().instrument_app(flask_app)
    RequestsInstrumentor().instrument()
