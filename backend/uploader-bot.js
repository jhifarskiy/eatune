// uploader-bot.js

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const chokidar = require('chokidar');
const fs = require('fs').promises;
const path = require('path');
const { exec } = require('child_process');

// --- КОНФИГУРАЦИЯ ---
const WATCH_FOLDER = './tracks-to-upload';
const UPLOADED_FOLDER = path.join(WATCH_FOLDER, 'uploaded');
// ИЗМЕНЕНИЕ: Устанавливаем лимит одновременных загрузок
const CONCURRENCY_LIMIT = 10;

const R2_CONFIG = {
    endpoint: 'https://e51a1f68ce64b0c69f6588f1e885c3ff.r2.cloudflarestorage.com',
    region: 'auto',
    credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    }
};
const BUCKET_NAME = 'eatune';

if (!R2_CONFIG.credentials.accessKeyId || !R2_CONFIG.credentials.secretAccessKey || !process.env.MONGO_PASSWORD) {
    console.error('❌ Ошибка: Ключи доступа R2 или пароль от MongoDB не предоставлены.');
    process.exit(1);
}

const s3Client = new S3Client(R2_CONFIG);

const runDbSync = () => {
    console.log('🔄 Запускаю финальную синхронизацию с базой данных (smart-sync.js)...');
    
    const command = `R2_ACCESS_KEY_ID="${process.env.R2_ACCESS_KEY_ID}" R2_SECRET_ACCESS_KEY="${process.env.R2_SECRET_ACCESS_KEY}" MONGO_PASSWORD="${process.env.MONGO_PASSWORD}" node scripts/smart-sync.js`;

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`❌ Ошибка при синхронизации с БД: ${error.message}`);
            return;
        }
        if (stderr) {
            console.error(` stderr при синхронизации: ${stderr}`);
        }
        console.log(`📡 stdout синхронизации:\n${stdout}`);
        console.log('✅ Финальная синхронизация с базой данных завершена.');
    });
};

const uploadFile = async (filePath) => {
    const s3Key = path.relative(WATCH_FOLDER, filePath).replace(/\\/g, '/');

    console.log(`  -> 📤 Загружаю: ${path.basename(filePath)}`);

    try {
        const fileContent = await fs.readFile(filePath);
        const uploadParams = {
            Bucket: BUCKET_NAME,
            Key: s3Key,
            Body: fileContent,
        };

        await s3Client.send(new PutObjectCommand(uploadParams));
        
        const newPath = path.join(UPLOADED_FOLDER, s3Key);
        await fs.mkdir(path.dirname(newPath), { recursive: true });
        
        await fs.rename(filePath, newPath);
        // console.log(`  -> ✅ Успешно загружен и перемещен: ${s3Key}`);
    } catch (err) {
        console.error(`❌ Ошибка при обработке файла "${filePath}":`, err);
    }
};

const startBot = async () => {
    await fs.mkdir(WATCH_FOLDER, { recursive: true });
    await fs.mkdir(UPLOADED_FOLDER, { recursive: true });

    console.log(`🤖 Бот-загрузчик запущен.`);
    console.log(`📂 Сканирую папку: ${path.resolve(WATCH_FOLDER)}...`);

    // ИЗМЕНЕНИЕ: Новая логика с обработкой пачками
    const fileQueue = [];
    const watcher = chokidar.watch(WATCH_FOLDER, {
        ignored: [/(^|[\/\\])\../, UPLOADED_FOLDER],
        persistent: false, // Бот отработает один раз и завершится
        ignoreInitial: false, 
    });

    watcher.on('add', (filePath) => {
        // Просто собираем все найденные файлы в очередь
        fileQueue.push(filePath);
    });

    watcher.on('ready', async () => {
        console.log(`🔍 Найдено ${fileQueue.length} файлов для загрузки.`);
        console.log(`🚀 Начинаю загрузку пачками по ${CONCURRENCY_LIMIT} файлов.`);

        for (let i = 0; i < fileQueue.length; i += CONCURRENCY_LIMIT) {
            const chunk = fileQueue.slice(i, i + CONCURRENCY_LIMIT);
            console.log(`\n--- Обработка пачки ${Math.floor(i / CONCURRENCY_LIMIT) + 1} из ${Math.ceil(fileQueue.length / CONCURRENCY_LIMIT)} ---`);
            
            const uploadPromises = chunk.map(filePath => uploadFile(filePath));
            await Promise.all(uploadPromises);
            
            console.log(`--- ✅ Пачка завершена ---`);
        }
        
        console.log('\n\n🎉 Все файлы успешно загружены!');
        runDbSync();
    });

    watcher.on('error', (error) => console.error(`❌ Ошибка воркера: ${error}`));
};

startBot();