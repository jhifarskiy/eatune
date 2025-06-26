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

// Очередь треков (массив id треков в порядке воспроизведения)
let playlistQueue = [];

// Индекс текущего трека в очереди
let currentIndex = -1;

// Получение базовых треков из базы (кэш)
let baseTracks = [];

// Загружает базовые треки из MongoDB для использования, если очередь пуста
async function loadBaseTracks() {
  if (!tracksCollection) return;
  baseTracks = await tracksCollection.find({}).toArray();
  if (baseTracks.length === 0) {
    console.warn('[WARN] Нет базовых треков в базе');
  }
}
loadBaseTracks();

// Функция получения текущего трека (из очереди или базовых)
function getCurrentTrack() {
  if (playlistQueue.length > 0 && currentIndex >= 0 && currentIndex < playlistQueue.length) {
    return playlistQueue[currentIndex];
  }
  // Если очередь пустая или вышли за пределы - берем трек из базовых по кругу (цикл)
  if (baseTracks.length === 0) return null;
  // Выбираем базовый трек по модулю индекса (если currentIndex == -1, ставим 0)
  let baseIndex = currentIndex >= 0 ? currentIndex : 0;
  baseIndex = baseIndex % baseTracks.length;
  return baseTracks[baseIndex];
}

// Эндпоинт: вернуть текущий трек
app.get('/playlist/current', (req, res) => {
  const track = getCurrentTrack();
  if (!track) return res.json(null);

  // Форматируем трек для отдачи клиенту
  const formattedTrack = {
    id: track._id.toString(),
    title: track.title || "Без названия",
    artist: track.artist || "Неизвестный исполнитель",
    duration: track.duration || "0:00",
    trackUrl: track.url,
    coverUrl: track.coverUrl || null
  };
  res.json(formattedTrack);
});

// Эндпоинт: получить все базовые треки (как было)
app.get('/tracks', async (req, res) => {
  if (!tracksCollection) return res.status(503).json({ error: "Database not connected" });
  try {
    const tracksFromDb = await tracksCollection.find({}).toArray();
    baseTracks = tracksFromDb; // обновляем кэш базовых треков
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

// Эндпоинт: добавить трек в очередь
app.post('/playlist/add', async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ error: 'Track ID is required' });
  if (!tracksCollection) return res.status(503).json({ error: 'Database not connected' });

  try {
    const track = await tracksCollection.findOne({ _id: new ObjectId(id) });
    if (!track) return res.status(404).json({ error: 'Track not found' });

    // Добавляем в очередь
    playlistQueue.push(track);
    // Если сейчас нет трека (т.е. currentIndex == -1), начинаем с первого добавленного
    if (currentIndex === -1) currentIndex = 0;

    console.log(`[OK] Track added to queue: ${track.title}`);

    res.json({ success: true, queueLength: playlistQueue.length });
  } catch (error) {
    console.error('[ERROR] Failed to add track to queue:', error);
    res.status(500).json({ error: 'Failed to add track to queue' });
  }
});

// Эндпоинт: перейти к следующему треку (например, вызывается клиентом по окончании текущего)
app.post('/playlist/next', (req, res) => {
  if (playlistQueue.length === 0) {
    // Если очередь пустая, просто крутим базовые треки по кругу
    currentIndex = (currentIndex + 1) % (baseTracks.length || 1);
  } else {
    currentIndex++;
    if (currentIndex >= playlistQueue.length) {
      // Очередь закончилась — сбрасываем очередь и начинаем базовые треки заново
      playlistQueue = [];
      currentIndex = 0;
    }
  }
  const track = getCurrentTrack();
  if (!track) return res.json(null);

  const formattedTrack = {
    id: track._id.toString(),
    title: track.title || "Без названия",
    artist: track.artist || "Неизвестный исполнитель",
    duration: track.duration || "0:00",
    trackUrl: track.url,
    coverUrl: track.coverUrl || null
  };

  console.log(`[OK] Moved to next track: ${formattedTrack.title}`);
  res.json(formattedTrack);
});

// Эндпоинт: получить длину очереди
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
      console.log(`Player is available at http://localhost:${port}/player.html or your public URL.`);
    });
  } catch (error) {
    console.error("Fatal: Could not connect to MongoDB.", error);
    process.exit(1);
  }
}

startServer();
