// ===============================
// Car Tinder - Backend Server
// ===============================
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const db = require('./db/connection');

const app = express();

// ---------- MIDDLEWARE ----------
app.use(cors());
app.use(express.json());

// Serve frontend files
app.use(express.static(path.join(__dirname, 'public')));

// ---------- ROOT ----------
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ===============================
// 🚘 GET ALL CARS
// ===============================
app.get('/cars', (req, res) => {
  const sql = `
    SELECT 
      c.car_id, c.brand, c.model, c.year, c.price, c.fuel_type, c.transmission, 
      c.seating_capacity, c.image_url, d.dealer_name,
      get_avg_rating(c.car_id) AS avg_rating,
      get_total_likes(c.car_id) AS total_likes
    FROM Cars c
    LEFT JOIN Dealers d ON c.dealer_id = d.dealer_id;
  `;

  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// ===============================
// ❤️ LIKE A CAR
// ===============================
app.post("/api/like", (req, res) => {
  const { user_id, car_id } = req.body;

  if (!user_id || !car_id)
    return res.status(400).json({ message: "Missing data" });

  const sql = `
    INSERT INTO LikedCars (user_id, car_id)
    VALUES (?, ?)
    ON DUPLICATE KEY UPDATE liked_at = NOW()
  `;

  db.query(sql, [user_id, car_id], (err) => {
    if (err) return res.status(500).json({ message: "DB error" });
    res.json({ message: "Car liked!" });
  });
});

// ===============================
// ❤️ RESET LIKES
// ===============================
app.delete("/api/resetLikes", (req, res) => {
  const { user_id } = req.body;

  const sql = `DELETE FROM LikedCars WHERE user_id = ?`;
  db.query(sql, [user_id], (err) => {
    if (err) return res.status(500).json({ message: "DB error" });
    res.json({ message: "Likes reset successfully!" });
  });
});

// ===============================
// 📅 BOOK TEST DRIVE (WITH ERROR HANDLING)
// ===============================
app.post('/testdrive', (req, res) => {
  const { user_id, car_id, date } = req.body;

  if (!user_id || !car_id || !date)
    return res.status(400).json({ message: "Missing fields" });

  const sql = 'CALL book_test_drive(?, ?, ?)';

  db.query(sql, [user_id, car_id, date], (err) => {
    if (err) {
      if (err.sqlState === '45000') {
        return res.status(400).json({ message: "You already booked this car on this date." });
      }
      return res.status(500).json({ message: err.message });
    }
    res.json({ message: 'Test drive booked successfully!' });
  });
});

// ===============================
// ❤️ GET LIKED CARS
// ===============================
app.get('/liked/:userId', (req, res) => {
  const { userId } = req.params;

  const sql = 'CALL get_liked_cars(?)';
  db.query(sql, [userId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    res.json(results[0]);
  });
});

// ===============================
// Dealer logs
// ===============================
app.get('/dealer/logs', (req, res) => {
  const sql = 'SELECT * FROM DealerActivityLog ORDER BY logged_at DESC';

  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// ===============================
// START SERVER
// ===============================
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});
