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
const USER_COOLDOWN_MINUTES = 5;
const HISTORY_MAX_SIZE = 30;
const BACKGROUND_QUEUE_SIZE = 4;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.set('trust proxy', 1);

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let venueQueues = {};
let userCooldowns = {};
let backgroundPlaylist = [];

// ... (функции broadcastQueueUpdate и ensureSufficientBackgroundTracks без изменений) ...
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


// --- (WebSocket .on('connection') без изменений) ---
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


app.get('/tracks', (req, res) => {
    res.json(backgroundPlaylist);
});


app.post('/queue', async (req, res) => {
    // =================================================================
    // >> НАЧАЛО БЛОКА С ЛОГИРОВАНИЕМ <<
    // =================================================================
    const { id: trackId, venueId } = req.body;
    const userIp = req.ip;

    console.log(`\n--- [${new Date().toLocaleTimeString()}] NEW REQUEST FOR /queue ---`);
    console.log(`DATA: TrackID=${trackId}, VenueID=${venueId}, IP=${userIp}`);

    if (!trackId || !venueId) {
        return res.status(400).json({ error: 'Track ID and Venue ID are required' });
    }
    
    if (!userIp) {
        console.log("!!! LOGGING: User IP is undefined.");
        return res.status(400).json({ error: "Could not identify your network address." });
    }
    
    if (!venueQueues[venueId]) {
        venueQueues[venueId] = { queue: [], history: [], listeners: new Set(), backgroundTrackIndex: 0, trackCooldowns: new Map() };
    }
    
    const venue = venueQueues[venueId];
    const now = Date.now();

    console.log('LOGGING: Current userCooldowns state:', JSON.stringify(userCooldowns, null, 2));
    const venueUserCooldowns = userCooldowns[venueId] || {};
    const lastAddTimestamp = venueUserCooldowns[userIp];

    if (lastAddTimestamp) {
        const cooldownEndTime = lastAddTimestamp + USER_COOLDOWN_MINUTES * 60 * 1000;
        console.log(`LOGGING: Found timestamp for IP ${userIp}. Cooldown ends at ${new Date(cooldownEndTime).toLocaleTimeString()}`);
        
        if (now < cooldownEndTime) {
            const timeLeftMs = cooldownEndTime - now;
            console.log(`-> LOGGING: Cooldown ACTIVE. Rejecting request.`);
            return res.status(429).json({
                error: `Следующий трек можно будет заказать через ${Math.ceil(timeLeftMs / 60000)} мин.`,
                cooldownType: 'user',
                timeLeftSeconds: Math.ceil(timeLeftMs / 1000),
            });
        } else {
            console.log('-> LOGGING: Cooldown has expired. Proceeding.');
        }
    } else {
        console.log(`-> LOGGING: No cooldown found for IP ${userIp}. Proceeding.`);
    }
    // =================================================================
    // >> КОНЕЦ БЛОКА С ЛОГИРОВАНИЕМ <<
    // =================================================================

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

    const newTrack = { ...selectedTrack, isBackgroundTrack: false, requestedBy: userIp };
    const currentlyPlaying = venue.queue.shift();
    venue.queue = venue.queue.filter(track => !track.isBackgroundTrack);
    venue.queue.push(newTrack);
    if (currentlyPlaying) {
        venue.queue.unshift(currentlyPlaying);
    }
    
    console.log(`-> LOGGING: SUCCESS. Setting new cooldown for IP ${userIp}.`);
    if (!userCooldowns[venueId]) {
        userCooldowns[venueId] = {};
    }
    userCooldowns[venueId][userIp] = now;

    broadcastQueueUpdate(venueId);
    res.status(201).json({ success: true, message: 'Трек добавлен в очередь!' });
});

// ... (остальные маршруты /track/next, /track/previous без изменений) ...
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


// ... (функция cleanupUserCooldowns и startServer без изменений) ...
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
setInterval(cleanupUserCooldowns, 5 * 60 * 1000);

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