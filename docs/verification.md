# Verification

## Stage 1: Baseline (Nginx, Flask API, PostgreSQL)

Stage 1 establishes a three-tier architecture across two isolated bridge networks. nginx is the only container with an exposed host port. postgres_db is unreachable from nginx. Only flask_api, which bridges both networks, can connect to it.

---

### 1. All three containers running

![All three containers running in Docker Desktop](images/stage1-containers-running.png)

Docker Desktop showing `postgres_db`, `flask_api`, and `nginx` all running simultaneously. nginx has port 80:80 mapped to the host, the only exposed port in the stack.

---

### 2. Networks created

![docker network ls output showing frontend_net and backend_net](images/stage1-networks-created.png)

`docker network ls` confirming both `frontend_net` and `backend_net` exist as bridge networks with local scope. Also visible: the `none` and `host` networks used in Stage 2.

---

### 3. Verification terminal output

![Terminal showing all four verification commands and their results](images/stage1-verification-terminal.png)

All four verification commands in a single frame:

- `curl http://localhost/api/health` returns `{"status":"ok"}`, nginx is proxying to flask_api
- `curl http://localhost/api/data` returns the PostgreSQL 16.14 version string, full stack query working
- `docker exec nginx ping -c 2 postgres_db` returns `bad address 'postgres_db'`, network isolation confirmed
- `docker exec flask_api python -c "..."` prints `flask_api connected to postgres_db`, flask_api has a valid route via backend_net

---

### 4. API health endpoint in browser

![Browser showing http://localhost/api/health returning status ok](images/stage1-api-health-browser.png)

`http://localhost/api/health` returning `{"status":"ok"}` in the browser. Confirms the full request path: browser to host port 80 to nginx to flask_api to response.

---

### 5. API data endpoint in browser

![Browser showing http://localhost/api/data returning PostgreSQL version](images/stage1-api-data-browser.png)

`http://localhost/api/data` returning the live PostgreSQL 16.14 version string. Confirms the complete end-to-end chain: browser to nginx to flask_api to postgres_db to response.

---

### 6. Automated verification script

![verify.sh passing all Stage 1 checks](images/stage1-verify-script.png)

`./scripts/verify.sh stage1` passing all 7 checks. Confirms the full stack, API endpoints, network isolation, and database connectivity in a single repeatable run.


### Summary

| Test | Command | Expected | Result |
|---|---|---|---|
| Health check | `curl /api/health` | `{"status":"ok"}` | ✅ Pass |
| DB query | `curl /api/data` | PostgreSQL version | ✅ Pass |
| Isolation: nginx blocked | `docker exec nginx ping postgres_db` | `bad address` | ✅ Pass |
| Isolation: flask_api allowed | `python psycopg2.connect(...)` | connected | ✅ Pass |
