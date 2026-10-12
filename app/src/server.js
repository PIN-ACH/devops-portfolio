'use strict';

require('dotenv').config();
const app = require('./app');
const db = require('./db');

const PORT = Number(process.env.PORT || 3000);

const server = app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', msg: `listening on :${PORT}` }));
});

// Graceful shutdown so Kubernetes rolling updates don't drop connections.
function shutdown(signal) {
  console.log(JSON.stringify({ level: 'info', msg: `received ${signal}, shutting down` }));
  server.close(async () => {
    await db.close();
    process.exit(0);
  });
  // Force-exit if cleanup hangs.
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = server;
