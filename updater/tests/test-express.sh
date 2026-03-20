#!/bin/bash
# Regression test for Express stack pattern
# Verifies the documented pattern in stacks/backend/nodejs-express.md still works

set -e

echo "=== Express Stack Regression Test ==="

# Create temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
echo "Working in $TMPDIR"

# Initialize minimal Express app using documented pattern
cat > package.json << 'EOF'
{
  "name": "express-test",
  "type": "module",
  "scripts": {
    "start": "node src/index.js"
  },
  "dependencies": {
    "express": "^5.0.0",
    "helmet": "^8.0.0",
    "cors": "^2.8.5",
    "zod": "^3.23.0"
  }
}
EOF

mkdir -p src

cat > src/index.js << 'EOF'
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Install dependencies
echo "Installing dependencies..."
npm install --silent

# Start server in background
echo "Starting server..."
npm start &
SERVER_PID=$!
sleep 3

# Test health endpoint
echo "Testing /health endpoint..."
RESPONSE=$(curl -s http://localhost:3000/health)
EXPECTED='{"status":"ok"}'

if [ "$RESPONSE" = "$EXPECTED" ]; then
  echo "✅ Health check passed"
  RESULT=0
else
  echo "❌ Health check failed"
  echo "Expected: $EXPECTED"
  echo "Got: $RESPONSE"
  RESULT=1
fi

# Cleanup
kill $SERVER_PID 2>/dev/null || true
cd /
rm -rf "$TMPDIR"

exit $RESULT
