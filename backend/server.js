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
const USER_COOLDOWN_MINUTES = 5; // Новый кулдаун для пользователя
const HISTORY_MAX_SIZE = 30;
const BACKGROUND_QUEUE_SIZE = 4;

// --- Мидлвары и сервер ---
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.set('trust proxy', 1); // Важно для корректного определения IP за прокси (напр. на Render)


const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let venueQueues = {};
let userCooldowns = {}; // { venueId: { ip: timestamp } }
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
    const userIp = req.ip;
    const now = Date.now();

    // ПРОВЕРКА 0: Пользователь на кулдауне?
    if (userCooldowns[venueId] && userCooldowns[venueId][userIp]) {
        const lastAddTimestamp = userCooldowns[venueId][userIp];
        const cooldownEndTime = lastAddTimestamp + USER_COOLDOWN_MINUTES * 60 * 1000;
        if (now < cooldownEndTime) {
            const timeLeftMs = cooldownEndTime - now;
            const timeLeftSec = Math.ceil(timeLeftMs / 1000);
            const timeLeftMin = Math.ceil(timeLeftMs / 60000);
            return res.status(429).json({
                error: `Следующий трек можно будет заказать через ${timeLeftMin} мин.`,
                cooldownType: 'user', // Тип кулдауна для фронтенда
                timeLeftSeconds: timeLeftSec,
            });
        }
    }

    // ПРОВЕРКА 1: Трек на кулдауне, потому что недавно играл?
    if (venue.trackCooldowns.has(trackId) && now < venue.trackCooldowns.get(trackId)) {
        const cooldownEndTime = venue.trackCooldowns.get(trackId);
        const timeLeftMs = cooldownEndTime - now;
        const timeLeftMin = Math.ceil(timeLeftMs / 60000);
        return res.status(429).json({ 
            error: `Этот трек недавно играл. Попробуйте снова через ${timeLeftMin} мин.`,
            cooldownType: 'track' // Тип кулдауна для фронтенда
        });
    }

    // ПРОВЕРКА 2: Трек уже заказан пользователем и ждет в очереди?
    if (venue.queue.some(track => track.id === trackId && !track.isBackgroundTrack)) {
        return res.status(409).json({ error: "Этот трек уже в очереди" });
    }

    const selectedTrack = backgroundPlaylist.find(t => t.id === trackId);
    if (!selectedTrack) {
        return res.status(404).json({ error: 'Track not found' });
    }
    const newTrack = { ...selectedTrack, isBackgroundTrack: false, requestedBy: userIp };


    // ПЕРЕСТРАИВАЕМ ОЧЕРЕДЬ
    const currentlyPlaying = venue.queue.length > 0 ? venue.queue[0] : null;
    const existingUserTracks = venue.queue.filter((track, index) => index > 0 && !track.isBackgroundTrack);

    let newQueue = [];
    if (currentlyPlaying) {
        newQueue.push(currentlyPlaying);
    }
    newQueue.push(...existingUserTracks);
    newQueue.push(newTrack);

    venue.queue = newQueue;
    
    // Устанавливаем кулдаун для пользователя
    if (!userCooldowns[venueId]) {
        userCooldowns[venueId] = {};
    }
    userCooldowns[venueId][userIp] = now;


    broadcastQueueUpdate(venueId);
    console.log(`Track "${newTrack.title}" added for venue ${venueId} by IP ${userIp}. User cooldown started.`);
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

        // Устанавливаем кулдаун, только когда трек ЗАКОНЧИЛСЯ
        venue.trackCooldowns.set(finishedTrack.id, Date.now() + TRACK_COOLDOWN_MINUTES * 60 * 1000);

        venue.history.unshift(finishedTrack);
        if (venue.history.length > HISTORY_MAX_SIZE) {
            venue.history.pop();
        }
        console.log(`Track "${finishedTrack.title}" finished. Cooldown started. Moved to history.`);
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
    console.log(`Rewinding to previous track "${trackToReplay.title}" for venue ${venueId}.`);
    res.status(200).json({ success: true, currentTrack: venue.queue[0] || null });
});

// Функция для очистки старых записей о кулдаунах пользователей
function cleanupUserCooldowns() {
    const now = Date.now();
    const cooldownPeriod = USER_COOLDOWN_MINUTES * 60 * 1000;
    for (const venueId in userCooldowns) {
        for (const userIp in userCooldowns[venueId]) {
            if (now - userCooldowns[venueId][userIp] > cooldownPeriod) {
                delete userCooldowns[venueId][userIp];
            }
        }
        if (Object.keys(userCooldowns[venueId]).length === 0) {
            delete userCooldowns[venueId];
        }
    }
}

// Запускаем очистку каждые 5 минут
setInterval(cleanupUserCooldowns, 5 * 60 * 1000);


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
        
        for (let i = backgroundPlaylist.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [backgroundPlaylist[i], backgroundPlaylist[j]] = [backgroundPlaylist[j], backgroundPlaylist[i]];
        }
        console.log(`Loaded and shuffled ${backgroundPlaylist.length} tracks into memory.`);
        server.listen(port, '0.0.0.0', () => {
            console.log(`Server running on port: ${port}`);
        });
    } catch (error) {
        console.error("Failed to start server:", error);
        process.exit(1);
    }
}

startServer();