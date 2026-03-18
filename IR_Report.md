# Incident Response (IR) Report: Cyber-Kill-Chain Attack Simulation

## 1. 개요
본 보고서는 2026년 3월 18일 EVE-NG 인프라 상에서 수행된 Cyber Kill Chain 시뮬레이션 중 발생한 공격 지표와 이에 따른 증적 데이터를 기반으로 작성된 타임라인입니다.

**대상 자산 요약:**
- **Web Server (DMZ):** 192.168.1.131 (DVWA, Nginx)
- **DB Server (Internal):** 192.168.1.133 (MariaDB)
- **SIEM Server (MGMT):** 192.168.1.134 (ELK Stack)
- **Attacker (External):** 192.168.1.132

---

## 2. 킬체인 단계별 공격 증적 (Log Evidence)

### Step 1. Initial Access & Execution (초기 침투 및 실행)
웹 어플리케이션(DVWA)의 Command Injection 취약점을 악용하여 임의의 시스템 명령어를 실행하는 공격이 확인되었습니다.

- **발생 일시:** `2026-03-18T04:59:03.403Z`
- **수집 인덱스:** `log-auditd-*` (EXECVE 시스템 콜)
- **증적 내용 (Command Execution):**
  - 공격자가 필터링 우회를 시도하며 명령어 결과를 파싱하는 이벤트 확인.
  - `type=EXECVE msg=audit(...): argc=3 a0="grep" a1="-oP" a2="(?<=<pre>)[^<]+"`
  - `type=EXECVE msg=audit(...): argc=2 a0="head" a1="-10"`
  - 시스템 콜을 통해 시스템 구조(권한 설정 SUID 덤프 등)를 정찰.

### Step 2. Persistence (영속성 유지)
초기 침투에 성공한 공격자는 웹 쉘(Web Shell)을 추가로 업로드하기 위해 HTTP POST 요청을 보낸 흔적이 Nginx 로그에 남아 있습니다.

- **수집 인덱스:** `log-nginx_access-*`
- **의심 행위 탐지 태그:** `dvwa_attack_endpoint` 및 `request_uri: /dvwa/vulnerabilities/upload/` 등을 통해 지속적인 백도어(backdoor) 파일 배포를 시도함.

### Step 3. Privilege Escalation (권한 상승 시도)
명령어 실행 이벤트 중 서버 내 민감한 권한 관리 파일을 탈취하려는 행위가 포착되었습니다.

- **수집 인덱스:** `log-auditd-*`
- **의심 행위 내용:**
  - `find / -perm -4000` (SUID 덤프)
  - `/etc/crontab` 및 `sudo -l` 조회 행위가 Kibana `command_execution` 룰셋에 탐지됨.

### Step 4. Lateral Movement (내부 이동)
DMZ 구간의 웹 서버 장악 후, 내부망(Core)에 있는 DB 서버로의 침투를 시도한 로그가 확인되었습니다.

- **발생 일시:** `2026-03-18T04:59:03.403Z` ~ `04:06`
- **수집 인덱스:** `log-auditd-*`
- **증적 내용:**
  - `cat config.inc.php` 를 통해 연동용 백엔드 Database의 자격증명을 무단으로 획득 시도.
  - `type=EXECVE msg=audit(...): argc=11 a0="curl" a1="-s" a2="-c" a3="/tmp/dvwa_cookie.txt"...` 세션 쿠키를 사용해 추가 공격 진행.
  - 공격자가 `10.10.20.10(DB IP)` 3306 포트를 향해 내부 포트 스캐닝 또는 nc/telnet 기반 연결을 시도하는 시스템콜(`type=SYSCALL syscall=59`) 확인.

---

## 3. 완화 방안 및 튜닝 제안 (Remediation)

1. **Web (HTTP/S) 레벨 방어:**
   - Command Injection 패턴(`;`, `||`, `&&`) 및 특수문자를 인라인으로 필터링하는 정책(WAF) 적용 권장.
2. **Auditd 감사 정책 강화:**
   - 기존의 `execve` 전체 로깅에서 벗어나 `curl`, `wget`, `nc` 등 Living off the Land (LotL) 툴에 집중하는 형태로 정책 필터 튜닝(오탐 감소 방안 마련).
3. **아키텍처 레벨 통제 (Lateral Movement 방지):**
   - 웹 애플리케이션 프론트에서 DB 노드로 직접 가는 세션을 특정 고정 포트 및 특정 App Daemon Account만 통과되도록 방화벽 ACL 조정.
