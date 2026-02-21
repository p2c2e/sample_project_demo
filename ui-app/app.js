// app.js -- Express server for the OpenTelemetry UI demo
// IMPORTANT: tracing must be initialized before any other require
require('./tracing.js');

var express = require('express');
var http = require('http');
var path = require('path');

var app = express();
var PORT = parseInt(process.env.UI_APP_PORT || '3000', 10);
var API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://localhost:5001';
var gatewayUrl = new URL(API_GATEWAY_URL);

// Serve static files (index.html)
app.use(express.static(path.join(__dirname, 'public')));

// Helper: proxy a GET request to the api-gateway and return the response
function proxyGet(gatewayPath, res) {
  var options = {
    hostname: gatewayUrl.hostname,
    port: gatewayUrl.port,
    path: gatewayPath,
    method: 'GET',
  };
  var proxyReq = http.request(options, function (apiRes) {
    var data = '';
    apiRes.on('data', function (chunk) { data += chunk; });
    apiRes.on('end', function () {
      res.status(apiRes.statusCode).type('json').send(data);
    });
  });
  proxyReq.on('error', function (err) {
    res.status(502).json({ error: 'Gateway error: ' + err.message });
  });
  proxyReq.end();
}

// Proxy routes
app.get('/api/health', function (req, res) {
  proxyGet('/', res);
});

app.get('/api/items', function (req, res) {
  proxyGet('/items', res);
});

app.get('/api/items/:id', function (req, res) {
  proxyGet('/items/' + req.params.id, res);
});

app.get('/api/order/:item_id', function (req, res) {
  proxyGet('/order/' + req.params.item_id, res);
});

app.listen(PORT, function () {
  console.log('ui-app listening on http://localhost:' + PORT);
});
