// clean-db-names.js
require('dotenv').config();
const { MongoClient } = require('mongodb');

const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const DB_NAME = 'eatune';
const COLLECTION_NAME = 'tracks';

// Функция для очистки строки от мусора
function cleanName(rawName) {
    if (!rawName) return '';
    // Удаляем (Sefon.Pro), (Sefon.me), текст в других скобках, и цифры в начале
    return rawName
        .replace(/\s*\(Sefon\.(Pro|me)\)\s*/gi, '')
        .replace(/\s*\(.*?\)|\[.*?\]/g, '')
        .replace(/^\d+\.\s*/, '')
        .trim();
}

async function cleanDatabaseNames() {
    if (!process.env.MONGO_PASSWORD) {
        console.error('❌ Ошибка: Пароль от MongoDB не найден в .env файле.');
        return;
    }

    const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
    const client = new MongoClient(MONGO_URL);

    console.log('🔄 Подключаюсь к MongoDB для очистки названий...');

    try {
        await client.connect();
        const db = client.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);

        const tracks = await collection.find({}).toArray();
        console.log(`🔎 Найдено ${tracks.length} треков для проверки.`);

        let updatedCount = 0;

        for (const track of tracks) {
            const newTitle = cleanName(track.title);
            const newArtist = cleanName(track.artist);

            // Обновляем, только если есть изменения
            if (newTitle !== track.title || newArtist !== track.artist) {
                updatedCount++;
                console.log(`\nОбновляю трек ID: ${track._id}`);
                console.log(`   Артист: "${track.artist}" -> "${newArtist}"`);
                console.log(`   Название: "${track.title}" -> "${newTitle}"`);
                
                await collection.updateOne(
                    { _id: track._id },
                    { $set: { title: newTitle, artist: newArtist } }
                );
            }
        }
        
        console.log(`\n✅ Готово. Обновлено названий: ${updatedCount} из ${tracks.length}.`);

    } catch (error) {
        console.error('❗️ Произошла ошибка при очистке:', error);
    } finally {
        await client.close();
        console.log('🔌 Соединение с MongoDB закрыто.');
    }
}

cleanDatabaseNames();