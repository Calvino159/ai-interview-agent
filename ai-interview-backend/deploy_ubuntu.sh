#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "== AI Interview backend deploy =="

if [ ! -f ".env" ]; then
  echo "Missing .env, copying from .env.example"
  cp .env.example .env
fi

if grep -Eq "sk-your-deepseek-key|sk-your-dashscope-key|your-deepseek-api-key" .env; then
  echo "WARNING: .env still contains placeholder AI keys."
  echo "The backend can start, but resume parsing, RAG vectorization, AI scoring, and reports need real keys."
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing docker.io"
  sudo apt-get update
  sudo apt-get install -y docker.io
fi

if ! sudo docker info >/dev/null 2>&1; then
  echo "Starting Docker daemon"
  if command -v systemctl >/dev/null 2>&1 && [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
    sudo systemctl enable --now docker
  elif command -v service >/dev/null 2>&1; then
    sudo service docker start
  else
    echo "Could not start Docker automatically. Start Docker in Ubuntu, then rerun this script."
    exit 1
  fi
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  if [ -f "./docker-compose-linux-x86_64" ]; then
    echo "Installing bundled Docker Compose v2 binary"
    sudo cp ./docker-compose-linux-x86_64 /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  elif docker compose version >/dev/null 2>&1; then
    echo "Using docker compose plugin"
  else
    echo "docker-compose is missing and bundled docker-compose-linux-x86_64 was not found."
    exit 1
  fi
fi

if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(sudo docker-compose)
else
  COMPOSE=(sudo docker compose)
fi

echo "Starting containers"
"${COMPOSE[@]}" -f docker-compose.yml -f docker-compose.dev.yml up -d --build

echo "Container status"
"${COMPOSE[@]}" -f docker-compose.yml -f docker-compose.dev.yml ps

echo "Running migrations"
sudo docker exec ai-interview-app alembic upgrade head

echo "Creating default admin if needed"
sudo docker exec ai-interview-app python scripts/create_first_admin.py || true

echo "Seeding position templates"
sudo docker exec ai-interview-app python scripts/seed_position_templates.py

echo "Checking pgvector"
sudo docker exec ai-interview-postgres psql -U demo -d ai_interview -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"

echo "Health check"
curl -fsS http://localhost:8006/api/v1/config/health
echo
echo "Backend is ready on port 8006."
