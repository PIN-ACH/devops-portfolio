'use strict';

const mysql = require('mysql2/promise');

/**
 * Connection pool to Amazon RDS (MySQL).
 * Credentials are injected via environment variables so that no secret
 * is ever committed to source control. In Kubernetes these come from a
 * Secret; locally they come from a .env file.
 */
let pool;

function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 3306),
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      waitForConnections: true,
      connectionLimit: Number(process.env.DB_POOL_SIZE || 10),
      queueLimit: 0,
      // RDS enforces TLS when the parameter group requires it.
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: true } : undefined,
    });
  }
  return pool;
}

async function query(sql, params) {
  const [rows] = await getPool().execute(sql, params);
  return rows;
}

async function healthcheck() {
  const rows = await query('SELECT 1 AS ok');
  return rows[0].ok === 1;
}

async function close() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

module.exports = { getPool, query, healthcheck, close };
