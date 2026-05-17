# Docker Network Segmentation

![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python_3.12-3776AB?style=flat&logo=python&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL_16-4169E1?style=flat&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis_7-DC382D?style=flat&logo=redis&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

Multi-tier service isolation using Docker bridge networks, built without Compose.

![Stage 2 network topology](docs/images/stage2-architecture.svg)

---

## Architecture

Five containers across two isolated bridge networks, a none network, and a host network exercise. nginx is the single host-facing entry point. postgres_db and redis_cache are unreachable from nginx. Only flask_api, which bridges both networks, can reach backend services.

| Container | Network | IP |
|---|---|---|
| nginx | frontend_net | 172.30.0.10 |
| flask_api | frontend_net, backend_net | 172.30.0.20, 172.31.0.20 |
| postgres_db | backend_net | 172.31.0.10 |
| redis_cache | backend_net | 172.31.0.11 |
| admin_probe | none | loopback only |

See [docs/architecture.md](docs/architecture.md) for design decisions.

---

## Quick start

**Prerequisites:** Docker Desktop with WSL 2 integration enabled.

```bash
# Build the API image
docker build -t flask_api ./services/api

# Create networks with custom CIDRs
docker network create --driver bridge --subnet 172.30.0.0/24 --gateway 172.30.0.1 frontend_net
docker network create --driver bridge --subnet 172.31.0.0/24 --gateway 172.31.0.1 backend_net

# Start containers
docker run -d --name postgres_db --network backend_net --ip 172.31.0.10 \
  -e POSTGRES_DB=appdb -e POSTGRES_USER=appuser -e POSTGRES_PASSWORD=secret \
  postgres:16-alpine

docker run -d --name redis_cache --network backend_net --ip 172.31.0.11 \
  redis:7-alpine

docker run -d --name flask_api --network backend_net --ip 172.31.0.20 \
  -e DB_HOST=postgres_db -e DB_NAME=appdb \
  -e DB_USER=appuser -e DB_PASSWORD=secret \
  flask_api

docker network connect --ip 172.30.0.20 frontend_net flask_api

docker run -d --name nginx --network frontend_net --ip 172.30.0.10 -p 80:80 \
  -v $(pwd)/services/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine

docker run -d --name admin_probe --network none alpine sleep infinity
```

---

## Verify

```bash
./scripts/verify.sh stage2
```

See [docs/verification.md](docs/verification.md) for full output and screenshots.

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
