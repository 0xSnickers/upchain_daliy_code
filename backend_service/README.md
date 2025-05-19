


```bash
├── src/
│   ├── server.ts                # Entry file
│   ├── routes/
│   │   └── index.ts             # API Route
│   ├── services/
│   │   ├── blockchain.ts        # Viem Logic
│   │   └── cache.ts             # Redis Logic
│   ├── clients/
│   │   ├── viemClient.ts        # Viem Client
│   │   └── redisClient.ts       # Redis Instance
├── .env                         
├── tsconfig.json
├── package.json
└── README.md
```





---

> ioredis ：
>
> **支持 Redis Cluster / Sentinel 模式**
>
> **支持高级特性**（Pub/Sub、Pipeline、Lua 脚本等）
>
> 自动重连、连接池、错误处理机制完善
>
> 内部使用 `EventEmitter`，易于集成复杂系统

![描述](https://github.com/0xSnickers/upchain_daliy_code/tree/main/backend_service/assets/01.jpg)