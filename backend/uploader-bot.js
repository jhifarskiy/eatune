// uploader-bot.js

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const chokidar = require('chokidar');
const fs = require('fs').promises;
const path = require('path');
const { exec } = require('child_process');

// --- КОНФИГУРАЦИЯ ---
const WATCH_FOLDER = './tracks-to-upload';
const UPLOADED_FOLDER = path.join(WATCH_FOLDER, 'uploaded');

const B2_CONFIG = {
    endpoint: 'https://s3.us-west-004.backblazeb2.com',
    region: 'us-west-004',
    credentials: {
        accessKeyId: process.env.B2_ACCESS_KEY_ID,
        secretAccessKey: process.env.B2_SECRET_ACCESS_KEY,
    }
};
const BUCKET_NAME = 'Eatune';

// --- Проверка наличия ключей ---
if (!B2_CONFIG.credentials.accessKeyId || !B2_CONFIG.credentials.secretAccessKey || !process.env.MONGO_PASSWORD) {
    console.error('❌ Ошибка: Ключи доступа или пароль от MongoDB не предоставлены.');
    console.error('Пожалуйста, запустите скрипт с переменными окружения:');
    console.error('B2_ACCESS_KEY_ID="..." B2_SECRET_ACCESS_KEY="..." MONGO_PASSWORD="..." node uploader-bot.js');
    process.exit(1);
}

const s3Client = new S3Client(B2_CONFIG);

const runDbSync = () => {
    console.log('🔄 Запускаю синхронизацию с базой данных (balanced-sync.js)...');
    
    const command = `MONGO_PASSWORD="${process.env.MONGO_PASSWORD}" node scripts/balanced-sync.js`;

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`❌ Ошибка при синхронизации с БД: ${error.message}`);
            return;
        }
        if (stderr) {
            console.error(` stderr при синхронизации: ${stderr}`);
        }
        console.log(`📡 stdout синхронизации:\n${stdout}`);
        console.log('✅ Синхронизация с базой данных завершена.');
    });
};

const uploadFile = async (filePath) => {
    // ИЗМЕНЕНИЕ №1: Создаем ключ для B2, сохраняя структуру папок
    // path.relative создает относительный путь, например: "хиты/2023/трек.mp3"
    // .replace(/\\/g, '/') заменяет бэкслэши (для Windows) на слэши, как принято в S3
    const s3Key = path.relative(WATCH_FOLDER, filePath).replace(/\\/g, '/');

    console.log(`\n⏳ Обнаружен новый файл: ${filePath}. Начинаю загрузку...`);
    console.log(`   -> Ключ в бакете будет: ${s3Key}`);

    try {
        const fileContent = await fs.readFile(filePath);
        const uploadParams = {
            Bucket: BUCKET_NAME,
            Key: s3Key, // Используем новый ключ со структурой папок
            Body: fileContent,
        };

        await s3Client.send(new PutObjectCommand(uploadParams));
        console.log(`✅ Файл "${s3Key}" успешно загружен в бакет "${BUCKET_NAME}".`);

        // Создаем необходимую структуру папок в 'uploaded'
        const newPath = path.join(UPLOADED_FOLDER, s3Key);
        await fs.mkdir(path.dirname(newPath), { recursive: true });
        
        // Перемещаем файл
        await fs.rename(filePath, newPath);
        console.log(`➡️ Файл перемещен в: ${newPath}`);

        runDbSync();

    } catch (err) {
        console.error(`❌ Ошибка при обработке файла "${filePath}":`, err);
    }
};

const startBot = async () => {
    await fs.mkdir(WATCH_FOLDER, { recursive: true });
    await fs.mkdir(UPLOADED_FOLDER, { recursive: true });

    console.log(`🤖 Бот-загрузчик запущен.`);
    console.log(`📂 Слежу за папкой: ${path.resolve(WATCH_FOLDER)} (включая все подпапки)`);

    // ИЗМЕНЕНИЕ №2: Убираем `depth: 0`, чтобы следить за файлами во вложенных папках
    const watcher = chokidar.watch(WATCH_FOLDER, {
        ignored: [/(^|[\/\\])\../, UPLOADED_FOLDER],
        persistent: true,
        ignoreInitial: true,
    });

    watcher.on('add', (filePath) => {
        setTimeout(() => uploadFile(filePath), 1000);
    });

    watcher.on('error', (error) => console.error(`❌ Ошибка воркера: ${error}`));
};

startBot();