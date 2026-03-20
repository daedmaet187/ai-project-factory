# Pattern: Real-Time Communication

**Problem**: Push real-time updates from server to clients without polling
**Applies to**: All stacks (Node.js/Socket.io backend, React admin, Flutter mobile)
**Last validated**: [Not yet validated — template]

---

## Solution Overview

Two approaches depending on use case:
1. **WebSocket + Redis PubSub** — bidirectional, multiple servers, for notifications and live collaboration
2. **Server-Sent Events (SSE)** — server-to-client only, simpler, for live dashboards and feeds

---

## Approach 1: WebSocket + Redis PubSub

Use when: clients need to send AND receive, or you have multiple backend instances.

### Backend Implementation (Node.js/Express + Socket.io)

```javascript
// src/realtime/socket.js
import { Server } from 'socket.io';
import { createClient } from 'redis';
import { createAdapter } from '@socket.io/redis-adapter';

export async function setupSocketIO(httpServer) {
  const pubClient = createClient({ url: process.env.REDIS_URL });
  const subClient = pubClient.duplicate();

  await Promise.all([pubClient.connect(), subClient.connect()]);

  const io = new Server(httpServer, {
    cors: {
      origin: process.env.ADMIN_URL,
      credentials: true,
    },
  });

  // Use Redis adapter for multi-instance support
  io.adapter(createAdapter(pubClient, subClient));

  // Auth middleware
  io.use(async (socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) return next(new Error('Authentication required'));

    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = payload.sub;
      socket.userRole = payload.role;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    // Join user-specific room
    socket.join(`user:${socket.userId}`);

    socket.on('disconnect', () => {
      // Cleanup handled automatically by Socket.io
    });
  });

  return io;
}

// Emit to a specific user from anywhere in the app
export function notifyUser(io, userId, event, data) {
  io.to(`user:${userId}`).emit(event, data);
}
```

### Flutter Implementation

```dart
// lib/core/realtime/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;

  Future<void> connect(String accessToken) async {
    _socket = IO.io(
      Env.apiUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
    });

    _socket!.on('notification', (data) {
      _notificationController.add(data as Map<String, dynamic>);
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    _notificationController.close();
    disconnect();
  }
}
```

---

## Approach 2: Server-Sent Events (SSE)

Use when: server-to-client only, simpler setup, no multi-instance concerns.

### Backend Implementation

```javascript
// src/routes/events.js
router.get('/events', requireAuth, (req, res) => {
  // SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  // Register client
  const clientId = req.user.id;
  sseClients.set(clientId, res);

  // Send initial heartbeat
  res.write('data: {"type":"connected"}\n\n');

  // Cleanup on disconnect
  req.on('close', () => {
    sseClients.delete(clientId);
  });
});

// Send event to specific user
export function sendSSE(userId, event, data) {
  const client = sseClients.get(userId);
  if (client) {
    client.write(`data: ${JSON.stringify({ type: event, ...data })}\n\n`);
  }
}
```

### React Implementation

```typescript
// src/hooks/useServerEvents.ts
import { useEffect, useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';

export function useServerEvents() {
  const queryClient = useQueryClient();
  const eventSourceRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const token = getAccessToken();
    const url = `${import.meta.env.VITE_API_URL}/api/events`;

    eventSourceRef.current = new EventSource(url, {
      withCredentials: true,
    });

    eventSourceRef.current.onmessage = (event) => {
      const data = JSON.parse(event.data);

      // Invalidate relevant queries based on event type
      switch (data.type) {
        case 'order_updated':
          queryClient.invalidateQueries({ queryKey: ['orders'] });
          break;
        case 'user_joined':
          queryClient.invalidateQueries({ queryKey: ['users'] });
          break;
      }
    };

    eventSourceRef.current.onerror = () => {
      // EventSource auto-reconnects on error
      console.warn('SSE connection error, retrying...');
    };

    return () => {
      eventSourceRef.current?.close();
    };
  }, [queryClient]);
}
```

---

## Gotchas

1. **WebSocket doesn't work behind some proxies without sticky sessions** — use Redis adapter to handle multiple instances
2. **SSE has a 6-connection limit per domain in HTTP/1.1** — use HTTP/2 or WebSocket for multiple tabs
3. **Always authenticate WebSocket connections** — in the handshake, not after connect
4. **Heartbeat to detect stale connections** — send a ping every 30s
5. **Flutter SSE requires a streaming HTTP client** — use `http` package's `Client.send()` not `get()`

---

## See Also

- `stacks/backend/nodejs-express.md` — Socket.io setup
- `brain/patterns/background-jobs.md` — For async job status updates via SSE
