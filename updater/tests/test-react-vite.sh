#!/bin/bash
# Regression test for React/Vite stack pattern
# Verifies the documented pattern in stacks/frontend/react-shadcn.md still works

set -e

echo "=== React/Vite Stack Regression Test ==="

# Create temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
echo "Working in $TMPDIR"

# Create minimal Vite + React app
cat > package.json << 'EOF'
{
  "name": "react-test",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "vite build",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.6.0",
    "vite": "^6.0.0"
  }
}
EOF

cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
})
EOF

cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true
  },
  "include": ["src"]
}
EOF

mkdir -p src

cat > src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'

function App() {
  return <h1>Test</h1>
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Test</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# Install dependencies
echo "Installing dependencies..."
npm install --silent

# Type check
echo "Running TypeScript check..."
if npm run typecheck; then
  echo "✅ TypeScript passed"
else
  echo "❌ TypeScript failed"
  cd /
  rm -rf "$TMPDIR"
  exit 1
fi

# Build
echo "Running build..."
if npm run build --silent; then
  echo "✅ Build passed"
  RESULT=0
else
  echo "❌ Build failed"
  RESULT=1
fi

# Cleanup
cd /
rm -rf "$TMPDIR"

exit $RESULT
