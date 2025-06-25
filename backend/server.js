const express = require('express');
const cors = require('cors');
const fs = require('fs');
const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public')); // ⬅️ Вот это добавили

const TRACK_FILE = './currentTrack.json';

app.get('/track', (req, res) => {
  if (fs.existsSync(TRACK_FILE)) {
    const data = fs.readFileSync(TRACK_FILE, 'utf-8');
    const json = JSON.parse(data);
    res.json(json);
  } else {
    res.json({ id: null });
  }
});

app.post('/track', (req, res) => {
  const { id } = req.body;
  if (!id || isNaN(id) || id < 1 || id > 5) {
    return res.status(400).json({ error: 'Invalid track ID' });
  }

  fs.writeFileSync(TRACK_FILE, JSON.stringify({ id: parseInt(id) }));
  res.json({ success: true });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on http://localhost:${port}`);
});
