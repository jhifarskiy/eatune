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
const HISTORY_MAX_SIZE = 30;
const MIN_BACKGROUND_TRACKS = 3; // Сколько фоновых треков всегда должно быть в очереди

// --- Мидлвары и сервер ---
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let venueQueues = {};
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

// ИЗМЕНЕНИЕ: Функция теперь поддерживает минимальное кол-во фоновых треков
function ensureSufficientBackgroundTracks(venueId) {
    const venue = venueQueues[venueId];
    if (!venue || backgroundPlaylist.length === 0) return;

    // Считаем только треки, которые еще не играют и являются фоновыми
    const upcomingBgTracks = venue.queue.filter((t, index) => index > 0 && t.isBackgroundTrack).length;
    
    // Если в очереди уже есть пользовательские треки, не добавляем фоновые
    const hasUserTracks = venue.queue.some(t => !t.isBackgroundTrack);
    if (hasUserTracks) return;

    let tracksToAdd = MIN_BACKGROUND_TRACKS - upcomingBgTracks;
    
    // Если играет фоновый трек и больше ничего нет, добавляем еще
    if (venue.queue.length === 1 && venue.queue[0].isBackgroundTrack) {
        tracksToAdd = MIN_BACKGROUND_TRACKS;
    }
    
    // Если очередь пуста, добавляем треки
    if (venue.queue.length === 0) {
        tracksToAdd = MIN_BACKGROUND_TRACKS + 1; // +1 для текущего
    }


    let currentTrackIndex = venue.backgroundTrackIndex || 0;
    while (tracksToAdd > 0) {
        const nextTrack = backgroundPlaylist[currentTrackIndex];
        
        if (!venue.queue.some(t => t.id === nextTrack.id)) {
            venue.queue.push({ ...nextTrack, isBackgroundTrack: true });
             tracksToAdd--;
        }
        
        currentTrackIndex = (currentTrackIndex + 1) % backgroundPlaylist.length;
    }
    venue.backgroundTrackIndex = currentTrackIndex;
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
            history: [],
            listeners: new Set(),
            backgroundTrackIndex: 0,
            trackCooldowns: new Map()
        };
    }
    
    const venue = venueQueues[venueId];
    venue.listeners.add(ws);
    
    ensureSufficientBackgroundTracks(venueId); // Используем новую функцию
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
    // При добавлении трека пользователем, удаляем все фоновые из очереди
    venue.queue = venue.queue.filter(track => !track.isBackgroundTrack);

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
    if (venue.queue.some(t => t.id === newTrack.id && !t.isBackgroundTrack)) {
        return res.status(409).json({ error: "Этот трек уже в очереди" });
    }
    venue.queue.push(newTrack);
    venue.trackCooldowns.set(trackId, now + TRACK_COOLDOWN_MINUTES * 60 * 1000);
    broadcastQueueUpdate(venueId);
    console.log(`Track "${newTrack.title}" added for venue ${venueId}. Queue updated.`);
    res.status(201).json({ success: true, message: 'Трек добавлен в очередь!', queue: venue.queue });
});
app.post('/track/next', (req, res) => {
    const { venueId } = req.body;
    if (!venueId || !venueQueues[venueId]) {
        return res.status(400).json({ error: 'venueId is required or invalid' });
    }
    const venue = venueQueues[venueId];
    if (venue.queue.length > 0) {
        const finishedTrack = venue.queue.shift();
        venue.history.unshift(finishedTrack);
        if (venue.history.length > HISTORY_MAX_SIZE) {
            venue.history.pop();
        }
        console.log(`Track "${finishedTrack.title}" finished. Moved to history for venue ${venueId}.`);
    }
    ensureSufficientBackgroundTracks(venueId); // Используем новую функцию
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