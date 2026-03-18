# Cyber Kill Chain Tracker (ELK SIEM 기반 위협 탐지 프로젝트)

## 📌 프로젝트 소개
EVE-NG 환경에서 웹, DB, SIEM 서버를 직접 구축하고, 가상의 해킹 시나리오(Cyber Kill Chain)를 수행하여 이를 실시간으로 탐지하는 파이프라인을 구현한 프로젝트입니다. 
단순히 공격만 해보는 것이 아니라, **공격자의 행위가 시스템과 네트워크에 어떤 로그를 남기며, 이를 SIEM 환경에서 어떻게 필터링하고 모니터링할 수 있는지**를 검증하기 위해 기획했습니다.

## 🏗 인프라 구성 (Architecture)
*   **MGMT (SIEM):** 192.168.1.134 (내부 10.10.30.10) - ELK Stack (Elasticsearch, Logstash, Kibana)
*   **DMZ (Web):** 192.168.1.131 (내부 10.10.10.10) - Nginx, PHP, DVWA, Filebeat, Auditd
*   **Core (DB):** 192.168.1.133 (내부 10.10.20.10) - MariaDB, Filebeat, Auditd
*   **External (Attacker):** 192.168.1.132 (내부 192.168.10.100) - Kali Linux 등 공격자 환경

**로깅 파이프라인:** `Filebeat & Auditd (Web/DB)` ➔ `Logstash (SIEM, 포트 5044)` ➔ `Elasticsearch` ➔ `Kibana`

## 🚀 재현 및 테스트 방법 (How to Test)

이 프로젝트를 로컬이나 EVE-NG 환경에서 직접 테스트해보려면 아래 순서대로 진행하시면 됩니다.

### 1단계: 인프라 기동 및 상태 확인
1. 위 네트워크 구성에 맞게 서버 IP를 설정하고 서비스(ELK, Nginx, MariaDB)를 기동합니다.
2. 각 엔드포인트(Web, DB) 서버에서 `systemctl status filebeat auditd` 명령어로 로깅 에이전트가 정상 작동하는지 확인합니다.
3. SIEM 서버(`Logstash`)의 5044 포트가 열려있는지 확인합니다.

### 2단계: 공격 시나리오 실행 (Attacker ➔ Web/DB)
제공된 자동화 스크립트를 사용하거나 직접 웹 브라우저를 통해 오픈소스 취약점 환경인 DVWA(`http://192.168.1.131/dvwa/`)에 접속하여 수동 공격을 수행할 수 있습니다.

*   **자동화 스크립트를 사용할 경우:**
    ```bash
    # Attacker 서버(또는 통신 가능한 터미널)에서 실행
    chmod +x scripts/phase5_attack.sh
    ./scripts/phase5_attack.sh
    ```
*   **수동 공격 테스트:**
    *   **Initial Access**: `http://192.168.1.131/dvwa/login.php` 에 접속 후 `admin/password` 계정으로 로그인하고 DVWA Security 탭에서 레벨을 Low로 설정합니다.
    *   **Execution**: Command Injection 탭(`http://192.168.1.131/dvwa/vulnerabilities/exec/`)에서 `127.0.0.1;whoami` 혹은 `127.0.0.1;cat /etc/passwd` 등을 입력하고 실행합니다.
    *   **Persistence**: File Upload 탭(`http://192.168.1.131/dvwa/vulnerabilities/upload/`)을 통해 간단한 PHP 웹쉘 코드(`<?php system($_GET["cmd"]); ?>` 등)를 업로드합니다.
    *   **Lateral Movement**: 획득한 웹쉘 경로(예: `http://192.168.1.131/dvwa/hackable/uploads/shell.php?cmd=nc -zv 10.10.20.10 3306`)를 이용해 내부망 DB 서버의 3306 포트 접근을 시도합니다.

### 3단계: Kibana에서 위협 탐지 (Threat Hunting)
공격 스크립트를 돌린 후, 사이버 킬체인 단계별로 시스템에 남은 로그를 확인합니다.
1. Kibana( `https://192.168.1.134:5601` )에 접속합니다.
2. Discover 메뉴로 이동 후 아래 KQL(Kibana Query Language) 쿼리를 입력해봅니다.
   *   **웹 공격 및 백도어 업로드 시도 탐지 (Nginx 로그):**
       ```kql
       index: "log-nginx_access-*" AND (request_uri: *%3B* OR request_uri: *exec* OR request_uri: *upload*)
       ```
   *   **비정상적인 시스템 명령어 실행 (Auditd 커널 로그):**
       ```kql
       index: "log-auditd-*" AND tags: "command_execution" AND message: (*whoami* OR *passwd* OR *nc*)
       ```
   *   **내부망 확산 탐지 (Lateral Movement):**
       ```kql
       index: "log-auditd-*" AND message: *10.10.20.10*
       ```
3. 수집된 데이터를 바탕으로 Dashboard를 구성해 Top 10 공격 IP, 시간대별 오류 발생 빈도 등을 차트로 시각화할 수 있습니다.

## 💡 느낀 점 (Lessons Learned)
*   **Grok 필터 최적화 삽질(?)**: 처음에 Nginx 로그를 Logstash에서 Raw하게 파싱하려고 하다 보니 Filebeat nginx 모듈이 올려보내는 기본 포맷과 충돌이 나서 애를 먹었습니다. 이중 파싱을 빼고 `url.original` 같은 내장 필드를 복사해서 쓰는 방식으로 리소스 소모를 줄이면서 해결했습니다.
*   **정교한 로그 수집의 중요성**: `auditd` 룰을 너무 범위가 넓게 잡았더니, 크론잡이나 시스템 타이머들이 발생시키는 노이즈 로그 데이터가 기하급수적으로 쌓였습니다. `type=EXECVE`에 찍히는 로그 중에 `nc`, `wget` 같은 악성 행위 의심 명령어들을 위주로 뽑아내는 튜닝이 꼭 필요하다는 걸 깨달았습니다.
*   **공격과 방어의 연결고리**: 직접 쳐본 웹 취약점 공격(Command Injection 등)이 OS 커널단(auditd)과 웹서버 로깅(Nginx)에 각각 쪼개져서 어떤 흔적을 남기는지 타임라인을 파악해 볼 수 있어서 유익한 경험이었습니다.
