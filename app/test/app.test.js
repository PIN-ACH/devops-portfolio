'use strict';

/**
 * Unit tests for the HTTP layer. The db module is mocked so these tests
 * run in CI without a live MySQL instance.
 */
const request = require('supertest');

jest.mock('../src/db', () => ({
  query: jest.fn(),
  healthcheck: jest.fn(),
  close: jest.fn(),
}));

const db = require('../src/db');
const app = require('../src/app');

describe('health endpoints', () => {
  test('GET /healthz returns 200', async () => {
    const res = await request(app).get('/healthz');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /readyz returns 200 when DB is healthy', async () => {
    db.healthcheck.mockResolvedValueOnce(true);
    const res = await request(app).get('/readyz');
    expect(res.status).toBe(200);
  });

  test('GET /readyz returns 503 when DB is down', async () => {
    db.healthcheck.mockRejectedValueOnce(new Error('connection refused'));
    const res = await request(app).get('/readyz');
    expect(res.status).toBe(503);
  });
});

describe('messages API', () => {
  test('GET /api/messages returns rows', async () => {
    db.query.mockResolvedValueOnce([{ id: 1, body: 'hello', created_at: '2024-01-01' }]);
    const res = await request(app).get('/api/messages');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].body).toBe('hello');
  });

  test('POST /api/messages validates input', async () => {
    const res = await request(app).post('/api/messages').send({ body: '' });
    expect(res.status).toBe(400);
  });

  test('POST /api/messages inserts a valid message', async () => {
    db.query.mockResolvedValueOnce({ insertId: 42 });
    const res = await request(app).post('/api/messages').send({ body: 'new message' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(42);
  });
});

describe('metrics', () => {
  test('GET /metrics exposes Prometheus format', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('http_request_duration_seconds');
  });
});
