// Test client to send data to server
const http = require('http');

const testData = {
    game: "FishIs",
    events: [
        {
            ts: Math.floor(Date.now() / 1000),
            kind: "test_from_nodejs",
            player: "TestPlayer",
            userId: 12345,
            level: 10,
            money: 1000,
            rods: ["Basic Rod"],
            baits: ["Worm"],
            source: "nodejs_test"
        }
    ]
};

const postData = JSON.stringify(testData);

const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/ingest',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
    }
};

console.log('🧪 Testing server with Node.js client...');
console.log('📤 Sending data:', JSON.stringify(testData, null, 2));

const req = http.request(options, (res) => {
    console.log('📊 Status Code:', res.statusCode);
    console.log('📋 Headers:', res.headers);
    
    let responseData = '';
    res.on('data', (chunk) => {
        responseData += chunk;
    });
    
    res.on('end', () => {
        console.log('✅ Response:', responseData);
        
        // Test GET /table
        setTimeout(() => {
            console.log('\n🔍 Testing GET /table...');
            http.get('http://localhost:3000/table', (getRes) => {
                let tableData = '';
                getRes.on('data', (chunk) => tableData += chunk);
                getRes.on('end', () => {
                    console.log('📊 Table response length:', tableData.length, 'characters');
                    if (tableData.includes('TestPlayer')) {
                        console.log('✅ SUCCESS: Data found in table!');
                    } else {
                        console.log('❌ FAIL: Data not found in table');
                    }
                });
            });
        }, 1000);
    });
});

req.on('error', (e) => {
    console.error('❌ Request error:', e.message);
});

req.write(postData);
req.end();
