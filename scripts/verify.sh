#!/bin/bash

# =============================================================================
# verify.sh — Docker Network Segmentation
# Runs all verification checks for Stage 1 and Stage 2.
# Usage: bash scripts/verify.sh [stage1|stage2|all]
# Default: all
# =============================================================================

STAGE=${1:-all}
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}✔${RESET} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✖${RESET} $1"; ((FAIL++)); }
header() { echo -e "\n${BOLD}${CYAN}$1${RESET}"; }

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

container_running() {
  docker ps --format '{{.Names}}' | grep -q "^$1$"
}

curl_check() {
  local url=$1
  local expected=$2
  local result
  result=$(curl -s "$url")
  if echo "$result" | grep -q "$expected"; then
    pass "$url → $result"
  else
    fail "$url → expected '$expected', got '$result'"
  fi
}

dns_should_fail() {
  local container=$1
  local target=$2
  if docker exec "$container" ping -c 1 "$target" > /dev/null 2>&1; then
    fail "$container → $target should be unreachable but is not"
  else
    pass "$container cannot resolve $target (isolation confirmed)"
  fi
}

python_connect() {
  local container=$1
  local host=$2
  local db=$3
  local user=$4
  local password=$5
  if docker exec "$container" python -c "
import psycopg2
conn = psycopg2.connect(host='$host', database='$db', user='$user', password='$password')
conn.close()
print('ok')
" 2>/dev/null | grep -q "ok"; then
    pass "$container → $host: connected"
  else
    fail "$container → $host: connection failed"
  fi
}

# -----------------------------------------------------------------------------
# Stage 1 checks
# -----------------------------------------------------------------------------

run_stage1() {
  header "Stage 1 — Containers running"

  for name in nginx flask_api postgres_db; do
    if container_running "$name"; then
      pass "$name is running"
    else
      fail "$name is not running"
    fi
  done

  header "Stage 1 — API endpoints"

  curl_check "http://localhost/api/health" '"status":"ok"'
  curl_check "http://localhost/api/data" "PostgreSQL"

  header "Stage 1 — Network isolation"

  dns_should_fail "nginx" "postgres_db"

  header "Stage 1 — flask_api → postgres_db connectivity"

  python_connect "flask_api" "postgres_db" "appdb" "appuser" "secret"
}

# -----------------------------------------------------------------------------
# Stage 2 checks
# -----------------------------------------------------------------------------

run_stage2() {
  header "Stage 2 — Additional containers running"

  for name in redis_cache admin_probe; do
    if container_running "$name"; then
      pass "$name is running"
    else
      fail "$name is not running"
    fi
  done

  header "Stage 2 — DNS resolution from flask_api"

  for target in redis_cache postgres_db; do
    if docker exec flask_api nslookup "$target" > /dev/null 2>&1; then
      pass "flask_api resolves $target by name"
    else
      fail "flask_api cannot resolve $target"
    fi
  done

  header "Stage 2 — nginx cannot reach backend_net services"

  dns_should_fail "nginx" "redis_cache"
  dns_should_fail "nginx" "postgres_db"

  header "Stage 2 — admin_probe has no network access"

  if docker exec admin_probe ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    fail "admin_probe should have no network access but reached 8.8.8.8"
  else
    pass "admin_probe cannot reach external network (none network confirmed)"
  fi

  if docker exec admin_probe ping -c 1 nginx > /dev/null 2>&1; then
    fail "admin_probe should have no network access but reached nginx"
  else
    pass "admin_probe cannot reach nginx (none network confirmed)"
  fi
}

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

echo -e "${BOLD}Docker Network Segmentation — Verification${RESET}"
echo -e "Running: ${CYAN}${STAGE}${RESET}\n"

case $STAGE in
  stage1) run_stage1 ;;
  stage2) run_stage1; run_stage2 ;;
  all)    run_stage1; run_stage2 ;;
  *)      echo "Usage: bash scripts/verify.sh [stage1|stage2|all]"; exit 1 ;;
esac

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo -e "\n${BOLD}Results${RESET}"
echo -e "  ${GREEN}Passed: $PASS${RESET}"
echo -e "  ${RED}Failed: $FAIL${RESET}"

if [ $FAIL -eq 0 ]; then
  echo -e "\n${GREEN}${BOLD}All checks passed.${RESET}"
  exit 0
else
  echo -e "\n${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  exit 1
fi
