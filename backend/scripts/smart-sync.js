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

// --- ИЗМЕНЕНИЕ: Проверяем новую переменную R2_PUBLIC_URL ---
if (!R2_CONFIG.credentials.accessKeyId || !R2_CONFIG.credentials.secretAccessKey || !process.env.MONGO_PASSWORD || !process.env.R2_PUBLIC_URL) {
    console.error('❌ Ошибка: Не все переменные заданы. Проверьте R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, MONGO_PASSWORD и R2_PUBLIC_URL в вашем .env файле.');
    process.exit(1);
}

const s3Client = new S3Client(R2_CONFIG);
const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
const mongoClient = new MongoClient(MONGO_URL, { tls: true });
// --- ИЗМЕНЕНИЕ: Формируем базовый публичный URL ---
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
    console.log('🤖 Запущен умный синхронизатор (Cloudflare R2)...');
    
    try {
        await mongoClient.connect();
        const db = mongoClient.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);

        console.log('🔄 Запускаю полную пересинхронизацию URL в базе данных...');
        
        const allTracks = await collection.find({}).toArray();
        const bulkOps = [];

        for (const track of allTracks) {
            // Извлекаем ключ файла из старого URL
            const oldUrl = new URL(track.url);
            const key = decodeURIComponent(oldUrl.pathname.substring(1)); // Убираем ведущий '/'
            
            // Собираем новый, правильный публичный URL
            const newPublicUrl = `${PUBLIC_R2_URL_BASE}/${encodeURIComponent(key)}`;

            if (track.url !== newPublicUrl) {
                bulkOps.push({
                    updateOne: {
                        filter: { _id: track._id },
                        update: { $set: { url: newPublicUrl } }
                    }
                });
            }
        }
        
        if (bulkOps.length > 0) {
            console.log(`Found ${bulkOps.length} tracks with outdated URLs. Updating now...`);
            await collection.bulkWrite(bulkOps);
            console.log(`✅ Успешно обновлено ${bulkOps.length} URL в базе данных.`);
        } else {
            console.log('✅ Все URL в базе данных уже в актуальном состоянии.');
        }

    } catch (error) {
        console.error('❌ Произошла критическая ошибка:', error);
    } finally {
        await mongoClient.close();
        console.log('🔌 Соединение с MongoDB закрыто.');
    }
}

smartSync();