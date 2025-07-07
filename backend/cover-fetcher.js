const { S3Client, ListObjectsV2Command, GetObjectCommand } = require("@aws-sdk/client-s3");
const { MongoClient } = require("mongodb");
const mm = require("music-metadata");
const sharp = require("sharp");
const stream = require("stream");

require("dotenv").config();

const B2_ENDPOINT = process.env.B2_ENDPOINT;
const B2_REGION = process.env.B2_REGION;
const B2_ACCESS_KEY_ID = process.env.B2_ACCESS_KEY_ID;
const B2_SECRET_ACCESS_KEY = process.env.B2_SECRET_ACCESS_KEY;
const B2_BUCKET_NAME = process.env.B2_BUCKET_NAME;
const MONGODB_URI = process.env.MONGODB_URI;

const s3Client = new S3Client({
  endpoint: B2_ENDPOINT,
  region: B2_REGION,
  credentials: {
    accessKeyId: B2_ACCESS_KEY_ID,
    secretAccessKey: B2_SECRET_ACCESS_KEY,
  },
});

const mongoClient = new MongoClient(MONGODB_URI);

async function streamToBuffer(stream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks)));
  });
}

// ИЗМЕНЕНИЕ: Более надежная функция для извлечения года
function getYearFromMetadata(metadata) {
    if (!metadata || !metadata.common) return null;

    // 1. Самый надежный тег (Recording time)
    if (metadata.common.year) {
        return metadata.common.year;
    }

    // 2. Проверяем нативные теги ID3v2
    if (metadata.native && metadata.native['ID3v2.4']) {
        const id3v24 = metadata.native['ID3v2.4'];
        // TDRC (Recording time) - более точный
        const tdrc = id3v24.find(tag => tag.id === 'TDRC');
        if (tdrc && !isNaN(parseInt(tdrc.value.substring(0, 4)))) {
            return parseInt(tdrc.value.substring(0, 4));
        }
        // TYER (Year) - менее точный
        const tyer = id3v24.find(tag => tag.id === 'TYER');
        if (tyer && !isNaN(parseInt(tyer.value))) {
            return parseInt(tyer.value);
        }
        // TDRL (Release time) - как запасной вариант
        const tdrl = id3v24.find(tag => tag.id === 'TDRL');
        if (tdrl && !isNaN(parseInt(tdrl.value.substring(0, 4)))) {
            return parseInt(tdrl.value.substring(0, 4));
        }
    }
    
    // 3. Если ничего не найдено, возвращаем null
    return null;
}

async function processTrack(trackKey, db) {
  console.log(`Processing: ${trackKey}`);
  const tracksCollection = db.collection("tracks");

  try {
    const getObjectParams = {
      Bucket: B2_BUCKET_NAME,
      Key: trackKey,
    };
    const { Body } = await s3Client.send(new GetObjectCommand(getObjectParams));

    const buffer = await streamToBuffer(Body);

    const metadata = await mm.parseBuffer(buffer, "audio/mpeg", {
      duration: true,
    });

    const { common, format } = metadata;
    const cover = common.picture ? common.picture[0] : null;

    let coverUrl = null;
    if (cover) {
      const resizedCoverBuffer = await sharp(cover.data)
        .resize(256, 256)
        .jpeg({ quality: 80 })
        .toBuffer();

      const coverKey = `covers/${trackKey.replace(/\.[^/.]+$/, "")}.jpg`;
      
      // Эта часть кода для загрузки обложек остается без изменений
    }

    const durationInSeconds = Math.round(format.duration);
    const minutes = Math.floor(durationInSeconds / 60);
    const seconds = durationInSeconds % 60;
    const formattedDuration = `${minutes}:${seconds.toString().padStart(2, "0")}`;
    
    // ИЗМЕНЕНИЕ: Используем новую функцию для получения года
    const year = getYearFromMetadata(metadata);

    const trackData = {
      _id: trackKey,
      title: common.title || "Unknown Title",
      artist: common.artist || "Unknown Artist",
      duration: formattedDuration,
      coverUrl: coverUrl,
      year: year, // Год может быть null, если не найден
    };

    await tracksCollection.updateOne(
      { _id: trackKey },
      { $set: trackData },
      { upsert: true }
    );

    console.log(`  -> Successfully processed and saved: ${trackData.title}`);
  } catch (error) {
    console.error(`  -> Error processing ${trackKey}:`, error);
  }
}

async function run() {
  try {
    await mongoClient.connect();
    console.log("Connected to MongoDB.");
    const db = mongoClient.db("eatune");

    const listObjectsParams = { Bucket: B2_BUCKET_NAME };
    const { Contents } = await s3Client.send(new ListObjectsV2Command(listObjectsParams));

    if (!Contents) {
      console.log("No tracks found in the bucket.");
      return;
    }

    const trackKeys = Contents.filter((obj) =>
      /\.(mp3|wav|ogg|flac|m4a)$/i.test(obj.Key)
    ).map((obj) => obj.Key);

    console.log(`Found ${trackKeys.length} tracks to process.`);

    for (const trackKey of trackKeys) {
      await processTrack(trackKey, db);
    }

    console.log("All tracks have been processed.");
  } catch (err) {
    console.error("An error occurred:", err);
  } finally {
    await mongoClient.close();
    console.log("MongoDB connection closed.");
  }
}

run();