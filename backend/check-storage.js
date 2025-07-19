const { S3Client, ListObjectVersionsCommand } = require('@aws-sdk/client-s3');

// --- КОНФИГУРАЦИЯ ---
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

if (!R2_CONFIG.credentials.accessKeyId || !R2_CONFIG.credentials.secretAccessKey) {
    console.error('❌ Ошибка: Ключи доступа R2 не предоставлены.');
    process.exit(1);
}

const s3Client = new S3Client(R2_CONFIG);

function formatBytes(bytes, decimals = 2) {
    if (!+bytes) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}

const checkStorage = async () => {
    // ... (остальной код файла остается без изменений)
};

checkStorage();