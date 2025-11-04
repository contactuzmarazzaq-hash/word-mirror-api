const express = require("express");
const { Pool } = require("pg");

const app = express();
const PORT = process.env.PORT || 4004;

// Enable JSON body parsing
app.use(express.json());

// Database connection pool
const pool = new Pool({
  host: process.env.PGHOST || "localhost",
  user: process.env.PGUSER || "pgadmin",
  password: process.env.PGPASSWORD || "Password123!",
  database: process.env.PGDATABASE || "mirror_db",
  port: process.env.PGPORT || 5432,
});

// Create table if it doesn't exist
(async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS mirrored_words (
        id SERIAL PRIMARY KEY,
        input_word TEXT NOT NULL,
        mirrored_word TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log("✅ Database table ready.");
  } catch (err) {
    console.error("❌ DB init error:", err);
  }
})();

// Health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

// GET mirror endpoint (existing)
app.get("/api/mirror", async (req, res) => {
  const { word } = req.query;

  if (!word) {
    return res.status(400).json({ error: "Missing 'word' parameter" });
  }

  const transformed = word
    .split("")
    .map((ch) =>
      ch === ch.toUpperCase() && /[A-Z]/.test(ch)
        ? ch.toLowerCase()
        : ch === ch.toLowerCase() && /[a-z]/.test(ch)
        ? ch.toUpperCase()
        : ch
    )
    .reverse()
    .join("");

  try {
    await pool.query(
      "INSERT INTO mirrored_words (input_word, mirrored_word) VALUES ($1, $2)",
      [word, transformed]
    );
  } catch (err) {
    console.error("❌ Error inserting into DB:", err);
  }

  res.json({ transformed });
});

// NEW: POST mirror endpoint
app.post("/api/mirror", async (req, res) => {
  const { text } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Missing 'text' in request body" });
  }

  const transformed = text
    .split("")
    .map((ch) =>
      ch === ch.toUpperCase() && /[A-Z]/.test(ch)
        ? ch.toLowerCase()
        : ch === ch.toLowerCase() && /[a-z]/.test(ch)
        ? ch.toUpperCase()
        : ch
    )
    .reverse()
    .join("");

  try {
    await pool.query(
      "INSERT INTO mirrored_words (input_word, mirrored_word) VALUES ($1, $2)",
      [text, transformed]
    );
  } catch (err) {
    console.error("❌ Error inserting into DB:", err);
  }

  res.json({ transformed });
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
