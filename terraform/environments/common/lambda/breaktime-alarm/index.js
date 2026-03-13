const https = require('https');

exports.handler = async (event) => {
    const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
    const roleId = process.env.DISCORD_ROLE_ID;
    const skipDates = (process.env.SKIP_DATES || '').split(',').filter(d => d);

    // 한국 시간으로 변환
    const now = new Date();
    const kstOffset = 9 * 60 * 60 * 1000;
    const kst = new Date(now.getTime() + kstOffset);

    // 오늘 날짜 확인 (YYYY-MM-DD 형식)
    const todayStr = kst.toISOString().split('T')[0];

    // 스킵 날짜 확인
    if (skipDates.includes(todayStr)) {
        console.log(`Skipping alarm for date: ${todayStr}`);
        return { statusCode: 200, body: 'Skipped' };
    }

    // 현재 시간 (KST)
    const hours = kst.getUTCHours();
    const minutes = kst.getUTCMinutes();

    // 메시지 선택
    let message;
    if (hours === 14 && minutes === 50) {
        message = `<@&${roleId}> ☕ 15시 쉬는시간 10분 전입니다!`;
    } else if (hours === 15 && minutes === 50) {
        message = `<@&${roleId}> 📚 16시 쉬는시간 10분 전입니다!`;
    } else if (hours === 16 && minutes === 50) {
        message = `<@&${roleId}> 🌙 17시 쉬는시간 10분 전입니다!`;
    } else {
        message = `<@&${roleId}> ⏰ 쉬는시간 알림!`;
    }

    // Discord 전송
    const payload = JSON.stringify({ content: message });
    const url = new URL(webhookUrl);

    const options = {
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload)
        }
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            resolve({ statusCode: res.statusCode, body: 'Success' });
        });

        req.on('error', (e) => {
            reject({ statusCode: 500, body: e.message });
        });

        req.write(payload);
        req.end();
    });
};
