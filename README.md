# Docker Network Segmentation

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python_3.12-3776AB?style=flat&logo=python&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL_16-4169E1?style=flat&logo=postgresql&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

Multi-tier service isolation using Docker bridge networks, built without Compose.

![Stage 1 network topology](docs/images/stage1-architecture.png)

---

## Architecture

Three containers across two isolated bridge networks. nginx is the single host-facing entry point. postgres_db is unreachable from nginx by design. Only flask_api, which bridges both networks, can connect to it.

| Container | Network(s) | Port |
|---|---|---|
| nginx | frontend_net | 80:80 (host) |
| flask_api | frontend_net, backend_net | internal only |
| postgres_db | backend_net | internal only |

See [docs/architecture.md](docs/architecture.md) for design decisions.

---

## Quick start

**Prerequisites:** Docker Desktop with WSL 2 integration enabled.

```bash
# Build the API image
docker build -t flask_api ./services/api

# Create networks
docker network create frontend_net
docker network create backend_net

# Start containers
docker run -d --name postgres_db --network backend_net \
  -e POSTGRES_DB=appdb -e POSTGRES_USER=appuser -e POSTGRES_PASSWORD=secret \
  postgres:16-alpine

docker run -d --name flask_api --network backend_net \
  -e DB_HOST=postgres_db -e DB_NAME=appdb \
  -e DB_USER=appuser -e DB_PASSWORD=secret \
  flask_api

docker network connect frontend_net flask_api

docker run -d --name nginx --network frontend_net -p 80:80 \
  -v $(pwd)/services/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine
```

---

## Verify

```bash
curl http://localhost/api/health        # {"status":"ok"}
curl http://localhost/api/data          # PostgreSQL version returned

docker exec nginx ping -c 2 postgres_db # bad address, isolation confirmed
```

See [docs/verification.md](docs/verification.md) for full verification output and screenshots.

---

## Project structure

```
docker-network-segmentation/
├── services/
│   ├── api/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── nginx/
│       └── nginx.conf
├── scripts/
│   └── verify.sh
├── docs/
│   ├── images/
│   ├── architecture.md
│   └── verification.md
└── README.md
```

---

