#!/usr/bin/env bash
set -euo pipefail

# Run from the Flutter application's root directory. Match the FTP workflow SDK.
flutter_version=3.47.7
sdk_dir="$(mktemp -d)/flutter"
git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$sdk_dir"
export PATH="$sdk_dir/bin:$PATH"
export CI=true
flutter config --no-analytics

# These are the existing frontend-safe defaults from the FTP workflow.
# Vercel environment variables can select a different Supabase project.
backend_url="${SUPABASE_URL:-https://ksrverpyybrwpoocbvqx.supabase.co}"
backend_key="${SUPABASE_PUBLISHABLE_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcnZlcnB5eWJyd3Bvb2NidnF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NzIxODUsImV4cCI6MjA5OTA0ODE4NX0.cJkIjJyDpm8pouZI83WCF-bDggKSAqGvnHAmht3wO5E}"
commit_sha="${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse HEAD)}"

flutter pub get
flutter build web --release --base-href / --pwa-strategy=none \
  --dart-define=BITCLASS_ENV=production \
  --dart-define="SUPABASE_URL=$backend_url" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$backend_key" \
  --dart-define="GIT_SHA=$commit_sha"
