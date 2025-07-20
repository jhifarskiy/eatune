// backend/scripts/smart-sync.js
require('dotenv').config();

const { S3Client, ListObjectsV2Command, GetObjectCommand } = require('@aws-sdk/client-s3');
const { MongoClient } = require('mongodb');
const path = require('path');

const R2_CONFIG = {
    endpoint: `https://e51a1f68ce64b0c69f6588f1e885c3ff.r2.cloudflarestorage.com`,
    region: 'auto',
    credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    }
};
const BUCKET_NAME = 'eatune';
const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const DB_NAME = 'eatune';
const COLLECTION_NAME = 'tracks';
const METADATA_CHUNK_SIZE_KB = 256;

if (!process.env.R2_ACCESS_KEY_ID || !process.env.R2_SECRET_ACCESS_KEY || !process.env.MONGO_PASSWORD || !process.env.R2_PUBLIC_URL) {
    console.error('❌ Ошибка: Не все переменные заданы. Проверьте R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, MONGO_PASSWORD и R2_PUBLIC_URL в вашем .env файле.');
    process.exit(1);
}

const s3Client = new S3Client(R2_CONFIG);
const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
const mongoClient = new MongoClient(MONGO_URL, { tls: true });
const PUBLIC_R2_URL_BASE = `https://${process.env.R2_PUBLIC_URL}`;

function cleanName(rawName) {
    if (!rawName) return '';
    const lastPart = rawName.split('] ').pop();
    return lastPart ? lastPart.trim() : rawName.trim();
}

function extractYear(filePath) {
    const match = filePath.match(/\b(19[8-9][0-9]|20[0-2][0-9])\b/);
    return match ? parseInt(match[1], 10) : null;
}

const streamToBuffer = (stream) =>
    new Promise((resolve, reject) => {
        const chunks = [];
        stream.on('data', (chunk) => chunks.push(chunk));
        stream.on('error', reject);
        stream.on('end', () => resolve(Buffer.concat(chunks)));
    });

async function smartSync() {
    const mm = await import('music-metadata');
    console.log('🤖 Запущен умный синхронизатор...');
    
    try {
        await mongoClient.connect();
        const db = mongoClient.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);

        // --- ЭТАП 1: ОБНОВЛЕНИЕ СУЩЕСТВУЮЩИХ ТРЕКОВ ---
        console.log('\n--- Этап 1: Проверка и обновление существующих треков ---');
        const allDbTracks = await collection.find({}).toArray();
        const bulkOps = [];

        for (const track of allDbTracks) {
            const updates = {};
            const key = track.filePath || decodeURIComponent(new URL(track.url).pathname.substring(1));
            const newPublicUrl = `${PUBLIC_R2_URL_BASE}/${encodeURIComponent(key)}`;

            if (track.url !== newPublicUrl) {
                updates.url = newPublicUrl;
            }
            if (!track.filePath) {
                updates.filePath = key;
            }
            
            if (Object.keys(updates).length > 0) {
                 bulkOps.push({
                    updateOne: {
                        filter: { _id: track._id },
                        update: { $set: updates }
                    }
                });
            }
        }
        
        if (bulkOps.length > 0) {
            console.log(`Найдено ${bulkOps.length} треков для обновления (URL и/или filePath)...`);
            await collection.bulkWrite(bulkOps);
            console.log(`✅ Успешно обновлено ${bulkOps.length} треков в базе.`);
        } else {
            console.log('✅ Все треки в базе уже актуальны.');
        }

        // --- ЭТАП 2: ПОИСК И ДОБАВЛЕНИЕ НОВЫХ ФАЙЛОВ ---
        console.log('\n--- Этап 2: Поиск новых файлов в R2 ---');
        const listCommand = new ListObjectsV2Command({ Bucket: BUCKET_NAME });
        const { Contents } = await s3Client.send(listCommand);
        const r2Files = Contents ? Contents.filter(file => /\.(mp3|wav|flac|m4a)$/i.test(file.Key) && file.Size > 0) : [];
        
        const updatedDbTracks = await collection.find({}, { projection: { filePath: 1 } }).toArray();
        const dbFilePaths = new Set(updatedDbTracks.map(track => track.filePath));
        
        const filesToAdd = r2Files.filter(file => !dbFilePaths.has(file.Key));
        
        if (filesToAdd.length === 0) {
            console.log('✨ Новых треков для добавления не найдено.');
            return;
        }

        console.log(`➕ Найдено ${filesToAdd.length} новых треков для добавления...`);
        const newTrackDocuments = [];
        for (const [index, audioFile] of filesToAdd.entries()) {
            console.log(`  -> Обработка ${index + 1}/${filesToAdd.length}: ${audioFile.Key}`);
            try {
                const range = `bytes=0-${METADATA_CHUNK_SIZE_KB * 1024}`;
                const getObjectCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: audioFile.Key, Range: range });
                const { Body } = await s3Client.send(getObjectCmd);
                const buffer = await streamToBuffer(Body);
                const metadata = await mm.parseBuffer(buffer, { mimeType: 'audio/mpeg', size: audioFile.Size });
                
                const { common, format } = metadata;
                const title = cleanName(common.title) || path.basename(audioFile.Key).replace(/\.[^/.]+$/, "");
                const artist = cleanName(common.artist) || 'Unknown Artist';
                const durationSeconds = Math.round(format.duration || 0);
                const minutes = Math.floor(durationSeconds / 60);
                const seconds = durationSeconds % 60;

                newTrackDocuments.push({
                    title, artist,
                    duration: `${minutes}:${seconds.toString().padStart(2, '0')}`,
                    genre: common.genre && common.genre.length > 0 ? common.genre[0] : 'Pop',
                    year: common.year || extractYear(audioFile.Key),
                    coverUrl: null,
                    url: `${PUBLIC_R2_URL_BASE}/${encodeURIComponent(audioFile.Key)}`,
                    filePath: audioFile.Key, // <-- ДОБАВЛЕНО: Сохраняем путь к файлу
                });
            } catch (error) {
                 console.error(`   ❗️ Ошибка при обработке файла ${audioFile.Key}: ${error.message}. Пропускаю...`);
            }
        }

        if (newTrackDocuments.length > 0) {
            console.log(`\n💾 Записываю ${newTrackDocuments.length} новых треков в MongoDB...`);
            await collection.insertMany(newTrackDocuments);
            console.log(`✅ Успешно добавлено ${newTrackDocuments.length} треков.`);
        }

    } catch (error) {
        console.error('❌ Произошла критическая ошибка:', error);
    } finally {
        await mongoClient.close();
        console.log('🔌 Соединение с MongoDB закрыто.');
    }
}

smartSync();