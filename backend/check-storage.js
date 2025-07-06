const { S3Client, ListObjectVersionsCommand } = require('@aws-sdk/client-s3');

// --- КОНФИГУРАЦИЯ ---
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
if (!B2_CONFIG.credentials.accessKeyId || !B2_CONFIG.credentials.secretAccessKey) {
    console.error('❌ Ошибка: Ключи доступа Backblaze B2 не предоставлены.');
    console.error('Пожалуйста, запустите скрипт с переменными окружения:');
    console.error('B2_ACCESS_KEY_ID="ВАШ_КЛЮЧ" B2_SECRET_ACCESS_KEY="ВАШ_СЕКРЕТ" node check-storage.js');
    process.exit(1);
}

const s3Client = new S3Client(B2_CONFIG);

function formatBytes(bytes, decimals = 2) {
    if (!+bytes) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}

const checkStorage = async () => {
    console.log(`🔎 Проверяю хранилище в бакете "${BUCKET_NAME}" (включая все версии файлов)...`);
    let totalSizeBytes = 0;
    let totalObjects = 0; // Включая все версии и маркеры удаления
    let keyMarker;
    let versionIdMarker;
    let isTruncated = true;

    try {
        while (isTruncated) {
            const params = {
                Bucket: BUCKET_NAME,
                KeyMarker: keyMarker,
                VersionIdMarker: versionIdMarker,
            };
            
            // ИЗМЕНЕНИЕ: Используем команду ListObjectVersionsCommand
            const response = await s3Client.send(new ListObjectVersionsCommand(params));
            
            // Считаем размеры всех версий файлов
            if (response.Versions) {
                for (const item of response.Versions) {
                    totalSizeBytes += item.Size;
                    totalObjects++;
                }
            }
            // Маркеры удаления тоже являются объектами, но их размер 0
            if (response.DeleteMarkers) {
                totalObjects += response.DeleteMarkers.length;
            }
            
            isTruncated = response.IsTruncated;
            keyMarker = response.NextKeyMarker;
            versionIdMarker = response.NextVersionIdMarker;
        }

        console.log('\n--- 📊 Полный отчет по хранилищу (все версии) ---');
        console.log(`📁 Всего объектов (версий и маркеров): ${totalObjects}`);
        console.log(`💾 Общий размер: ${formatBytes(totalSizeBytes)}`);
        console.log(`   - в мегабайтах: ${(totalSizeBytes / 1024 / 1024).toFixed(2)} MB`);
        console.log(`   - в гигабайтах: ${(totalSizeBytes / 1024 / 1024 / 1024).toFixed(3)} GB`);
        console.log('--------------------------------------------------\n');
        console.log('💡 Совет: Чтобы избежать накопления старых версий, настройте Lifecycle Rules в панели управления бакетом на сайте Backblaze.');


    } catch (err) {
        console.error("❌ Не удалось получить информацию о хранилище:", err);
    }
};

checkStorage();