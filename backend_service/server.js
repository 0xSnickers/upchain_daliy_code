// server.js
const express = require('express');
const bodyParser = require('body-parser');
const { client: redis_client, connectRedis } = require('./redisClient');
const cors = require('cors');
const app = express();
const PORT = 9000;

app.use(bodyParser.json());
app.use(cors());
app.post('/user', async (req, res) => {
  const { address, signature, tokenId, deadline } = req.body;
  if (!address || !signature) return res.status(400).json({ error: 'Missing address' });

  await redis_client.set(`user:${address}`, JSON.stringify({ signature, tokenId, deadline }));
  res.json({ code:0, message: 'success' });
});

app.get('/user/:address', async (req, res) => {
  const data = await redis_client.get(`user:${req.params.address}`);
  let result = { code:0, message: 'success',data:{} };
  if (data) {
    result.data = JSON.parse(data);
  }

  res.json(result);
});

app.delete('/user/:address', async (req, res) => {
  const result = await redis_client.del(`user:${req.params.address}`);
  if (result === 0) return res.status(404).json({ error: 'User not found' });

  res.json({ code:0, message: 'success' });
});

app.listen(PORT, async () => {
  await connectRedis();
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});
