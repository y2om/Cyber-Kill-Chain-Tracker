#!/bin/bash
# =============================================================================
# Phase 4 완료: Kibana 인덱스 패턴 자동 생성
# Phase 5 시작: Kill Chain 공격 시뮬레이션 준비
# =============================================================================

KIBANA="https://localhost:5601"
ES="https://localhost:9200"
AUTH="elastic:ntAHiBOfSg**Fb0PJTDU"
CURL="curl -sk -u $AUTH"
KCURL="curl -sk -u $AUTH -H 'kbn-xsrf: true' -H 'Content-Type: application/json'"

echo "=============================================="
echo " Phase 4 완료: Kibana 인덱스 패턴 생성"
echo "=============================================="

# 1. Kibana가 준비될 때까지 대기
echo ""
echo "[*] Kibana 상태 확인..."
for i in {1..10}; do
    STATUS=$(curl -sk -u "$AUTH" "${KIBANA}/api/status" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('overall',{}).get('level','unknown'))" 2>/dev/null)
    if [ "$STATUS" = "available" ]; then
        echo "    [OK] Kibana 준비 완료"
        break
    fi
    echo "    [..] 대기 중 ($i/10)... status=$STATUS"
    sleep 5
done

# 2. 인덱스 패턴 생성 함수
create_data_view() {
    local TITLE=$1
    local NAME=$2
    
    RESULT=$(curl -sk -u "$AUTH" \
        -X POST "${KIBANA}/api/data_views/data_view" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d "{\"data_view\":{\"title\":\"${TITLE}\",\"name\":\"${NAME}\",\"timeFieldName\":\"@timestamp\"}}")
    
    ID=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data_view',{}).get('id','ERROR: '+str(d)[:100]))" 2>/dev/null)
    echo "    [인덱스 패턴] $NAME → ID: $ID"
}

echo ""
echo "[1] 인덱스 패턴 생성 중..."
create_data_view "log-nginx_access-*" "Nginx Access Logs"
create_data_view "log-auditd-*" "Auditd Security Events"
create_data_view "log-system-*" "System & Auth Logs"

echo ""
echo "[2] 생성된 Data Views 확인:"
curl -sk -u "$AUTH" "${KIBANA}/api/data_views" | python3 -c "
import sys, json
d = json.load(sys.stdin)
views = d.get('data_view', [])
for v in views:
    title = v.get('title','')
    name = v.get('name','')
    if 'log-' in title:
        print(f'  [OK] {name}: {title}')
" 2>/dev/null

echo ""
echo "=============================================="
echo " Phase 4 완료!"
echo "=============================================="
