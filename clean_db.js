const https = require('https');

const url = 'https://ffddohkyuegzywkepfsk.supabase.co/rest/v1/orders?id=not.eq.00000000-0000-0000-0000-000000000000';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZGRvaGt5dWVnenl3a2VwZnNrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDQyMzIxNSwiZXhwIjoyMDg5OTk5MjE1fQ.O2yEvsPjZEQczC9Xin3iAt1ZLRiTbQXSQ8wrMFlZlw4';

const options = {
  method: 'DELETE',
  headers: {
    'apikey': key,
    'Authorization': 'Bearer ' + key,
    'Content-Type': 'application/json'
  }
};

const req = https.request(url, options, (res) => {
  console.log(`STATUS: ${res.statusCode}`);
  res.on('data', (chunk) => {
    console.log(`BODY: ${chunk}`);
  });
});

req.on('error', (e) => {
  console.error(`ERROR: ${e.message}`);
});

req.end();
