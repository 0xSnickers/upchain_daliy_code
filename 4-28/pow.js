/**
 * 实践 POW， 编写程序（编程语言不限）用自己的昵称 + nonce，不断修改nonce 进行 sha256 Hash 运算：
 * 直到满足 4 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。
 * 再次运算直到满足 5 个 0 开头的哈希值，打印出花费的时间、Hash 的内容及Hash值。
 */
const crypto = require('crypto');

class MyPow {
    constructor(nickname) {
        this.nickname = nickname;
    }

    // 计算哈希值
    calculateHash(input) {
        return crypto.createHash('sha256').update(input).digest('hex');
    }

    mine(leadingZeros) {
        let nonce = 0;
        const startTime = Date.now();
        const targetPrefix = '0'.repeat(leadingZeros);

        while (true) {
            const input = `${this.nickname}_${nonce}`;
            const hash = this.calculateHash(input);
            console.log(`Hash= ${hash} | input=${input}`)
            // 检查是否满足条件
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

    // 运行POW测试
    run(leadingZeros = 4) {
        const result = this.mine(leadingZeros);
        this.printResult(result, leadingZeros);
    }

    // 打印结果
    printResult(result, leadingZeros) {
        console.log('----------------------------------------');
        console.log(`leadingZeros: ${leadingZeros}`);
        console.log(`input: ${result.input}`);
        console.log(`Hash: ${result.hash}`);
        console.log(`耗时: ${result.elapsed.toFixed(4)} 秒`);
        console.log(`尝试次数: ${result.attempts}`);
        console.log('----------------------------------------');
    }
}

// 使用示例
const pow = new MyPow("OPENSPACE");
pow.run(5)