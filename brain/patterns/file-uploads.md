# Pattern: File Uploads

**Problem**: Secure file uploads to S3 with validation, size limits, and progress tracking
**Applies to**: All stacks with S3 backend
**Last validated**: [Not yet validated — template]

---

## Solution Overview

1. Client requests presigned URL from backend
2. Backend validates request, generates presigned PUT URL with size/type restrictions
3. Client uploads directly to S3 (bypasses backend for large files)
4. Backend receives S3 event notification (optional) or client confirms upload
5. Backend stores file reference in database

---

## Backend Implementation (Node.js/Express)

### Presigned URL Generation

```javascript
// src/routes/uploads.js
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

const s3 = new S3Client({ region: process.env.AWS_REGION });
const BUCKET = process.env.S3_BUCKET;

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
const MAX_SIZE = 10 * 1024 * 1024; // 10MB

router.post('/upload-url', requireAuth, async (req, res) => {
  const { filename, contentType, size } = req.body;

  // Validate
  if (!ALLOWED_TYPES.includes(contentType)) {
    return res.status(400).json({ error: 'File type not allowed' });
  }
  if (size > MAX_SIZE) {
    return res.status(400).json({ error: 'File too large (max 10MB)' });
  }

  // Generate unique key
  const ext = filename.split('.').pop();
  const key = `uploads/${req.user.id}/${randomUUID()}.${ext}`;

  // Generate presigned URL (valid 5 minutes)
  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ContentType: contentType,
    ContentLength: size,
  });

  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

  res.json({
    uploadUrl,
    key,
    publicUrl: `https://${BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`,
  });
});
```

---

## Flutter Implementation

### Upload with Progress

```dart
// lib/services/upload_service.dart
import 'dart:io';
import 'package:dio/dio.dart';

class UploadService {
  final Dio _dio;

  UploadService(this._dio);

  Future<String> uploadFile(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final filename = file.path.split('/').last;
    final size = await file.length();
    final contentType = _getContentType(filename);

    // 1. Get presigned URL
    final urlResponse = await _dio.post('/api/upload-url', data: {
      'filename': filename,
      'contentType': contentType,
      'size': size,
    });

    final uploadUrl = urlResponse.data['uploadUrl'];
    final publicUrl = urlResponse.data['publicUrl'];

    // 2. Upload directly to S3
    await Dio().put(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': size,
        },
      ),
      onSendProgress: onProgress,
    );

    return publicUrl;
  }

  String _getContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
```

---

## React Implementation

### Drag-Drop Upload Component

```typescript
// src/components/FileUpload.tsx
import { useCallback, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { api } from '@/lib/api';

interface FileUploadProps {
  onUploadComplete: (url: string) => void;
  accept?: Record<string, string[]>;
  maxSize?: number;
}

export function FileUpload({
  onUploadComplete,
  accept = { 'image/*': ['.jpg', '.jpeg', '.png', '.webp'] },
  maxSize = 10 * 1024 * 1024,
}: FileUploadProps) {
  const [progress, setProgress] = useState(0);
  const [isUploading, setIsUploading] = useState(false);

  const onDrop = useCallback(async (files: File[]) => {
    const file = files[0];
    if (!file) return;

    setIsUploading(true);
    setProgress(0);

    try {
      // 1. Get presigned URL
      const { data } = await api.post('/api/upload-url', {
        filename: file.name,
        contentType: file.type,
        size: file.size,
      });

      // 2. Upload to S3
      await fetch(data.uploadUrl, {
        method: 'PUT',
        body: file,
        headers: { 'Content-Type': file.type },
      });

      setProgress(100);
      onUploadComplete(data.publicUrl);
    } catch (err) {
      console.error('Upload failed:', err);
    } finally {
      setIsUploading(false);
    }
  }, [onUploadComplete]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept,
    maxSize,
    multiple: false,
  });

  return (
    <div
      {...getRootProps()}
      className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer
        ${isDragActive ? 'border-primary bg-primary/5' : 'border-muted-foreground/25'}
        ${isUploading ? 'pointer-events-none opacity-50' : ''}`}
    >
      <input {...getInputProps()} />
      {isUploading ? (
        <p>Uploading... {progress}%</p>
      ) : isDragActive ? (
        <p>Drop the file here</p>
      ) : (
        <p>Drag & drop a file, or click to select</p>
      )}
    </div>
  );
}
```

---

## Infrastructure (OpenTofu)

### S3 Bucket with CORS

```hcl
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-${var.environment}-uploads"
  tags   = var.common_tags
}

resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = var.allowed_origins  # ["https://admin.example.com"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "uploads_public_read" {
  bucket = aws_s3_bucket.uploads.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.uploads.arn}/uploads/*"
    }]
  })
}
```

---

## Gotchas

1. **CORS must be configured on S3** — client uploads will fail without it
2. **Presigned URLs expire** — 5 minutes is enough; don't make them too long
3. **Validate content type server-side** — clients can lie about file type
4. **Size limits in presigned URL** — S3 enforces ContentLength if specified
5. **Don't store files in your API server** — always use S3 or equivalent object storage

---

## See Also

- `stacks/infra/aws-ecs-fargate.md` — S3 bucket setup
- `security/CHECKLIST.md` — File upload security
