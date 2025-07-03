const express = require('express');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { WebSocketServer } = require('ws');
const { MongoClient } = require('mongodb');

// --- НАСТРОЙКИ ---
const app = express();
const port = process.env.PORT || 3000;
const mongoUri = process.env.MONGO_URI || "mongodb+srv://jhifarskiy:83leva35@eatune.8vrsmid.mongodb.net/?retryWrites=true&w=majority&appName=Eatune";
const client = new MongoClient(mongoUri);
const dbName = 'eatune';

const TRACK_COOLDOWN_MINUTES = 15;
const HISTORY_MAX_SIZE = 30; // Ограничиваем размер истории

// --- Мидлвары и сервер ---
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// --- УПРАВЛЕНИЕ ОЧЕРЕДЯМИ ---
let venueQueues = {}; // { venueId: { queue: [], history: [], listeners: Set, ... } }
let backgroundPlaylist = [];

/**
 * Оповещает всех клиентов заведения об обновлении очереди
 * @param {string} venueId
 */
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

/**
 * Добавляет фоновый трек, если очередь пуста.
 * @param {string} venueId
 */
function addBackgroundTrackIfNeeded(venueId) {
    const venue = venueQueues[venueId];
    if (!venue || venue.queue.length > 0 || backgroundPlaylist.length === 0) {
        return;
    }

    let nextIndex = venue.backgroundTrackIndex || 0;
    const nextTrack = backgroundPlaylist[nextIndex];
    
    venue.backgroundTrackIndex = (nextIndex + 1) % backgroundPlaylist.length;
    venue.queue.push({ ...nextTrack, isBackgroundTrack: true });
    
    console.log(`Venue ${venueId}: Queue was empty. Added background track: ${nextTrack.title}`);
}

// --- УПРАВЛЕНИЕ WEBSOCKETS ---
wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const venueId = url.searchParams.get('venueId');

    if (!venueId) return ws.close();
    console.log(`Player connected for venue: ${venueId}`);

    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { 
            queue: [], 
            history: [], // НОВОЕ: Инициализация истории
            listeners: new Set(), 
            backgroundTrackIndex: 0, 
            trackCooldowns: new Map() 
        };
    }
    
    venueQueues[venueId].listeners.add(ws);
    
    addBackgroundTrackIfNeeded(venueId);
    broadcastQueueUpdate(venueId);

    ws.on('close', () => {
        console.log(`Player disconnected for venue: ${venueId}`);
        if (venueQueues[venueId]) {
            venueQueues[venueId].listeners.delete(ws);
        }
    });

    ws.on('error', console.error);
});

// --- API МАРШРУТЫ ---

app.get('/tracks', (req, res) => {
    res.json(backgroundPlaylist);
});

app.post('/queue', async (req, res) => {
    const { id: trackId, venueId } = req.body;
    if (!trackId || !venueId) {
        return res.status(400).json({ error: 'Track ID and Venue ID are required' });
    }

    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { queue: [], history: [], listeners: new Set(), backgroundTrackIndex: 0, trackCooldowns: new Map() };
    }
    const venue = venueQueues[venueId];
    const now = Date.now();

    if (venue.trackCooldowns.has(trackId) && now < venue.trackCooldowns.get(trackId)) {
        const timeLeft = Math.ceil((venue.trackCooldowns.get(trackId) - now) / 60000);
        return res.status(429).json({ error: `Этот трек недавно играл. Попробуйте снова через ${timeLeft} мин.` });
    }

    const selectedTrack = backgroundPlaylist.find(t => t.id === trackId);
    if (!selectedTrack) {
        return res.status(404).json({ error: 'Track not found' });
    }
    
    const newTrack = { ...selectedTrack, isBackgroundTrack: false };

    let newQueue = venue.queue.filter((track, index) => index === 0 || !track.isBackgroundTrack);
    
    if (newQueue.some(t => t.id === newTrack.id && !t.isBackgroundTrack)) {
        return res.status(409).json({ error: "Этот трек уже в очереди" });
    }

    newQueue.push(newTrack);
    venue.queue = newQueue;
    venue.trackCooldowns.set(trackId, now + TRACK_COOLDOWN_MINUTES * 60 * 1000);
    
    broadcastQueueUpdate(venueId);
    console.log(`Track "${newTrack.title}" added for venue ${venueId}. Queue updated.`);
    res.status(201).json({ success: true, message: 'Трек добавлен в очередь!', queue: venue.queue });
});

// ИЗМЕНЕНИЕ: Теперь '/track/next' добавляет трек в историю
app.post('/track/next', (req, res) => {
    const { venueId } = req.body;
    if (!venueId || !venueQueues[venueId]) {
        return res.status(400).json({ error: 'venueId is required or invalid' });
    }
    const venue = venueQueues[venueId];

    if (venue.queue.length > 0) {
        const finishedTrack = venue.queue.shift();
        // Добавляем завершенный трек в начало истории
        venue.history.unshift(finishedTrack);
        // Ограничиваем размер истории
        if (venue.history.length > HISTORY_MAX_SIZE) {
            venue.history.pop();
        }
        console.log(`Track "${finishedTrack.title}" finished. Moved to history for venue ${venueId}.`);
    }
    
    addBackgroundTrackIfNeeded(venueId);
    broadcastQueueUpdate(venueId);
    
    res.status(200).json({ success: true, nextTrack: venue.queue[0] || null });
});

// НОВЫЙ МАРШРУТ: для кнопки "назад"
app.post('/track/previous', (req, res) => {
    const { venueId } = req.body;
    if (!venueId || !venueQueues[venueId]) {
        return res.status(400).json({ error: 'venueId is required or invalid' });
    }
    const venue = venueQueues[venueId];

    // Проверяем, есть ли что-то в истории
    if (venue.history.length === 0) {
        return res.status(404).json({ error: 'No previous track in history.' });
    }
    
    // Перемещаем текущий трек (если он есть) обратно в историю, чтобы избежать дублирования
    if (venue.queue.length > 0) {
        venue.history.unshift(venue.queue.shift());
    }

    // Берем последний проигранный трек из истории и ставим его в начало очереди
    const trackToReplay = venue.history.shift();
    venue.queue.unshift(trackToReplay);

    broadcastQueueUpdate(venueId);
    console.log(`Rewinding to previous track "${trackToReplay.title}" for venue ${venueId}.`);
    res.status(200).json({ success: true, currentTrack: venue.queue[0] || null });
});


// --- ЗАПУСК СЕРВЕРА ---
async function startServer() {
    try {
        await client.connect();
        console.log("Successfully connected to MongoDB Atlas!");
        const db = client.db(dbName);
        const tracksCollection = db.collection('tracks');
        
        const tracksFromDb = await tracksCollection.find({}).toArray();
        backgroundPlaylist = tracksFromDb.map(track => ({
            id: track._id.toString(),
            title: track.title || "Без названия",
            artist: track.artist || "Неизвестный исполнитель",
            duration: track.duration || "0:00",
            trackUrl: track.url,
            coverUrl: track.coverUrl || null
        }));
        console.log(`Loaded ${backgroundPlaylist.length} tracks into memory.`);
        
        server.listen(port, '0.0.0.0', () => {
            console.log(`Server running on port: ${port}`);
        });

    } catch (error) {
        console.error("Failed to start server:", error);
        process.exit(1);
    }
}

startServer();