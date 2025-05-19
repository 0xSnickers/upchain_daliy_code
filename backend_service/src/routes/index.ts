import { getStorageAt } from '../services/blockchain'
import { cacheUserPermit, getCachedUserPermit, delCachedUserPermit } from '../services/cache'
import { Request, Response, Router } from 'express'

const router = Router()
// ========================获取合约 slot (LockInfo[] _locks) 数据========================

router.get('/getStorageAt/:address', async (req: any, res: any) => {
    const address = req.params.address as `0x${string}`
    // const { slot } = req.query;
    // 类型断言并转换为 number
    const slot = parseInt(req.query.slot as string, 10);
    const data = await getStorageAt(address, slot)
    res.json({ code: 0, message: 'success', data: data });
})



// ========================离线签名派发NFT白名单========================
router.post('/userPermit', async (req: any, res: any) => {
    const { address, signature, tokenId, deadline } = req.body;
    if (!address || !signature) return res.status(400).json({ error: 'Missing address' });

    await cacheUserPermit(`user:${address}`, JSON.stringify({ signature, tokenId, deadline }));
    res.json({ code: 0, message: 'success' });
});

router.get('/userPermit/:address', async (req: any, res: any) => {
    const data = await getCachedUserPermit(`user:${req.params.address}`);
    let result = { code: 0, message: 'success', data: {} };
    if (data) {
        result.data = JSON.parse(data);
    }

    res.json(result);
});

router.delete('/userPermit/:address', async (req: any, res: any) => {
    const result = await delCachedUserPermit(`user:${req.params.address}`);
    if (result === 0) return res.status(404).json({ error: 'User not found' });

    res.json({ code: 0, message: 'success' });
});


export default router
