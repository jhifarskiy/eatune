const fs = require('fs').promises;
const path = require('path');

// --- Пути к файлам ---
const DB_PATH = path.join(__dirname, '..', 'db', 'tracks.json');
const QUEUE_PATH = path.join(__dirname, 'queue.json');
const CURRENT_TRACK_PATH = path.join(__dirname, 'currentTrack.json');

// --- Переменные в памяти ---
let userQueue = []; // Очередь треков от пользователей
let autoPlaylist = []; // Автоматический плейлист из базы
let recentlyPlayed = []; // История последних проигранных треков для авто-пдейлиста
const RECENTLY_PLAYED_MAX_SIZE = 20; // Сколько треков хранить в истории

let trackCooldowns = new Map(); // Карта для хранения кулдаунов треков (trackId => cooldownEndTime)
const COOLDOWN_MINUTES = 15; // Время кулдауна в минутах

// --- Функции ---

/**
 * Инициализация плейлистов при старте сервера
 */
const initializePlayer = async () => {
    try {
        // Загружаем очередь, если она есть
        const queueData = await fs.readFile(QUEUE_PATH, 'utf8');
        const savedQueue = JSON.parse(queueData);
        if (Array.isArray(savedQueue)) {
            userQueue = savedQueue;
        }

        // Загружаем треки из базы для авто-плейлиста
        const dbData = await fs.readFile(DB_PATH, 'utf8');
        autoPlaylist = JSON.parse(dbData);
        shuffleArray(autoPlaylist); // Перемешиваем для случайного порядка

        console.log('Плеер инициализирован.');
        playNextTrack(); // Запускаем воспроизведение
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.log('Файлы очереди или базы не найдены, создаем новые.');
            await fs.writeFile(QUEUE_PATH, JSON.stringify([]));
            await fs.writeFile(CURRENT_TRACK_PATH, JSON.stringify({}));
        } else {
            console.error('Ошибка инициализации плеера:', error);
        }
    }
};

/**
 * Перемешивание массива (для случайного плейлиста)
 */
const shuffleArray = (array) => {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
};

/**
 * Сохранение пользовательской очереди в файл
 */
const saveQueue = async () => {
    try {
        await fs.writeFile(QUEUE_PATH, JSON.stringify(userQueue, null, 2));
    } catch (error) {
        console.error('Ошибка сохранения очереди:', error);
    }
};

/**
 * Выбор и запуск следующего трека
 */
const playNextTrack = async () => {
    let nextTrack = null;

    // 1. Приоритет - пользовательская очередь
    if (userQueue.length > 0) {
        nextTrack = userQueue.shift();
        console.log(`Играет трек из пользовательской очереди: ${nextTrack.title}`);
    }
    // 2. Если пользовательская очередь пуста, берем из авто-плейлиста
    else {
        // Выбираем трек, которого нет в recentlyPlayed
        let trackFound = false;
        for (let i = 0; i < autoPlaylist.length; i++) {
            const potentialTrack = autoPlaylist[i];
            if (!recentlyPlayed.some(p => p.id === potentialTrack.id)) {
                nextTrack = potentialTrack;
                // Перемещаем выбранный трек в конец, чтобы он не играл снова сразу же
                autoPlaylist.splice(i, 1);
                autoPlaylist.push(nextTrack);
                trackFound = true;
                break;
            }
        }
        // Если все треки в плейлисте уже были недавно проиграны, просто берем первый
        if (!trackFound) {
            nextTrack = autoPlaylist[0];
            autoPlaylist.splice(0, 1);
            autoPlaylist.push(nextTrack);
        }
         console.log(`Играет трек из авто-плейлиста: ${nextTrack.title}`);
    }

    if (nextTrack) {
        // Добавляем трек в историю проигранных
        recentlyPlayed.push(nextTrack);
        if (recentlyPlayed.length > RECENTLY_PLAYED_MAX_SIZE) {
            recentlyPlayed.shift(); // Удаляем самый старый трек из истории
        }
        
        const currentTrackData = {
            ...nextTrack,
            startTime: Date.now()
        };
        await fs.writeFile(CURRENT_TRACK_PATH, JSON.stringify(currentTrackData, null, 2));
        await saveQueue();
    } else {
        // Если треков нет нигде, очищаем currentTrack
        await fs.writeFile(CURRENT_TRACK_PATH, JSON.stringify({}));
        console.log('Плейлисты пусты. Ожидание новых треков.');
    }
};

/**
 * Добавление трека в пользовательскую очередь
 */
const addToQueue = async (req, res) => {
    const { trackId } = req.body;
    if (!trackId) {
        return res.status(400).json({ message: 'Не указан ID трека.' });
    }

    // Проверка кулдауна
    if (trackCooldowns.has(trackId) && Date.now() < trackCooldowns.get(trackId)) {
        const timeLeft = Math.ceil((trackCooldowns.get(trackId) - Date.now()) / 60000);
        return res.status(429).json({ message: `Этот трек недавно играл. Попробуйте снова через ${timeLeft} мин.` });
    }

    try {
        const dbData = await fs.readFile(DB_PATH, 'utf8');
        const tracks = JSON.parse(dbData);
        const trackToAdd = tracks.find(t => t.id === trackId);

        if (!trackToAdd) {
            return res.status(404).json({ message: 'Трек не найден в базе.' });
        }

        userQueue.push(trackToAdd);
        
        // Устанавливаем кулдаун
        const cooldownEndTime = Date.now() + COOLDOWN_MINUTES * 60 * 1000;
        trackCooldowns.set(trackId, cooldownEndTime);

        await saveQueue();
        
        // Если до этого ничего не играло, запускаем плеер
        const currentTrack = JSON.parse(await fs.readFile(CURRENT_TRACK_PATH, 'utf8'));
        if (!currentTrack.id) {
             playNextTrack();
        }

        res.status(200).json({ message: 'Трек добавлен в очередь!', queue: userQueue });

    } catch (error) {
        console.error('Ошибка добавления в очередь:', error);
        res.status(500).json({ message: 'Внутренняя ошибка сервера.' });
    }
};

// --- Экспорт ---

module.exports = {
    initializePlayer,
    playNextTrack,
    addToQueue
};