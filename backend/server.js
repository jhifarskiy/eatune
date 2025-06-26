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

const CURRENT_TRACK_FILE = path.join(__dirname, 'currentTrack.json');
let playlistQueue = [];
let defaultTracks = [];

// Загружаем текущий трек из файла (если был)
let currentTrack = null;
if (fs.existsSync(CURRENT_TRACK_FILE)) {
  try {
    currentTrack = JSON.parse(fs.readFileSync(CURRENT_TRACK_FILE, 'utf-8'));
  } catch (e) {
    currentTrack = null;
  }
}

// Возвращает все треки
app.get('/tracks', async (req, res) => {
  try {
    const tracks = await tracksCollection.find({}).toArray();
    const formatted = tracks.map(t => ({
      id: t._id.toString(),
      title: t.title || "Без названия",
      artist: t.artist || "Неизвестный исполнитель",
      duration: t.duration || "0:00",
      trackUrl: t.url,
      coverUrl: t.coverUrl || null
    }));
    res.json(formatted);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch tracks' });
  }
});

// Добавляет трек в очередь
app.post('/playlist/add', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'Track ID required' });

  try {
    const track = await tracksCollection.findOne({ _id: new ObjectId(id) });
    if (!track) return res.status(404).json({ error: 'Track not found' });

    const formatted = {
      id: track._id.toString(),
      title: track.title || "Без названия",
      artist: track.artist || "Неизвестный исполнитель",
      duration: track.duration || "0:00",
      trackUrl: track.url,
      coverUrl: track.coverUrl || null
    };

    playlistQueue.push(formatted);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to add track' });
  }
});

// Отдает текущий трек
app.get('/playlist/current', (req, res) => {
  res.json(currentTrack || null);
});

// Возвращает очередь (без текущего трека)
app.get('/playlist/queue', (req, res) => {
  res.json(playlistQueue);
});

// Получает прогресс и решает, переключаться или нет
app.post('/progress', (req, res) => {
  const { currentTime } = req.body;
  if (!currentTrack || !currentTime) return res.sendStatus(200);

  // Если трек близок к концу — переключаем
  const [min, sec] = (currentTrack.duration || "0:00").split(":").map(Number);
  const durationSec = (min * 60) + sec;

  if (durationSec > 0 && currentTime >= durationSec - 1) {
    playNextTrack();
  }

  res.sendStatus(200);
});

// Логика переключения на следующий трек
function playNextTrack() {
  if (playlistQueue.length > 0) {
    currentTrack = playlistQueue.shift();
  } else {
    // берём случайный трек из базы
    if (defaultTracks.length > 0) {
      const random = defaultTracks[Math.floor(Math.random() * defaultTracks.length)];
      currentTrack = random;
    } else {
      currentTrack = null;
    }
  }

  if (currentTrack) {
    fs.writeFileSync(CURRENT_TRACK_FILE, JSON.stringify(currentTrack, null, 2));
    console.log(`[NEXT] Now playing: ${currentTrack.title}`);
  }
}

// Старт сервера и инициализация базы
async function startServer() {
  try {
    await client.connect();
    console.log("MongoDB connected");
    const db = client.db(dbName);
    tracksCollection = db.collection(collectionName);

    const fromDb = await tracksCollection.find({}).toArray();
    defaultTracks = fromDb.map(track => ({
      id: track._id.toString(),
      title: track.title || "Без названия",
      artist: track.artist || "Неизвестный исполнитель",
      duration: track.duration || "0:00",
      trackUrl: track.url,
      coverUrl: track.coverUrl || null
    }));

    if (!currentTrack) playNextTrack();

    app.listen(port, '0.0.0.0', () => {
      console.log(`Server running on http://localhost:${port}`);
    });
  } catch (error) {
    console.error("Mongo connection failed:", error);
    process.exit(1);
  }
}

startServer();
