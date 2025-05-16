// redisClient.js
const { createClient } = require('redis');

const client = createClient({
//   url: 'redis://:123456@localhost:6379', // 没有密码就用 redis://localhost:6379
  url: 'redis://localhost:6379', // 
});

client.on('error', (err) => console.error('❌ Redis Error:', err));

async function connectRedis() {
  if (!client.isOpen) {
    await client.connect();
  }
}

module.exports = { client, connectRedis };
