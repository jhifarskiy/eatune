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
const client = new MongoClient(mongoUri, { tls: true }); // Добавил tls для стабильности
const dbName = 'eatune';
const COLLECTION_NAME = 'tracks';

const TRACK_COOLDOWN_MINUTES = 15;
const USER_COOLDOWN_MINUTES = 5;
const HISTORY_MAX_SIZE = 30;
const BACKGROUND_QUEUE_SIZE = 4;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let venueQueues = {};
let userCooldowns = {};
let backgroundPlaylist = [];

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

wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const venueId = url.searchParams.get('venueId');
    if (!venueId) return ws.close();
    console.log(`Player connected for venue: ${venueId}`);
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
                venue.listeners.forEach(client => {
                    if (client !== ws && client.readyState === client.OPEN) {
                        client.send(JSON.stringify({
                            type: 'current_track_progress',
                            currentTime: data.currentTime
                        }));
                    }
                });
            }
        } catch (e) {
            console.error('Failed to parse message or broadcast:', e);
        }
    });
    ws.on('close', () => {
        console.log(`Player disconnected for venue: ${venueId}`);
        if (venue) {
            venue.listeners.delete(ws);
        }
    });
    ws.on('error', console.error);
});

// ИЗМЕНЕНИЕ: Переписываем маршрут /tracks
app.get('/tracks', async (req, res) => {
    // mode: 'popular', 'all', 'year'
    // value: '2024' (для 'year')
    // limit: 50
    const { mode = 'all', value, limit = 0 } = req.query;

    try {
        let tracks = [...backgroundPlaylist]; // Работаем с кэшем в памяти

        // Фильтрация по году
        if (mode === 'year' && value) {
            const yearNum = parseInt(value, 10);
            tracks = tracks.filter(t => t.year === yearNum);
        }
        
        // Перемешивание для 'popular'
        if (mode === 'popular') {
            for (let i = tracks.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [tracks[i], tracks[j]] = [tracks[j], tracks[i]];
            }
        }
        
        // Ограничение количества треков
        const limitNum = parseInt(limit, 10);
        if (limitNum > 0 && tracks.length > limitNum) {
            tracks = tracks.slice(0, limitNum);
        }

        res.json(tracks);
    } catch (e) {
        console.error('Track fetch error:', e);
        res.status(500).json({ error: 'Failed to fetch tracks' });
    }
});

app.post('/queue', async (req, res) => {
    const { id: trackId, venueId, deviceId } = req.body;

    if (!trackId || !venueId || !deviceId) {
        return res.status(400).json({ error: 'Track ID, Venue ID, and Device ID are required' });
    }
    
    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { queue: [], history: [], listeners: new Set(), backgroundTrackIndex: 0, trackCooldowns: new Map() };
    }
    
    const venue = venueQueues[venueId];
    const now = Date.now();
    const venueUserCooldowns = userCooldowns[venueId] || {};
    const lastAddTimestamp = venueUserCooldowns[deviceId];

    if (lastAddTimestamp) {
        const cooldownEndTime = lastAddTimestamp + USER_COOLDOWN_MINUTES * 60 * 1000;
        if (now < cooldownEndTime) {
            const timeLeftMs = cooldownEndTime - now;
            return res.status(429).json({
                error: `Следующий трек можно будет заказать через ${Math.ceil(timeLeftMs / 60000)} мин.`,
                cooldownType: 'user',
                timeLeftSeconds: Math.ceil(timeLeftMs / 1000),
            });
        }
    }

    if (venue.trackCooldowns.has(trackId) && now < venue.trackCooldowns.get(trackId)) {
        const cooldownEndTime = venue.trackCooldowns.get(trackId);
        return res.status(429).json({ 
            error: `Этот трек недавно играл. Попробуйте снова через ${Math.ceil((cooldownEndTime - now) / 60000)} мин.`,
            cooldownType: 'track'
        });
    }

    if (venue.queue.some(track => track.id === trackId && !track.isBackgroundTrack)) {
        return res.status(409).json({ error: "Этот трек уже в очереди" });
    }

    const selectedTrack = backgroundPlaylist.find(t => t.id === trackId);
    if (!selectedTrack) {
        return res.status(404).json({ error: 'Track not found' });
    }

    const newTrack = { ...selectedTrack, isBackgroundTrack: false, requestedBy: deviceId };
    const currentlyPlaying = venue.queue.shift();
    venue.queue = venue.queue.filter(track => !track.isBackgroundTrack);
    venue.queue.push(newTrack);
    if (currentlyPlaying) {
        venue.queue.unshift(currentlyPlaying);
    }
    
    if (!userCooldowns[venueId]) {
        userCooldowns[venueId] = {};
    }
    userCooldowns[venueId][deviceId] = now;

    broadcastQueueUpdate(venueId);
    res.status(201).json({ success: true, message: 'Трек добавлен в очередь!' });
});

app.post('/track/next', (req, res) => {
    const { venueId } = req.body;
    if (!venueId || !venueQueues[venueId]) {
        return res.status(400).json({ error: 'venueId is required or invalid' });
    }
    const venue = venueQueues[venueId];
    if (venue.queue.length > 0) {
        const finishedTrack = venue.queue.shift();
        venue.trackCooldowns.set(finishedTrack.id, Date.now() + TRACK_COOLDOWN_MINUTES * 60 * 1000);
        venue.history.unshift(finishedTrack);
        if (venue.history.length > HISTORY_MAX_SIZE) {
            venue.history.pop();
        }
    }
    ensureSufficientBackgroundTracks(venueId);
    broadcastQueueUpdate(venueId);
    res.status(200).json({ success: true, nextTrack: venue.queue[0] || null });
});

app.post('/track/previous', (req, res) => {
    const { venueId } = req.body;
    if (!venueId || !venueQueues[venueId]) {
        return res.status(400).json({ error: 'venueId is required or invalid' });
    }
    const venue = venueQueues[venueId];
    if (venue.history.length === 0) {
        return res.status(404).json({ error: 'No previous track in history.' });
    }
    const trackToReplay = venue.history.shift();
    venue.queue.unshift(trackToReplay);
    broadcastQueueUpdate(venueId);
    res.status(200).json({ success: true, currentTrack: venue.queue[0] || null });
});

function cleanupUserCooldowns() {
    const now = Date.now();
    const cooldownPeriod = USER_COOLDOWN_MINUTES * 60 * 1000;
    for (const venueId in userCooldowns) {
        for (const deviceId in userCooldowns[venueId]) {
            if (now - userCooldowns[venueId][deviceId] > cooldownPeriod) {
                delete userCooldowns[venueId][deviceId];
            }
        }
        if (Object.keys(userCooldowns[venueId]).length === 0) {
            delete userCooldowns[venueId];
        }
    }
}
setInterval(cleanupUserCooldowns, 5 * 60 * 1000);

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

startServer();