/**
 * 实践非对称加密 RSA（编程语言不限）：
 * 先生成一个公私钥对, 用私钥对符合 POW 4 个 0 开头的哈希值的 “昵称 + nonce” 进行私钥签名用公钥验证
 */
const crypto = require('crypto');

class MyRsa {
    constructor(nickname) {
        this.nickname = nickname;
        this.keyPair = null;
    }

    // 1. 生成RSA密钥对
    generateKeyPair() {
        this.keyPair = crypto.generateKeyPairSync('rsa', {
            modulusLength: 2048, // 密钥长度
            publicKeyEncoding: {
                type: 'spki', // 推荐的公钥格式
                format: 'pem'
            },
            privateKeyEncoding: {
                type: 'pkcs8', // 推荐的私钥格式
                format: 'pem',
                // cipher: 'aes-256-cbc', // 可选: 用密码保护私钥
                // passphrase: 'top-secret' // 可选: 密码
            }
        });


        console.log('RSA密钥对已生成并保存');
    }

    // 计算SHA-256哈希
    calculateHash(input) {
        return crypto.createHash('sha256').update(input).digest('hex');
    }

    // 执行工作量证明(POW)
    mine(leadingZeros) {
        let nonce = 0;
        const startTime = Date.now();
        const targetPrefix = '0'.repeat(leadingZeros);

        while (true) {
            const input = `${this.nickname}_${nonce}`;
            const hash = this.calculateHash(input);
            console.log(`Hash= ${hash} | input=${input}`)

            if (hash.startsWith(targetPrefix)) {
                const elapsed = (Date.now() - startTime) / 1000;
                return {
                    input,
                    hash,
                    elapsed,
                    attempts: nonce + 1
                };
            }
            nonce++;
        }
    }

    // 使用私钥签名
    signData(data, privateKey) {
        const sign = crypto.createSign('SHA256');
        sign.update(data);
        sign.end();
        return sign.sign(privateKey, 'base64'); // 返回Base64编码的签名
    }

    // 使用公钥验证签名
    verifySignature(data, signature, publicKey) {
        const verify = crypto.createVerify('SHA256');
        verify.update(data);
        verify.end();
        return verify.verify(publicKey, signature, 'base64');
    }

    printPowResult(result, leadingZeros) {
        console.log('----------------------------------------');
        console.log(`leadingZeros: ${leadingZeros}`);
        console.log(`input: ${result.input}`);
        console.log(`Hash: ${result.hash}`);
        console.log(`耗时: ${result.elapsed.toFixed(4)} 秒`);
        console.log(`尝试次数: ${result.attempts}`);
        console.log('----------------------------------------');
    }

    // 运行完整流程
    run() {
        // 1. 生成密钥对
        this.generateKeyPair();

        // 2. 执行POW寻找4个0开头的哈希
        const powResult = this.mine(4);
        this.printPowResult(powResult, 4);
        // 3. 使用私钥对"昵称+nonce"签名
        const signature = this.signData(powResult.input, this.keyPair.privateKey);
        console.log(`生成签名(Base64):\n${signature}`);
        console.log('----------------------------------------');
        // 4. 使用公钥验证签名
        const isValid = this.verifySignature(powResult.input, signature, this.keyPair.publicKey);
        console.log(`签名验证结果: ${isValid ? '✅ 有效' : '❌ 无效'}`);
        console.log('----------------------------------------');
        // 5. 测试篡改数据后的验证
        const tamperedData = powResult.input + '_test_error';
        const isTamperedValid = this.verifySignature(tamperedData, signature, this.keyPair.publicKey);
        console.log(`篡改数据验证: ${isTamperedValid ? '✅ 有效' : '❌ 无效'}`);

    }
}

// 使用示例
const rsaPow = new MyRsa("OPENSPACE");
rsaPow.run();