#!/bin/bash
# Phase 4: 각 인덱스 로그 내용 상세 확인 스크립트

ES="https://localhost:9200"
AUTH="elastic:ntAHiBOfSg**Fb0PJTDU"
DATE=$(date +%Y.%m.%d)

echo "=========================================="
echo " Phase 4: 로그 수집 및 파싱 검증 결과"
echo " 날짜: $DATE"
echo "=========================================="

echo ""
echo "▶ [1] 현재 log-* 인덱스 목록 및 문서 수:"
curl -sk -u "$AUTH" "https://localhost:9200/_cat/indices/log-*?h=index,docs.count&s=index"

echo ""
echo "▶ [2] log-auditd 최신 로그 3건 (message 필드):"
curl -sk -u "$AUTH" "${ES}/log-auditd-${DATE}/_search?size=3&sort=@timestamp:desc" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d.get('hits', {}).get('hits', [])
if not hits:
    print('  [!] 오늘 날짜 인덱스에 데이터 없음')
else:
    for i, h in enumerate(hits):
        src = h.get('_source', {})
        msg = src.get('message', '(no message)')[:300]
        print(f'  [{i+1}] {msg}')
"

echo ""
echo "▶ [3] log-nginx_access 최신 로그 3건 (파싱 결과):"
curl -sk -u "$AUTH" "${ES}/log-nginx_access-${DATE}/_search?size=3&sort=@timestamp:desc" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d.get('hits', {}).get('hits', [])
if not hits:
    print('  [!] 오늘 날짜 인덱스에 데이터 없음. 2026.03.15 기준 확인:')
    exit()
for i, h in enumerate(hits):
    src = h.get('_source', {})
    print(f'  [{i+1}] client_ip={src.get(\"client_ip\",\"N/A\")} method={src.get(\"http_method\",\"N/A\")} uri={src.get(\"request_uri\",\"N/A\")[:80]} status={src.get(\"http_status_code\",\"N/A\")}')
"

echo ""
echo "▶ [4] log-nginx_access-2026.03.15 (기존 수집 데이터 파싱 확인):"
curl -sk -u "$AUTH" "${ES}/log-nginx_access-2026.03.15/_search?size=3&sort=@timestamp:desc" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
hits = d.get('hits', {}).get('hits', [])
if not hits:
    print('  [!] 데이터 없음')
else:
    for i, h in enumerate(hits):
        src = h.get('_source', {})
        client_ip = src.get('client_ip', 'N/A')
        method = src.get('http_method', 'N/A')
        uri = src.get('request_uri', src.get('message','N/A'))[:80]
        status = src.get('http_status_code', 'N/A')
        tags = src.get('tags', [])
        print(f'  [{i+1}] IP={client_ip} {method} {uri} [{status}] tags={tags}')
"

echo ""
echo "▶ [5] log-auditd에서 EXECVE 타입 이벤트 검색:"
curl -sk -u "$AUTH" "${ES}/log-auditd-*/_search?size=5&q=message:EXECVE&sort=@timestamp:desc" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
total = d.get('hits', {}).get('total', {}).get('value', 0)
hits = d.get('hits', {}).get('hits', [])
print(f'  총 EXECVE 이벤트: {total}건')
for i, h in enumerate(hits):
    msg = h.get('_source', {}).get('message', '')[:200]
    print(f'  [{i+1}] {msg}')
"

echo ""
echo "▶ [6] Logstash 파이프라인 통계 (처리량 확인):"
curl -sk -u "$AUTH" "${ES}/_nodes/stats/ingest" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
nodes = d.get('nodes', {})
for nid, node in nodes.items():
    name = node.get('name', nid)
    ingest = node.get('ingest', {}).get('total', {})
    print(f'  Node: {name}')
    print(f'  - 처리된 문서: {ingest.get(\"count\", 0)}')
    print(f'  - 실패한 문서: {ingest.get(\"failed\", 0)}')
"

echo ""
echo "▶ [7] Filebeat 연결 상태 (Web 서버 → SIEM):"
ss -tnp | grep 5044 || netstat -tnp 2>/dev/null | grep 5044 || echo "  (ss 명령 사용불가)"

echo ""
echo "=========================================="
echo " 검증 완료"
echo "=========================================="
