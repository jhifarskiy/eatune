// fix-genre.js
require('dotenv').config();
const { MongoClient } = require('mongodb');

if (!process.env.MONGO_PASSWORD) {
    console.error('❌ Ошибка: Пароль от MongoDB не найден в .env файле.');
    process.exit(1);
}

const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
const client = new MongoClient(MONGO_URL);

// Список артистов из твоего скриншота
const artistsToUpdate = [
    "Chilelektro", "Aqua Mundi", "Innate Joy", "Asservat", 
    "Converted Specifications", "Aurtigards", "Mighty Real", 
    "Hone Mline", "Leisure Pleasure", "Rhythmphoria", "Vis et Spes", 
    "Asking Altotas", "Schlichting", "Adaptationes Mirabiles", 
    "Wohltat", "Zirkadian Sender", "Logophilia", "Lusser", "Pikomos", 
    "Ritscher", "Kaxamarka", "Herfau Reload", "HIC ET NUNC", 
    "The Biosnakes", "Diario"
];

async function fixGenres() {
    console.log('🔄 Подключаюсь к MongoDB для исправления жанров...');
    try {
        await client.connect();
        const collection = client.db('eatune').collection('tracks');

        console.log(`🔍 Ищу треки ${artistsToUpdate.length} артистов и меняю их жанр на "Jazz"...`);

        const result = await collection.updateMany(
            { artist: { $in: artistsToUpdate } }, // Ищем по списку артистов
            { $set: { genre: "Jazz" } }
        );

        console.log(`\n✅ Готово. Жанр изменен для ${result.modifiedCount} треков.`);
        if (result.modifiedCount === 0) {
            console.log('⚠️ Если количество 0, возможно, треки уже имеют верный жанр или имена артистов в базе отличаются.');
        }

    } catch (error) {
        console.error('❗️ Произошла ошибка:', error);
    } finally {
        await client.close();
        console.log('🔌 Соединение с MongoDB закрыто.');
    }
}

fixGenres();