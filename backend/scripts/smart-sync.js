// backend/scripts/smart-sync.js

const { S3Client, ListObjectsV2Command, GetObjectCommand } = require('@aws-sdk/client-s3');
const { MongoClient } = require('mongodb');
const { Readable } = require('stream');
const path = require('path');

// ИЗМЕНЕНИЕ: Конфигурация для Cloudflare R2 с вашими данными
const R2_CONFIG = {
    endpoint: 'https://e51a1f68ce64b0c69f6588f1e885c3ff.r2.cloudflarestorage.com',
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

if (!R2_CONFIG.credentials.accessKeyId || !R2_CONFIG.credentials.secretAccessKey || !process.env.MONGO_PASSWORD) {
    console.error('❌ Ошибка: Ключи доступа R2 или пароль от MongoDB не предоставлены.');
    process.exit(1);
}

const s3Client = new S3Client(R2_CONFIG);
const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
const mongoClient = new MongoClient(MONGO_URL, { tls: true });

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
        const listCommand = new ListObjectsV2Command({ Bucket: BUCKET_NAME });
        const { Contents } = await s3Client.send(listCommand);
        
        if (!Contents) {
            console.log("🎶 Файлов в бакете не найдено. Завершаю работу.");
            return;
        }

        const audioFiles = Contents.filter(file => /\.(mp3|wav|flac|m4a)$/i.test(file.Key) && file.Size > 0);
        console.log(`🎶 Найдено аудиофайлов для обработки: ${audioFiles.length}`);

        const trackDocuments = [];

        for (const [index, audioFile] of audioFiles.entries()) {
            console.log(`\n--- Обработка файла ${index + 1} из ${audioFiles.length}: ${audioFile.Key} ---`);
            
            try {
                const range = `bytes=0-${METADATA_CHUNK_SIZE_KB * 1024}`;
                const getObjectCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: audioFile.Key, Range: range });
                const response = await s3Client.send(getObjectCmd);
                const buffer = await streamToBuffer(response.Body);

                const metadata = await mm.parseBuffer(buffer, { mimeType: 'audio/mpeg', size: audioFile.Size });
                const { common, format } = metadata;
                
                const title = cleanName(common.title) || path.basename(audioFile.Key).replace(/\.[^/.]+$/, "");
                const artist = cleanName(common.artist) || 'Unknown Artist';
                const durationSeconds = Math.round(format.duration || 0);
                const minutes = Math.floor(durationSeconds / 60);
                const seconds = durationSeconds % 60;
                const duration = `${minutes}:${seconds.toString().padStart(2, '0')}`;
                
                const year = common.year || extractYear(audioFile.Key);
                const genre = common.genre && common.genre.length > 0 ? common.genre[0] : 'Pop';

                console.log(`      -> Исполнитель: ${artist}, Название: ${title}, Год: ${year || 'N/A'}`);
                
                const endpointUrl = R2_CONFIG.endpoint.replace('https://', '');
                trackDocuments.push({
                    title, artist, duration, genre, year,
                    coverUrl: null,
                    url: `https://${BUCKET_NAME}.${endpointUrl}/${encodeURIComponent(audioFile.Key)}`,
                });

            } catch (error) {
                 console.error(`   ❗️ Ошибка при обработке файла ${audioFile.Key}: ${error.message}. Пропускаю...`);
            }
        }

        if (trackDocuments.length > 0) {
            console.log('\n💾 Очищаю коллекцию и записываю новые данные в MongoDB...');
            await collection.deleteMany({});
            await collection.insertMany(trackDocuments);
            console.log(`✅ Успешно добавлено ${trackDocuments.length} треков в базу.`);
        }

    } catch (error) {
        console.error('❌ Произошла критическая ошибка:', error);
    } finally {
        await mongoClient.close();
        console.log('🔌 Соединение с MongoDB закрыто.');
    }
}

smartSync();