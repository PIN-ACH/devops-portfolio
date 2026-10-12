'use strict';

const express = require('express');
const client = require('prom-client');
const db = require('./db');

const app = express();
app.use(express.json());

// ---------------------------------------------------------------------------
// Prometheus metrics
// ---------------------------------------------------------------------------
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
});
register.registerMetric(httpRequestDuration);

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route ? req.route.path : req.path, status_code: res.statusCode });
  });
  next();
});

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

// Liveness: process is up. No external dependencies checked.
app.get('/healthz', (req, res) => res.status(200).json({ status: 'ok' }));

// Readiness: can we actually serve traffic (DB reachable)?
app.get('/readyz', async (req, res) => {
  try {
    await db.healthcheck();
    res.status(200).json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({ status: 'not-ready', error: err.message });
  }
});

// Prometheus scrape endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// --- Business API: a simple "messages" resource backed by MySQL -------------
app.get('/api/messages', async (req, res, next) => {
  try {
    const rows = await db.query('SELECT id, body, created_at FROM messages ORDER BY id DESC LIMIT 100');
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

app.post('/api/messages', async (req, res, next) => {
  try {
    const { body } = req.body;
    if (!body || typeof body !== 'string' || body.length > 500) {
      return res.status(400).json({ error: 'body is required and must be a string <= 500 chars' });
    }
    // Parameterized query prevents SQL injection.
    const result = await db.query('INSERT INTO messages (body) VALUES (?)', [body]);
    res.status(201).json({ id: result.insertId, body });
  } catch (err) {
    next(err);
  }
});

// Centralized error handler — never leak stack traces to clients.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(JSON.stringify({ level: 'error', msg: err.message }));
  res.status(500).json({ error: 'internal server error' });
});

module.exports = app;
