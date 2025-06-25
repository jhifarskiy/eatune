const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { MongoClient, ObjectId } = require('mongodb');

const app = express();
const port = process.env.PORT || 3000;

// ВАЖНО: Замените <db_password> на ваш реальный пароль
const mongoUri = "mongodb+srv://jhifarskiy:83leva35@eatune.8vrsmid.mongodb.net/?retryWrites=true&w=majority&appName=Eatune";
const client = new MongoClient(mongoUri);
const dbName = 'eatune';
const collectionName = 'tracks';
let tracksCollection;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const CURRENT_TRACK_FILE = path.join(__dirname, 'currentTrack.json');

// Отдает все треки из MongoDB
app.get('/tracks', async (req, res) => {
  if (!tracksCollection) return res.status(503).json({ error: "Database not connected" });
  try {
    const tracksFromDb = await tracksCollection.find({}).toArray();
    console.log(`[OK] Sent ${tracksFromDb.length} tracks to a client.`);
    const formattedTracks = tracksFromDb.map(track => ({
      id: track._id.toString(),
      title: track.title || "Без названия",
      artist: track.artist || "Неизвестный исполнитель",
      duration: track.duration || "0:00",
      trackUrl: track.url,
      coverUrl: track.coverUrl || null
    }));
    res.json(formattedTracks);
  } catch (error) {
    console.error('[ERROR] Failed to fetch tracks:', error);
    res.status(500).json({ error: 'Failed to fetch tracks' });
  }
});

// Отдает текущий играющий трек
app.get('/track', (req, res) => {
  if (fs.existsSync(CURRENT_TRACK_FILE)) {
    try {
      const data = fs.readFileSync(CURRENT_TRACK_FILE, 'utf-8');
      res.json(JSON.parse(data));
    } catch (error) { res.json(null); }
  } else { res.json(null); }
});

// Устанавливает текущий трек
app.post('/track', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'Track ID is required' });
  try {
    const selectedTrack = await tracksCollection.findOne({ _id: new ObjectId(id) });
    if (!selectedTrack) {
      return res.status(404).json({ error: 'Track not found' });
    }
    const trackData = {
        id: selectedTrack._id.toString(),
        title: selectedTrack.title || "Без названия",
        artist: selectedTrack.artist || "Неизвестный исполнитель",
        duration: selectedTrack.duration || "0:00",
        trackUrl: selectedTrack.url,
        coverUrl: selectedTrack.coverUrl || null
    };
    fs.writeFileSync(CURRENT_TRACK_FILE, JSON.stringify(trackData, null, 2));
    console.log(`[OK] Current track set to: ${trackData.title}`);
    res.json({ success: true, track: trackData });
  } catch (error) {
    console.error('[ERROR] Failed to select track:', error);
    res.status(500).json({ error: 'Failed to process selection' });
  }
});

// Запуск сервера и подключение к БД
async function startServer() {
  try {
    await client.connect();
    console.log("MongoDB connected successfully.");
    const db = client.db(dbName);
    tracksCollection = db.collection(collectionName);
    app.listen(port, '0.0.0.0', () => {
      console.log(`Server running on http://localhost:${port}`);
      console.log(`Player is available at http://localhost:${port}/player.html or your public URL.`);
    });
  } catch (error) {
    console.error("Fatal: Could not connect to MongoDB.", error);
    process.exit(1);
  }
}

startServer();
