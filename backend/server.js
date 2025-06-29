const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { MongoClient, ObjectId } = require('mongodb');

const app = express();
const port = process.env.PORT || 3000;

// --- НАСТРОЙКИ ПОДКЛЮЧЕНИЯ ---
const mongoUri = process.env.MONGO_URI || "mongodb+srv://jhifarskiy:83leva35@eatune.8vrsmid.mongodb.net/?retryWrites=true&w=majority&appName=Eatune";
const client = new MongoClient(mongoUri);
const dbName = 'eatune';
const collectionName = 'tracks';
let tracksCollection;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const QUEUE_FILE = path.join(__dirname, 'queue.json');

// --- Хелперы для работы с очередью ---
function readQueue() {
    if (!fs.existsSync(QUEUE_FILE)) {
        return [];
    }
    try {
        const data = fs.readFileSync(QUEUE_FILE, 'utf-8');
        if (data.trim() === '') return [];
        return JSON.parse(data);
    } catch (e) {
        console.error("Error reading or parsing queue.json:", e);
        return [];
    }
}

function writeQueue(queue) {
    fs.writeFileSync(QUEUE_FILE, JSON.stringify(queue, null, 2));
}


// --- Маршруты API ---

// Отдает список всех доступных треков из БД
app.get('/tracks', async (req, res) => {
    if (!tracksCollection) {
        return res.status(503).json({ error: "Database not connected" });
    }
    try {
        const tracksFromDb = await tracksCollection.find({}).toArray();
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
        console.error('Failed to fetch tracks:', error);
        res.status(500).json({ error: 'Failed to fetch tracks from database' });
    }
});

// Отдает текущий играющий трек (первый в очереди)
app.get('/track', (req, res) => {
    const queue = readQueue();
    const nowPlaying = queue.length > 0 ? queue[0] : null;
    res.json(nowPlaying);
});

// [НОВЫЙ] Маршрут для обновления прогресса текущего трека
app.post('/track/progress', (req, res) => {
    const { currentTime } = req.body;
    // Проверяем, что currentTime это число
    if (typeof currentTime !== 'number') {
        return res.status(400).json({ error: 'currentTime must be a number' });
    }

    let queue = readQueue();
    if (queue.length > 0) {
        // Обновляем время у первого трека в очереди
        queue[0].currentTime = currentTime;
        queue[0].lastUpdate = Date.now();
        writeQueue(queue);
        return res.status(200).json({ success: true });
    }

    // Если очередь пуста, ничего не делаем
    res.status(404).json({ error: 'Queue is empty, nothing to update' });
});

// Отдает всю очередь целиком
app.get('/queue', (req, res) => {
    const queue = readQueue();
    res.json(queue);
});

// Добавляет трек в конец очереди
app.post('/queue', async (req, res) => {
    const { id } = req.body;
    if (!id) return res.status(400).json({ error: 'Track ID is required' });

    try {
        const selectedTrack = await tracksCollection.findOne({ _id: new ObjectId(id) });
        if (!selectedTrack) return res.status(404).json({ error: 'Track not found' });
        
        const trackData = {
            id: selectedTrack._id.toString(),
            title: selectedTrack.title || "Без названия",
            artist: selectedTrack.artist || "Неизвестный исполнитель",
            duration: selectedTrack.duration || "0:00",
            trackUrl: selectedTrack.url,
            coverUrl: selectedTrack.coverUrl || null,
            currentTime: 0, // При добавлении трек всегда начинается с 0
            lastUpdate: Date.now()
        };

        const queue = readQueue();
        if (queue.find(t => t.id === trackData.id)) {
            return res.status(409).json({ error: "Track is already in the queue" });
        }

        queue.push(trackData);
        writeQueue(queue);

        console.log(`Track "${trackData.title}" added to queue. Queue size: ${queue.length}`);
        res.status(201).json({ success: true, queue });

    } catch (error) {
        console.error('Error adding to queue:', error);
        res.status(500).json({ error: 'Failed to add track to queue' });
    }
});

// Удаляет текущий трек и сдвигает очередь (для плеера)
app.post('/track/next', (req, res) => {
    let queue = readQueue();
    if (queue.length > 0) {
        const finishedTrack = queue.shift();
        writeQueue(queue);
        console.log(`Track "${finishedTrack.title}" finished. Next track is "${queue[0]?.title || 'none'}".`);
        res.status(200).json({ success: true, nextTrack: queue[0] || null });
    } else {
        res.status(200).json({ success: true, nextTrack: null });
    }
});


// --- Запуск сервера ---
async function startServer() {
    try {
        await client.connect();
        console.log("Successfully connected to MongoDB Atlas!");
        const db = client.db(dbName);
        tracksCollection = db.collection(collectionName);
        
        if (!fs.existsSync(QUEUE_FILE)) {
            writeQueue([]);
        }

        app.listen(port, '0.0.0.0', () => {
            console.log(`Server running on http://localhost:${port}`);
            console.log(`Player available at http://localhost:${port}/player.html`);
        });

    } catch (error) {
        console.error("Failed to connect to MongoDB", error);
        process.exit(1);
    }
}

startServer();
