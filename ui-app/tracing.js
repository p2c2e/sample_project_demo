// tracing.js -- OpenTelemetry manual setup for ui-app
// Must be loaded BEFORE express and http modules

require('dotenv').config();

var sdkTraceNode = require('@opentelemetry/sdk-trace-node');
var sdkTraceBase = require('@opentelemetry/sdk-trace-base');
var resources = require('@opentelemetry/resources');
var semconv = require('@opentelemetry/semantic-conventions');
var OTLPTraceExporter = require('@opentelemetry/exporter-trace-otlp-http').OTLPTraceExporter;
var HttpInstrumentation = require('@opentelemetry/instrumentation-http').HttpInstrumentation;
var ExpressInstrumentation = require('@opentelemetry/instrumentation-express').ExpressInstrumentation;
var registerInstrumentations = require('@opentelemetry/instrumentation').registerInstrumentations;

var otelEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318';
var serviceName = process.env.OTEL_SERVICE_NAME || 'ui-app';

// Create resource with service name
var resource = new resources.Resource({
  [semconv.ATTR_SERVICE_NAME]: serviceName,
});

// Create OTLP exporter
var otlpExporter = new OTLPTraceExporter({
  url: otelEndpoint + '/v1/traces',
});

// Create tracer provider
var provider = new sdkTraceNode.NodeTracerProvider({
  resource: resource,
  spanProcessors: [
    new sdkTraceBase.BatchSpanProcessor(otlpExporter),
  ],
});

// Register as global tracer provider
provider.register();

// Register instrumentations
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});

console.log('[tracing] OpenTelemetry initialized for ' + serviceName);
console.log('[tracing] Exporting to: ' + otelEndpoint + '/v1/traces');

// Graceful shutdown
function shutdown() {
  provider.shutdown()
    .then(function () {
      console.log('[tracing] Provider shut down');
    })
    .catch(function (err) {
      console.error('[tracing] Shutdown error:', err);
    })
    .finally(function () {
      process.exit(0);
    });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
