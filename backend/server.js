const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { MongoClient, ObjectId } = require('mongodb');

const app = express();
const port = process.env.PORT || 3000;

const mongoUri = "mongodb+srv://jhifarskiy:83leva35@eatune.8vrsmid.mongodb.net/?retryWrites=true&w=majority&appName=Eatune";
const client = new MongoClient(mongoUri);
const dbName = 'eatune';
const collectionName = 'tracks';
let tracksCollection;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Очередь треков (массив треков)
let playlistQueue = [];

// Индекс текущего трека
let currentIndex = -1;

// Кэш базовых треков
let baseTracks = [];

// Загрузка базовых треков из базы
async function loadBaseTracks() {
  if (!tracksCollection) return;
  baseTracks = await tracksCollection.find({}).toArray();
  if (baseTracks.length === 0) {
    console.warn('[WARN] Нет базовых треков в базе');
  }
}
loadBaseTracks();

// Получение текущего трека (с учётом очереди или базовых)
function getCurrentTrack() {
  if (playlistQueue.length > 0 && currentIndex >= 0 && currentIndex < playlistQueue.length) {
    return playlistQueue[currentIndex];
  }

  if (baseTracks.length === 0) return null;

  if (currentIndex === -1) currentIndex = 0; // 👈 фикс

  const baseIndex = currentIndex % baseTracks.length;
  return baseTracks[baseIndex];
}

// GET текущий трек
app.get('/playlist/current', (req, res) => {
  const track = getCurrentTrack();
  if (!track) return res.json(null);

  res.json({
    id: track._id.toString(),
    title: track.title || "Без названия",
    artist: track.artist || "Неизвестный исполнитель",
    duration: track.duration || "0:00",
    trackUrl: track.url,
    coverUrl: track.coverUrl || null
  });
});

// GET все базовые треки
app.get('/tracks', async (req, res) => {
  if (!tracksCollection) return res.status(503).json({ error: "Database not connected" });
  try {
    const tracksFromDb = await tracksCollection.find({}).toArray();
    baseTracks = tracksFromDb;

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

// POST добавить трек в очередь
app.post('/playlist/add', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'Track ID is required' });
  if (!tracksCollection) return res.status(503).json({ error: 'Database not connected' });

  try {
    const track = await tracksCollection.findOne({ _id: new ObjectId(id) });
    if (!track) return res.status(404).json({ error: 'Track not found' });

    playlistQueue.push(track);
    if (currentIndex === -1) currentIndex = 0;

    console.log(`[OK] Track added to queue: ${track.title}`);
    res.json({ success: true, queueLength: playlistQueue.length });
  } catch (error) {
    console.error('[ERROR] Failed to add track to queue:', error);
    res.status(500).json({ error: 'Failed to add track to queue' });
  }
});

// POST перейти к следующему треку
app.post('/playlist/next', (req, res) => {
  if (playlistQueue.length === 0) {
    currentIndex = (currentIndex + 1) % (baseTracks.length || 1);
  } else {
    currentIndex++;
    if (currentIndex >= playlistQueue.length) {
      playlistQueue = [];
      currentIndex = 0;
    }
  }

  const track = getCurrentTrack();
  if (!track) return res.json(null);

  res.json({
    id: track._id.toString(),
    title: track.title || "Без названия",
    artist: track.artist || "Неизвестный исполнитель",
    duration: track.duration || "0:00",
    trackUrl: track.url,
    coverUrl: track.coverUrl || null
  });
});

// GET длина очереди
app.get('/playlist/length', (req, res) => {
  res.json({ length: playlistQueue.length });
});

// Запуск сервера и подключение к БД
async function startServer() {
  try {
    await client.connect();
    console.log("MongoDB connected successfully.");
    const db = client.db(dbName);
    tracksCollection = db.collection(collectionName);
    await loadBaseTracks();

    app.listen(port, '0.0.0.0', () => {
      console.log(`Server running on http://localhost:${port}`);
      console.log(`Player available at http://localhost:${port}/player.html`);
    });
  } catch (error) {
    console.error("Fatal: Could not connect to MongoDB.", error);
    process.exit(1);
  }
}

startServer();

// DEBUG: Получить текущую очередь
app.get('/playlist/queue', (req, res) => {
  res.json({
    queue: playlistQueue.map(t => ({
      id: t._id.toString(),
      title: t.title
    })),
    currentIndex
  });
});