// cover-fetcher.js
require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const axios = require('axios');
const sharp = require('sharp');

// --- КОНФИГУРАЦИЯ (теперь из .env) ---
const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const DB_NAME = 'eatune';
const COLLECTION_NAME = 'tracks';

const R2_CONFIG = {
    endpoint: `https://e51a1f68ce64b0c69f6588f1e885c3ff.r2.cloudflarestorage.com`,
    region: 'auto',
    credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    }
};
const BUCKET_NAME = 'eatune';
const R2_PUBLIC_URL = process.env.R2_PUBLIC_URL; // Берем публичный URL из .env

const COVER_UPLOAD_PATH = 'covers/';
const COVER_SIZE = 500;
const REQUEST_DELAY_MS = 500; // Задержка между запросами, чтобы не забанили

// --- ПРОВЕРКА КЛЮЧЕЙ ---
if (!process.env.MONGO_PASSWORD || !process.env.R2_ACCESS_KEY_ID || !process.env.SPOTIFY_CLIENT_ID || !R2_PUBLIC_URL) {
    console.error('❌ Ошибка: Не все необходимые переменные (MONGO_PASSWORD, R2_ACCESS_KEY_ID, SPOTIFY_CLIENT_ID, R2_PUBLIC_URL) заданы в файле .env');
    process.exit(1);
}

const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
const mongoClient = new MongoClient(MONGO_URL);
const s3Client = new S3Client(R2_CONFIG);

async function getSpotifyToken() {
    console.log('🔑 Получаю токен от Spotify...');
    const authString = Buffer.from(`${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`).toString('base64');
    try {
        // ИСПРАВЛЕНИЕ: Используем официальный URL API Spotify для получения токена
        const response = await axios.post('https://accounts.spotify.com/api/token', 'grant_type=client_credentials', {
            headers: {
                'Authorization': `Basic ${authString}`,
                'Content-Type': 'application/x-www-form-urlencoded'
            }
        });
        console.log('✅ Токен успешно получен!');
        return response.data.access_token;
    } catch (error) {
        console.error('❗️ Не удалось получить токен:', error.response?.data);
        throw new Error('Spotify Token Error');
    }
}

async function uploadCoverToR2(imageBuffer, trackId) {
    const s3Key = `${COVER_UPLOAD_PATH}${trackId}.jpg`;
    try {
        const processedImage = await sharp(imageBuffer)
            .resize(COVER_SIZE, COVER_SIZE)
            .jpeg({ quality: 85 })
            .toBuffer();

        const command = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: s3Key,
            Body: processedImage,
            ContentType: 'image/jpeg'
        });
        await s3Client.send(command);

        // Формируем правильную публичную ссылку для R2
        return `${R2_PUBLIC_URL}/${s3Key}`;
    } catch (error) {
        console.error(`❗️ Ошибка загрузки обложки для трека ${trackId}:`, error);
        return null;
    }
}

async function findCoverOnSpotify(track, token) {
    const query = encodeURIComponent(`artist:"${track.artist}" track:"${track.title}"`);
    // ИСПРАВЛЕНИЕ: Используем официальный URL API Spotify для поиска и правильные шаблонные строки
    const url = `https://api.spotify.com/v1/search?q=${query}&type=track&limit=1`;
    try {
        const response = await axios.get(url, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const items = response.data.tracks?.items;
        if (items && items.length > 0) {
            const images = items[0].album?.images;
            if (images && images.length > 0) {
                return images[0].url; // Возвращаем самую большую обложку
            }
        }
        return null;
    } catch (error) {
        if (error.response?.status === 401) {
            console.error('❗️ Ошибка 401: Токен Spotify истек или недействителен. Перезапустите скрипт.');
            throw new Error('Invalid Spotify Token');
        }
        console.error(`❗️ Ошибка поиска для "${track.artist} - ${track.title}":`, error.message);
        return null;
    }
}

async function main() {
    let mongoConnection;
    try {
        console.log(`\n🚀 Запускаю процесс поиска обложек...`);
        
        const spotifyToken = await getSpotifyToken();
        if (!spotifyToken) return;
        
        mongoConnection = await mongoClient.connect();
        const db = mongoConnection.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);

        // Ищем все треки, у которых еще нет обложки
        const tracksToUpdate = await collection.find({ coverUrl: null }).toArray();
       
        if (tracksToUpdate.length === 0) {
            console.log(`✅ Треков для обновления не найдено. Работа завершена.`);
            return;
        }

        console.log(`🎶 Найдено ${tracksToUpdate.length} треков для обработки.`);

        for (const [index, track] of tracksToUpdate.entries()) {
            console.log(`\n--- [${index + 1}/${tracksToUpdate.length}] Обработка: ${track.artist} - ${track.title}`);

            const coverUrl = await findCoverOnSpotify(track, spotifyToken);

            if (coverUrl) {
                console.log(`   ✔️ Найдена обложка: ${coverUrl}`);
                const imageResponse = await axios.get(coverUrl, { responseType: 'arraybuffer' });
                const finalCoverUrl = await uploadCoverToR2(Buffer.from(imageResponse.data), track._id.toString());

                if (finalCoverUrl) {
                    await collection.updateOne(
                        { _id: new ObjectId(track._id) },
                        { $set: { coverUrl: finalCoverUrl } }
                    );
                    console.log(`   💾 Успешно обновлено в MongoDB.`);
                }
            } else {
                console.log('   ❌ Обложка не найдена. Помечаю, чтобы не искать повторно.');
                // Ставим пометку, чтобы в будущем не искать этот трек заново
                await collection.updateOne({ _id: new ObjectId(track._id) }, { $set: { coverUrl: 'not_found' } });
            }
            // Делаем небольшую задержку между запросами к Spotify API
            await new Promise(resolve => setTimeout(resolve, REQUEST_DELAY_MS));
        }

        console.log(`\n\n🎉 Все треки обработаны!`);

    } catch (error) {
        console.error('❌ Произошла критическая ошибка в процессе:', error.message);
    } finally {
        if (mongoConnection) {
            await mongoConnection.close();
            console.log('🔌 Соединение с MongoDB закрыто.');
        }
    }
}

main();