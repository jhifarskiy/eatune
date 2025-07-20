// reset-covers.js
require('dotenv').config();
const { MongoClient } = require('mongodb');

const MONGO_URI_TEMPLATE = 'mongodb+srv://jhifarskiy:<ПАРОЛЬ>@eatune.8vrsmid.mongodb.net/eatune?retryWrites=true&w=majority';
const DB_NAME = 'eatune';
const COLLECTION_NAME = 'tracks';

async function resetCovers() {
  if (!process.env.MONGO_PASSWORD) {
    console.error('❌ Ошибка: Пароль от MongoDB не найден в .env файле.');
    return;
  }

  const MONGO_URL = MONGO_URI_TEMPLATE.replace('<ПАРОЛЬ>', process.env.MONGO_PASSWORD);
  const client = new MongoClient(MONGO_URL);

  console.log('🔄 Подключаюсь к MongoDB для сброса обложек...');

  try {
    await client.connect();
    const db = client.db(DB_NAME);
    const collection = db.collection(COLLECTION_NAME);

    const result = await collection.updateMany(
      { "coverUrl": "not_found" },
      { "$set": { "coverUrl": null } }
    );

    console.log(`✅ Готово. Сброшено обложек для повторного поиска: ${result.modifiedCount}.`);

  } catch (error) {
    console.error('❗️ Произошла ошибка при сбросе обложек:', error);
  } finally {
    await client.close();
    console.log('🔌 Соединение с MongoDB для сброса закрыто.');
  }
}

resetCovers();