#!/bin/bash
AUTH="elastic:ntAHiBOfSg**Fb0PJTDU"

echo "================================================="
echo " IR Report: 킬체인 기반 공격 시나리오 시뮬레이션"
echo "================================================="
echo ""

cat << 'EOF' > /tmp/parse.py
import sys, json

stage = sys.argv[1]
try:
    d = json.load(sys.stdin)
    hits = d.get("hits",{}).get("hits",[])
    if hits:
        print(f"[{stage}]")
        for h in hits:
            s = h.get("_source", {})
            ts = s.get("@timestamp")
            
            if stage == "Nginx":
                ip = s.get('client_ip')
                uri = s.get('request_uri')
                print(f"- Time: {ts}")
                print(f"- IP: {ip} -> URI: {uri}")
                
            elif stage == "Auditd" or stage == "Lateral":
                msg = s.get('message', '')[:150]
                print(f"- Time: {ts}")
                print(f"- MSG : {msg}")
                
            elif stage == "Upload":
                uri = s.get('request_uri')
                print(f"- Time: {ts} | URI: {uri}")
except Exception as e:
    print("Error parsing json:", e)
EOF

echo "## [단계 1: Initial Access & Execution] 웹 취약점 악용(Command Injection)"
curl -sk -u "$AUTH" 'https://localhost:9200/log-nginx_access-*/_search?size=3&sort=@timestamp:desc&q=tags:dvwa_attack_endpoint' | python3 /tmp/parse.py "Nginx"
echo ""

echo "## [단계 2: Execution] 시스템 명령어 실행 (Auditd log)"
curl -sk -u "$AUTH" 'https://localhost:9200/log-auditd-*/_search?size=3&sort=@timestamp:desc&q=tags:command_execution' | python3 /tmp/parse.py "Auditd"
echo ""

echo "## [단계 3: Persistence] Web Shell 업로드"
curl -sk -u "$AUTH" 'https://localhost:9200/log-nginx_access-*/_search?size=2&sort=@timestamp:desc&q=request_uri:*upload*' | python3 /tmp/parse.py "Upload"
echo ""

echo "## [단계 4: Lateral Movement] DB 연동 파일 및 시스템 접근 시도"
curl -sk -u "$AUTH" 'https://localhost:9200/log-auditd-*/_search?size=2&sort=@timestamp:desc&q=message:*cat*config.inc*+OR+message:*3306*' | python3 /tmp/parse.py "Lateral"
echo ""
