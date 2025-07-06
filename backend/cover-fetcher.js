// cover-fetcher.js
require('dotenv').config();
const { MongoClient, ObjectId } = require('mongodb');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const axios = require('axios');
const sharp = require('sharp');

// --- КОНФИГУРАЦИЯ ---
const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const DB_NAME = 'eatune';
const COLLECTION_NAME = 'tracks';

const B2_CONFIG = {
    endpoint: 'https://s3.us-west-004.backblazeb2.com',
    region: 'us-west-004',
    credentials: {
        accessKeyId: process.env.B2_ACCESS_KEY_ID,
        secretAccessKey: process.env.B2_SECRET_ACCESS_KEY,
    }
};
const BUCKET_NAME = 'Eatune';
const COVER_UPLOAD_PATH = 'covers/';
const COVER_SIZE = 500;
const REQUEST_DELAY_MS = 500;

// --- ПРОВЕРКА КЛЮЧЕЙ ---
if (!process.env.MONGO_PASSWORD || !process.env.B2_ACCESS_KEY_ID || !process.env.SPOTIFY_CLIENT_ID) {
    console.error('❌ Ошибка: Ключи доступа или пароль от MongoDB не предоставлены в файле .env');
    process.exit(1);
}

const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
const mongoClient = new MongoClient(MONGO_URL);
const s3Client = new S3Client(B2_CONFIG);

// ... (Функции getSpotifyToken и uploadCoverToB2 остаются без изменений)

async function getSpotifyToken() {
    console.log('🔑 Получаю токен от Spotify...');
    const authString = Buffer.from(`${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`).toString('base64');
    try {
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

async function uploadCoverToB2(imageBuffer, trackId) {
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

        return `https://${BUCKET_NAME}.${B2_CONFIG.endpoint.replace('https://', '')}/${s3Key}`;
    } catch (error) {
        console.error(`❗️ Ошибка загрузки обложки для трека ${trackId}:`, error);
        return null;
    }
}


/**
 * Ищет трек на Spotify и возвращает URL обложки
 */
async function findCoverOnSpotify(track, token) {
    const query = encodeURIComponent(`artist:"${track.artist}" track:"${track.title}"`);
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
        console.error(`❗️ Ошибка поиска для "${track.artist} - ${track.title}":`, error.message);
        return null;
    }
}

/**
 * НОВАЯ ФУНКЦИЯ: Ищет трек в iTunes и возвращает URL обложки
 */
async function findCoverOnItunes(track) {
    const term = encodeURIComponent(`${track.artist} ${track.title}`);
    const url = `https://itunes.apple.com/search?term=${term}&entity=song&limit=1`;
    try {
        const response = await axios.get(url);
        const results = response.data.results;
        if (results && results.length > 0) {
            // Получаем URL обложки и заменяем размер на более качественный
            const artworkUrl = results[0].artworkUrl100;
            if (artworkUrl) {
                return artworkUrl.replace('100x100bb.jpg', '600x600bb.jpg');
            }
        }
        return null;
    } catch (error) {
        console.error(`❗️ Ошибка поиска в iTunes для "${track.artist} - ${track.title}":`, error.message);
        return null;
    }
}


/**
 * Основная функция
 */
async function main() {
    const mode = process.argv[2]; // Получаем режим из аргументов командной строки (spotify или itunes)
    if (!['spotify', 'itunes'].includes(mode)) {
        console.error("❌ Укажите режим работы: 'spotify' или 'itunes'. Пример: node cover-fetcher.js spotify");
        return;
    }

    let mongoConnection;
    try {
        console.log(`\n🚀 Запускаю процесс поиска обложек в режиме: ${mode.toUpperCase()}`);
        
        mongoConnection = await mongoClient.connect();
        const db = mongoConnection.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);

        let tracksToUpdate;
        let searchFunction;
        let notFoundMarker;

        if (mode === 'spotify') {
            const spotifyToken = await getSpotifyToken();
            if (!spotifyToken) return;
            // Ищем треки, у которых еще не было попыток поиска
            tracksToUpdate = await collection.find({ coverUrl: null }).toArray();
            searchFunction = (track) => findCoverOnSpotify(track, spotifyToken);
            notFoundMarker = 'spotify_not_found';
        } else { // itunes mode
            // Ищем треки, которые не были найдены в Spotify
            tracksToUpdate = await collection.find({ coverUrl: 'spotify_not_found' }).toArray();
            searchFunction = findCoverOnItunes;
            notFoundMarker = 'not_found_anywhere';
        }

        if (tracksToUpdate.length === 0) {
            console.log(`✅ В режиме "${mode}" треков для обновления не найдено. Работа завершена.`);
            return;
        }

        console.log(`🎶 Найдено ${tracksToUpdate.length} треков для обработки в режиме "${mode}".`);

        for (const [index, track] of tracksToUpdate.entries()) {
            console.log(`\n--- [${index + 1}/${tracksToUpdate.length}] Обработка: ${track.artist} - ${track.title}`);

            const coverUrl = await searchFunction(track);

            if (coverUrl) {
                console.log(`   ✔️ Найдена обложка: ${coverUrl}`);
                const imageResponse = await axios.get(coverUrl, { responseType: 'arraybuffer' });
                const finalCoverUrl = await uploadCoverToB2(Buffer.from(imageResponse.data), track._id.toString());

                if (finalCoverUrl) {
                    await collection.updateOne(
                        { _id: new ObjectId(track._id) },
                        { $set: { coverUrl: finalCoverUrl } }
                    );
                    console.log(`   💾 Успешно обновлено в MongoDB.`);
                }
            } else {
                console.log('   ❌ Обложка не найдена.');
                await collection.updateOne({ _id: new ObjectId(track._id) }, { $set: { coverUrl: notFoundMarker } });
            }
            await new Promise(resolve => setTimeout(resolve, REQUEST_DELAY_MS));
        }

        console.log(`\n\n🎉 Все треки в режиме "${mode}" обработаны!`);

    } catch (error) {
        console.error('❌ Произошла критическая ошибка в процессе:', error);
    } finally {
        if (mongoConnection) {
            await mongoConnection.close();
            console.log('🔌 Соединение с MongoDB закрыто.');
        }
    }
}

main();