const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { MongoClient } = require('mongodb');
const fs = require('fs');
const path = require('path');

// ===============================================================
// >> ВАШИ ДАННЫЕ ЗДЕСЬ <<
// ===============================================================

// --- Данные от Backblaze B2 ---
const B2_CONFIG = {
    endpoint: 'https://s3.us-west-004.backblazeb2.com',
    region: 'us-west-004',
    
    // ИЗМЕНЕНИЕ ЗДЕСЬ: Ключи теперь сгруппированы в отдельный объект 'credentials'
    credentials: {
        accessKeyId: '00411c4ed76c7310000000002',
        secretAccessKey: 'K0049JrtTehedMNjwKxVsHNcdHQMa8k',
    }
};
const BUCKET_NAME = 'Eatune';

// --- Данные от MongoDB ---
const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const DB_NAME = 'eatune';
const COLLECTION_NAME = 'tracks';

// ===============================================================
// Дальше код можно не трогать
// ===============================================================

function parseFileName(fileName) {
    const cleanName = fileName.replace(/\.(mp3|wav|flac|m4a)$/i, '');
    const parts = cleanName.split(' - ');
    if (parts.length >= 2) {
        return { artist: parts[0].trim(), title: parts.slice(1).join(' - ').trim() };
    }
    return { artist: 'Unknown Artist', title: cleanName.trim() };
}

async function balancedSync() {
    if (!process.env.MONGO_PASSWORD) {
        console.error('❌ Ошибка: Пароль от MongoDB не передан. Используйте команду: MONGO_PASSWORD="ваш_пароль" node balanced-sync.js');
        return;
    }
    const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);

    let metadataTemplate = {};
    const templatePath = path.join(__dirname, 'metadata_template.json');
    if (fs.existsSync(templatePath)) {
        try {
            metadataTemplate = JSON.parse(fs.readFileSync(templatePath, 'utf-8'));
            console.log('📄 Шаблон с длительностью треков (metadata_template.json) успешно загружен.');
        } catch (error) {
            console.error('❌ Ошибка при чтении файла metadata_template.json:', error.message);
        }
    }

    const s3Client = new S3Client(B2_CONFIG);
    const mongoClient = new MongoClient(MONGO_URL);

    try {
        await mongoClient.connect();
        const db = mongoClient.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);
        console.log('✅ Успешно подключились к MongoDB');

        console.log(`🔍 Получаем список всех файлов из бакета "${BUCKET_NAME}"...`);
        const { Contents } = await s3Client.send(new ListObjectsV2Command({ Bucket: BUCKET_NAME }));
        if (!Contents) return console.log('🟡 В бакете нет файлов.');

        const audioFiles = [];
        const coverFiles = new Map();
        for (const file of Contents) {
            if (/\.(mp3|wav|flac|m4a)$/i.test(file.Key)) {
                audioFiles.push(file);
            } else if (/^covers\/.*\.(jpg|jpeg|png|webp)$/i.test(file.Key)) {
                const coverKey = file.Key.replace(/^covers\//, '').replace(/\.(jpg|jpeg|png|webp)$/i, '');
                coverFiles.set(coverKey, file.Key);
            }
        }
        console.log(`🎶 Найдено аудиофайлов: ${audioFiles.length}. 🖼️ Найдено обложек: ${coverFiles.size}.`);

        const trackDocuments = [];
        for (const audioFile of audioFiles) {
            const trackKey = audioFile.Key.replace(/\.(mp3|wav|flac|m4a)$/i, '');
            const parsed = parseFileName(audioFile.Key);
            const url = `https://${BUCKET_NAME}.${B2_CONFIG.endpoint.replace('https://', '')}/${encodeURIComponent(audioFile.Key)}`;
            const metadata = metadataTemplate[audioFile.Key] || {};

            let coverUrl = null;
            if (coverFiles.has(trackKey)) {
                const coverPath = coverFiles.get(trackKey);
                coverUrl = `https://${BUCKET_NAME}.${B2_CONFIG.endpoint.replace('https://', '')}/${encodeURIComponent(coverPath)}`;
            }

            const trackDocument = {
                title: parsed.title,
                artist: parsed.artist,
                duration: metadata.duration || '0:00',
                coverUrl: coverUrl,
                url: url,
            };
            trackDocuments.push(trackDocument);
        }

        if (trackDocuments.length > 0) {
            console.log('💾 Очищаем коллекцию и записываем новые данные...');
            await collection.deleteMany({});
            await collection.insertMany(trackDocuments);
            console.log(`✅ Успешно добавлено ${trackDocuments.length} треков.`);
        }

    } catch (error) {
        console.error('❌ Произошла критическая ошибка:', error);
    } finally {
        await mongoClient.close();
        console.log('🔌 Соединение с MongoDB закрыто.');
    }
}

balancedSync();

