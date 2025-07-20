// backend/server.js

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
const client = new MongoClient(mongoUri, { tls: true });
const dbName = 'eatune';
const COLLECTION_NAME = 'tracks';

const TRACK_COOLDOWN_MINUTES = 15;
const USER_COOLDOWN_MINUTES = 5;
const HISTORY_MAX_SIZE = 30;
const BACKGROUND_QUEUE_SIZE = 4;

// --- MIDDLEWARE ---
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// --- ХРАНИЛИЩА В ПАМЯТИ ---
let venueQueues = {};
let userCooldowns = {};
let backgroundPlaylist = [];

// --- WEBSOCKETS ---

function broadcastToVenue(venueId, message) {
    if (venueQueues[venueId]) {
        const messageString = JSON.stringify(message);
        venueQueues[venueId].listeners.forEach(client => {
            if (client.readyState === client.OPEN) {
                client.send(messageString);
            }
        });
    }
}

function broadcastQueueUpdate(venueId) {
    if (venueQueues[venueId]) {
        broadcastToVenue(venueId, { type: 'queue_update', queue: venueQueues[venueId].queue });
    }
}

wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const venueId = url.searchParams.get('venueId');
    if (!venueId) return ws.close();

    console.log(`Client connected for venue: ${venueId}`);

    if (!venueQueues[venueId]) {
        venueQueues[venueId] = {
            queue: [],
            history: [],
            listeners: new Set(),
            backgroundTrackIndex: 0,
            trackCooldowns: new Map()
        };
    }

    const venue = venueQueues[venueId];
    venue.listeners.add(ws);

    ensureSufficientBackgroundTracks(venueId);
    broadcastQueueUpdate(venueId);

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            if (data.type === 'progress_update' && data.venueId === venueId) {
                broadcastToVenue(venueId, {
                    type: 'current_track_progress',
                    currentTime: data.currentTime
                });
            }
        } catch (e) {
            console.error('Failed to parse message:', e);
        }
    });

    ws.on('close', () => {
        console.log(`Client disconnected for venue: ${venueId}`);
        if (venue) {
            venue.listeners.delete(ws);
        }
    });
    ws.on('error', console.error);
});


// --- ЛОГИКА ОЧЕРЕДИ ---

function ensureSufficientBackgroundTracks(venueId) {
    const venue = venueQueues[venueId];
    if (!venue || backgroundPlaylist.length === 0) return;

    const hasUserTracks = venue.queue.some(t => !t.isBackgroundTrack);
    if (hasUserTracks) return;

    let tracksToAdd = BACKGROUND_QUEUE_SIZE - venue.queue.length;
    if (tracksToAdd <= 0) return;

    let currentTrackIndex = venue.backgroundTrackIndex || 0;
    let safeguard = backgroundPlaylist.length;

    while (tracksToAdd > 0 && safeguard > 0) {
        const nextTrack = backgroundPlaylist[currentTrackIndex];
        const isAlreadyInQueue = venue.queue.some(t => t.id === nextTrack.id);
        const isOnCooldown = venue.trackCooldowns.has(nextTrack.id) && Date.now() < venue.trackCooldowns.get(nextTrack.id);
        
        if (!isAlreadyInQueue && !isOnCooldown) {
            venue.queue.push({ ...nextTrack, isBackgroundTrack: true });
            tracksToAdd--;
        }
        currentTrackIndex = (currentTrackIndex + 1) % backgroundPlaylist.length;
        safeguard--;
    }
    venue.backgroundTrackIndex = currentTrackIndex;
}


// --- API РОУТЕР ---
const apiRouter = express.Router();

// GET /api/tracks - Получить треки (кэш)
apiRouter.get('/tracks', async (req, res) => {
    res.json(backgroundPlaylist);
});

// GET /api/history/:venueId - Получить историю
apiRouter.get('/history/:venueId', (req, res) => {
    const { venueId } = req.params;
    const venue = venueQueues[venueId];
    if (!venue) {
        return res.status(404).json({ error: 'Venue not found' });
    }
    res.json(venue.history || []);
});


// POST /api/queue/add - Добавить трек в очередь (для пользователей)
apiRouter.post('/queue/add', async (req, res) => {
    const { id: trackId, venueId, deviceId } = req.body;
    if (!trackId || !venueId || !deviceId) return res.status(400).json({ error: 'Track ID, Venue ID, and Device ID are required' });
    
    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { queue: [], history: [], listeners: new Set(), backgroundTrackIndex: 0, trackCooldowns: new Map() };
    }
    
    const venue = venueQueues[venueId];
    const now = Date.now();
    const venueUserCooldowns = userCooldowns[venueId] || {};
    const lastAddTimestamp = venueUserCooldowns[deviceId];

    // Проверка кулдауна пользователя
    if (lastAddTimestamp) {
        const cooldownEndTime = lastAddTimestamp + USER_COOLDOWN_MINUTES * 60 * 1000;
        if (now < cooldownEndTime) {
            const timeLeftMs = cooldownEndTime - now;
            return res.status(429).json({
                error: `Пользовательский кулдаун.`,
                cooldownType: 'user',
                timeLeftSeconds: Math.ceil(timeLeftMs / 1000),
            });
        }
    }

    // Проверка кулдауна трека
    if (venue.trackCooldowns.has(trackId) && now < venue.trackCooldowns.get(trackId)) {
        return res.status(429).json({ error: `Этот трек недавно играл.`, cooldownType: 'track' });
    }

    // Проверка на дубликат в очереди
    if (venue.queue.some(track => track.id === trackId && !track.isBackgroundTrack)) {
        return res.status(409).json({ error: "Этот трек уже в очереди" });
    }

    const selectedTrack = backgroundPlaylist.find(t => t.id === trackId);
    if (!selectedTrack) return res.status(404).json({ error: 'Track not found' });

    // --- ОСНОВНАЯ ЛОГИКА ДОБАВЛЕНИЯ С ПРИОРИТЕТОМ ---
    const newTrack = { ...selectedTrack, isBackgroundTrack: false, requestedBy: deviceId };
    const currentlyPlaying = venue.queue.shift();
    venue.queue = venue.queue.filter(track => !track.isBackgroundTrack); // Удаляем фоновые
    venue.queue.push(newTrack); // Добавляем заказ
    if (currentlyPlaying) {
        venue.queue.unshift(currentlyPlaying); // Возвращаем текущий трек
    }
    
    if (!userCooldowns[venueId]) userCooldowns[venueId] = {};
    userCooldowns[venueId][deviceId] = now;

    broadcastQueueUpdate(venueId);
    res.status(201).json({ success: true, message: 'Трек добавлен в очередь!' });
});

// POST /api/queue/add-next - Добавить трек следующим (для админа)
apiRouter.post('/queue/add-next', (req, res) => {
    const { trackId, venueId } = req.body;
    const venue = venueQueues[venueId];
    if (!venue) return res.status(404).json({ error: 'Venue not found' });

    const trackToAdd = backgroundPlaylist.find(t => t.id === trackId);
    if (!trackToAdd) return res.status(404).json({ error: 'Track not found' });
    
    // Вставляем трек на вторую позицию (после играющего)
    venue.queue.splice(1, 0, { ...trackToAdd, isBackgroundTrack: false, requestedBy: 'admin' });

    broadcastQueueUpdate(venueId);
    res.status(200).json({ success: true });
});

// POST /api/queue/remove - Удалить трек из очереди (для админа)
apiRouter.post('/queue/remove', (req, res) => {
    const { trackId, venueId } = req.body;
    const venue = venueQueues[venueId];
    if (!venue) return res.status(404).json({ error: 'Venue not found' });

    const trackIndex = venue.queue.findIndex(t => t.id === trackId);
    // Не позволяем удалить текущий играющий трек
    if (trackIndex > 0) {
        venue.queue.splice(trackIndex, 1);
        broadcastQueueUpdate(venueId);
        res.status(200).json({ success: true });
    } else {
        res.status(400).json({ error: 'Cannot remove the currently playing track or track not found.' });
    }
});


// POST /api/player/next - Следующий трек
apiRouter.post('/player/next', (req, res) => {
    const { venueId } = req.body;
    const venue = venueQueues[venueId];
    if (!venue) return res.status(404).json({ error: 'Venue not found' });

    if (venue.queue.length > 0) {
        const finishedTrack = venue.queue.shift();
        venue.trackCooldowns.set(finishedTrack.id, Date.now() + TRACK_COOLDOWN_MINUTES * 60 * 1000);
        venue.history.unshift(finishedTrack);
        if (venue.history.length > HISTORY_MAX_SIZE) venue.history.pop();
    }
    
    ensureSufficientBackgroundTracks(venueId);
    broadcastQueueUpdate(venueId);
    res.status(200).json({ success: true });
});

// POST /api/player/previous - Предыдущий трек
apiRouter.post('/player/previous', (req, res) => {
    const { venueId } = req.body;
    const venue = venueQueues[venueId];
    if (!venue) return res.status(404).json({ error: 'Venue not found' });

    if (venue.history.length === 0) return res.status(404).json({ error: 'No previous track in history.' });
    
    const trackToReplay = venue.history.shift();
    venue.queue.unshift(trackToReplay);
    
    broadcastQueueUpdate(venueId);
    res.status(200).json({ success: true });
});

// POST /api/player/play & /pause - Управление плеером
apiRouter.post('/player/:action', (req, res) => {
    const { action } = req.params;
    const { venueId } = req.body;
    if (action !== 'play' && action !== 'pause') {
        return res.status(400).json({ error: 'Invalid action.' });
    }
    broadcastToVenue(venueId, { type: 'player_control', action });
    res.status(200).json({ success: true, action });
});


app.use('/api', apiRouter);


// --- ЗАПУСК СЕРВЕРА ---

async function startServer() {
    try {
        await client.connect();
        console.log("Successfully connected to MongoDB Atlas!");
        const db = client.db(dbName);
        const tracksCollection = db.collection(COLLECTION_NAME);
        const tracksFromDb = await tracksCollection.find({}).toArray();
        
        backgroundPlaylist = tracksFromDb.map(track => ({
            id: track._id.toString(),
            title: track.title || "Без названия",
            artist: track.artist || "Неизвестный исполнитель",
            duration: track.duration || "0:00",
            genre: track.genre || "Pop",
            year: track.year || null,
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

setInterval(() => {
    const now = Date.now();
    const userCooldownPeriod = USER_COOLDOWN_MINUTES * 60 * 1000;
    for (const venueId in userCooldowns) {
        for (const deviceId in userCooldowns[venueId]) {
            if (now - userCooldowns[venueId][deviceId] > userCooldownPeriod) {
                delete userCooldowns[venueId][deviceId];
            }
        }
    }
}, 5 * 60 * 1000);

startServer();