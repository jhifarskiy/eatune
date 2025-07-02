const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const http = require('http');
const { WebSocketServer } = require('ws');
const { MongoClient, ObjectId } = require('mongodb');

const app = express();
const port = process.env.PORT || 3000;

// --- НАСТРОЙКИ ---
const mongoUri = process.env.MONGO_URI || "mongodb+srv://jhifarskiy:83leva35@eatune.8vrsmid.mongodb.net/?retryWrites=true&w=majority&appName=Eatune";
const client = new MongoClient(mongoUri);
const dbName = 'eatune';
const collectionName = 'tracks';
let tracksCollection;

const USER_TRACK_COOLDOWN = 5 * 60 * 1000; // 5 минут в миллисекундах

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// --- НОВАЯ СИСТЕМА ОЧЕРЕДЕЙ ---
let venueQueues = {}; // { venueId: { queue: [], listeners: Set, backgroundTrackIndex: 0, lastUserAddTimestamp: 0 } }
let backgroundPlaylist = []; // Глобальный плейлист из всех треков в БД

// Функция для добавления трека из фонового плейлиста, если очередь пуста
function ensureQueueHasTrack(venueId) {
    if (!venueQueues[venueId] || venueQueues[venueId].queue.length > 0) {
        return; 
    }
    
    if (backgroundPlaylist.length === 0) {
        console.log(`Venue ${venueId}: Background playlist is empty, can't add a track.`);
        return;
    }

    let afrerackIndex = venueQueues[venueId].backgroundTrackIndex || 0;
    
    const nextTrack = backgroundPlaylist[afrerackIndex];
    afrerackIndex = (afrerackIndex + 1) % backgroundPlaylist.length;
    venueQueues[venueId].backgroundTrackIndex = afrerackIndex;
    
    venueQueues[venueId].queue.push({ ...nextTrack, isBackgroundTrack: true });
    
    console.log(`Venue ${venueId}: Queue was empty. Added background track: ${nextTrack.title}`);
}


// --- УПРАВЛЕНИЕ WEBSOCKETS ---
wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const venueId = url.searchParams.get('venueId');

    if (!venueId) {
        ws.close();
        return;
    }

    console.log(`Player connected for venue: ${venueId}`);

    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { queue: [], listeners: new Set(), backgroundTrackIndex: 0, lastUserAddTimestamp: 0 };
    }
    
    venueQueues[venueId].listeners.add(ws);
    
    ensureQueueHasTrack(venueId);
    broadcastQueueUpdate(venueId);

    ws.on('close', () => {
        console.log(`Player disconnected for venue: ${venueId}`);
        if (venueQueues[venueId]) {
            venueQueues[venueId].listeners.delete(ws);
        }
    });

    ws.on('error', console.error);
});

// Функция для оповещения всех плееров конкретного заведения
function broadcastQueueUpdate(venueId) {
    if (venueQueues[venueId]) {
        const message = JSON.stringify({ type: 'queue_update', queue: venueQueues[venueId].queue });
        venueQueues[venueId].listeners.forEach(client => {
            if (client.readyState === client.OPEN) {
                client.send(message);
            }
        });
    }
}


// --- Маршруты API (ОБНОВЛЕННЫЕ) ---

app.get('/tracks', (req, res) => {
    res.json(backgroundPlaylist);
});

app.post('/queue', async (req, res) => {
    const { id: trackId, venueId } = req.body;
    if (!trackId || !venueId) {
        return res.status(400).json({ error: 'Track ID and Venue ID are required' });
    }

    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { queue: [], listeners: new Set(), backgroundTrackIndex: 0, lastUserAddTimestamp: 0 };
    }

    const now = Date.now();
    const lastAdd = venueQueues[venueId].lastUserAddTimestamp || 0;
    const timeSinceLastAdd = now - lastAdd;

    if (timeSinceLastAdd < USER_TRACK_COOLDOWN) {
        const timeLeft = Math.ceil((USER_TRACK_COOLDOWN - timeSinceLastAdd) / 60000);
        return res.status(429).json({ error: `Вы сможете добавить трек через ${timeLeft} мин.` });
    }

    const selectedTrack = backgroundPlaylist.find(t => t.id === trackId);
    if (!selectedTrack) {
        return res.status(404).json({ error: 'Track not found' });
    }
        
    const trackData = { ...selectedTrack, isBackgroundTrack: false, currentTime: 0, lastUpdate: now };
    const currentQueue = venueQueues[venueId].queue;

    if (currentQueue.find(t => t.id === trackData.id)) {
        return res.status(409).json({ error: "Этот трек уже в очереди" });
    }
    
    // ИЗМЕНЕНИЕ: Убрана сложная логика. Любой новый трек всегда добавляется в конец.
    currentQueue.push(trackData);

    venueQueues[venueId].lastUserAddTimestamp = now;
    broadcastQueueUpdate(venueId);

    console.log(`Track "${trackData.title}" added to queue for venue ${venueId}.`);
    res.status(201).json({ success: true, queue: currentQueue });
});


app.post('/track/next', (req, res) => {
    const { venueId } = req.body;
    if (!venueId) return res.status(400).json({ error: 'venueId is required' });

    const venue = venueQueues[venueId];
    if (venue && venue.queue.length > 0) {
        const finishedTrack = venue.queue.shift();
        console.log(`Track "${finishedTrack.title}" finished for venue ${venueId}.`);
        
        ensureQueueHasTrack(venueId);
        broadcastQueueUpdate(venueId);
        
        res.status(200).json({ success: true, nextTrack: venue.queue[0] || null });
    } else {
        // Если по какой-то причине очередь оказалась пуста, все равно проверяем
        if (venue) {
             ensureQueueHasTrack(venueId);
             broadcastQueueUpdate(venueId);
        }
        res.status(200).json({ success: true, nextTrack: venue?.queue[0] || null });
    }
});


// --- Запуск сервера ---
async function startServer() {
    try {
        await client.connect();
        console.log("Successfully connected to MongoDB Atlas!");
        const db = client.db(dbName);
        tracksCollection = db.collection(collectionName);
        
        const tracksFromDb = await tracksCollection.find({}).toArray();
        backgroundPlaylist = tracksFromDb.map(track => ({
            id: track._id.toString(),
            title: track.title || "Без названия",
            artist: track.artist || "Неизвестный исполнитель",
            duration: track.duration || "0:00",
            trackUrl: track.url,
            coverUrl: track.coverUrl || null
        }));
        console.log(`Loaded ${backgroundPlaylist.length} tracks into memory for background playlist.`);
        
        server.listen(port, '0.0.0.0', () => {
            console.log(`Server running on http://localhost:${port}`);
            console.log(`Player available at http://localhost:${port}/player.html`);
        });

    } catch (error) {
        console.error("Failed to start server:", error);
        process.exit(1);
    }
}

startServer();