# Phase 2 Walkthrough: Target Environment Configuration

Phase 2에서는 공격 대상이 될 DMZ망의 웹 서버와 내부망(Core)의 DB 서버를 구축하고, 취약한 웹 애플리케이션인 DVWA를 통해 두 서버를 연동했습니다.

## 1. DMZ Web Server 구성 (192.168.1.131)
- **OS**: Ubuntu 22.04 LTS
- **Services**: Nginx, PHP 8.1-FPM
- **Application**: DVWA (Damn Vulnerable Web Application)
- **Configuration**:
  - Nginx Root: `/var/www/html/dvwa`
  - PHP-FPM 연동 완료
  - `config.inc.php`에서 DB 서버를 `10.10.20.10`(Core Internal IP)으로 설정

## 2. Core DB Server 구성 (192.168.1.133)
- **OS**: Ubuntu 22.04 LTS
- **Services**: MariaDB Server
- **Database**: `dvwa` 생성
- **User**: `dvwa_user`@`%` 생성 (패스워드: `password123`)
- **Security**:
  - `bind-address = 0.0.0.0` 설정으로 원격 접속 허용
  - `ufw` 방화벽 비활성화 및 MariaDB 서비스 활성화 확인

## 3. 연동 검증 결과
Web 서버에서 DB 서버로의 접속 테스트를 수행하고, 브라우저를 통해 DVWA를 성공적으로 초기화했습니다.

![DVWA Login Page](C:\Users\ybhss\.gemini\antigravity\brain\0b1944af-c8d6-4722-854e-a0860c06e8d3\dvwa_login_verification_1773548489363.png)

위 스크린샷은 **192.168.1.131 (Web Server)**에서 성공적으로 가동 중인 DVWA 로그인 화면입니다.

## Phase 3 Walkthrough: Centralized Logging Infrastructure & Agent Setup

Phase 3에서는 MGMT 서버에 ELK 스택(Java 17, Elasticsearch, Logstash, Kibana)을 구축하고, 타겟 서버(Web, DB)에 보안 감사 에이전트를 설치하여 실시간 로그 수집 파이프라인을 완성했습니다.

### 1. MGMT 서버 (SIEM) 구성 (192.168.1.134)
- **ELK Stack 설치**: Java 17 및 ELK 8.x 패키지 설치 완료.
- **Resource Optimize**: 4GB RAM 서버 환경에 맞춰 Elasticsearch 힙 메모리를 1GB로 조정하여 안정성 확보.
- **Security**: `elastic` 계정 암호 재설정 및 Kibana 연동 토큰 발행 완료.
- **Logstash Pipeline**: 5044 포트로 유입되는 Beats 데이터를 수신하여 Elasticsearch에 `log-YYYY.MM.DD` 형식으로 인덱싱하도록 구성.

### 2. 엔드포인트 보안 에이전트 배포
- **Auditd 설치**: Web/DB 서버에 커널 레벨 시스템 콜 감시 및 중요 설정 파일(`shadow`, `passwd` 등) 변조 탐지 룰셋 적용.
- **Filebeat 구성**: 수집된 로그(System, Audit)를 SIEM 서버(10.10.30.10:5044)로 안전하게 수송하도록 설정.

### 3. 연동 검증 결과
- **Connectivity**: `filebeat test output`을 통해 웹/DB 서버와 SIEM 서버 간의 전송 경로(TCP 5044) 정상 확인.
- **Data Indexing**: SIEM 서버의 Elasticsearch에서 실시간 로그 데이터 유입을 나타내는 인덱스 생성 확인.

## Phase 4 Walkthrough: 로그 파싱(정규화) 및 위협 탐지 대시보드 구현

Phase 4에서는 수집된 로그를 Grok 패턴으로 정규화하여 유형별 인덱스로 분리하고, Kibana에서 위협 탐지를 위한 시각화 대시보드를 구성합니다.

---

### Step 1: Auditd 로그 수집 검증

Logstash 필터를 정교화하기 전에, Auditd 이벤트가 실제로 Elasticsearch까지 도달하는지 먼저 검증합니다.

**[Web 서버: 192.168.1.131]** 에서 테스트 명령어 실행:
```bash
# Auditd 감시 대상 명령어 실행 (execve 시스템콜 트리거)
whoami
id
uname -a
```

**[SIEM 서버: 192.168.1.134]** 에서 수집 확인:
```bash
# Elasticsearch에 직접 쿼리하여 auditd 이벤트 유입 확인
curl -k -u elastic:'ntAHiBOfSg**Fb0PJTDU' \
  'https://localhost:9200/log-all-v1/_search?pretty&q=type:EXECVE&size=5'
```

**Kibana에서 확인**: `log-all-v1` 인덱스에서 `type: "EXECVE"` 또는 `message: "*whoami*"` 검색.

---

### Step 2: Logstash 설정 정교화 (Grok 필터 적용)

기존의 단순 수집 설정(`log-all-v1`)을 로그 유형별 분리 파싱 설정으로 교체합니다.

**[SIEM 서버]** 에서 기존 설정 백업 후 교체:
```bash
# 1. 기존 설정 백업
sudo cp /etc/logstash/conf.d/beats.conf \
        /etc/logstash/conf.d/beats.conf.bak_$(date +%Y%m%d)

# 2. 새 설정 파일 적용 (프로젝트의 configs/logstash_beats.conf 내용으로 교체)
sudo nano /etc/logstash/conf.d/beats.conf

# 3. 설정 문법 검증 (오류 있으면 Logstash가 상세 에러 출력)
sudo /usr/share/logstash/bin/logstash --config.test_and_exit \
     -f /etc/logstash/conf.d/beats.conf

# 4. Logstash 재시작
sudo systemctl restart logstash
sudo systemctl status logstash
```

**로그 확인** (정상 기동 여부):
```bash
sudo tail -f /var/log/logstash/logstash-plain.log
```

---

### Step 3: SSL 인증서 설정 (Logstash → Elasticsearch)

Elasticsearch 8.x는 기본적으로 HTTPS를 사용하므로, Logstash가 SSL로 통신하기 위한 CA 인증서를 복사합니다.

```bash
# 1. Logstash 인증서 디렉터리 생성
sudo mkdir -p /etc/logstash/certs

# 2. Elasticsearch CA 인증서 복사
sudo cp /etc/elasticsearch/certs/http_ca.crt /etc/logstash/certs/
sudo chmod 644 /etc/logstash/certs/http_ca.crt

# 3. 연결 테스트
curl -k -u elastic:'ntAHiBOfSg**Fb0PJTDU' \
  --cacert /etc/logstash/certs/http_ca.crt \
  https://localhost:9200/_cluster/health?pretty
```

---

### Step 4: Kibana 인덱스 패턴 생성

Logstash 재시작 후 로그가 유입되면 Kibana에서 새 인덱스 패턴을 생성합니다.

1. **Kibana 접속**: `https://192.168.1.134:5601`
2. **메뉴**: `Stack Management > Index Patterns > Create index pattern`
3. **생성할 패턴 목록**:
   | 인덱스 패턴 | 설명 |
   |---|---|
   | `log-nginx_access-*` | Nginx 웹 접근 로그 |
   | `log-auditd-*` | Auditd 커널 감사 로그 |
   | `log-system-*` | Syslog / 인증 로그 |
4. **Time field**: `@timestamp` 선택

---

### Step 5: Kibana 대시보드 구성

#### 5-1. 필수 시각화 차트 목록

| 차트 이름 | 유형 | 인덱스 | 주요 필드 |
|---|---|---|---|
| Top 10 공격 IP | Bar chart | `log-nginx_access-*` | `client_ip` (Terms) |
| 시간대별 HTTP 오류 추이 | Line chart | `log-nginx_access-*` | `@timestamp`, `http_status_code` |
| 실행된 명령어 목록 | Data table | `log-auditd-*` | `execve_args`, `process_name` |
| 인증 실패 이벤트 | Metric | `log-system-*` | `tags: "auth_failure"` |
| 위협 심각도 분포 | Pie chart | `log-nginx_access-*` | `threat_severity` (Terms) |
| 공격 타임라인 | Area chart | `log-nginx_access-*` | `@timestamp` (Date histogram) |

#### 5-2. 대시보드 생성 절차

```
Kibana > Visualize Library > Create new visualization > Lens
→ 인덱스 패턴 선택 → 차트 유형 선택 → X/Y 축 필드 설정 → Save
→ Dashboards > Create dashboard > Add panel → 저장한 시각화 추가
```

---

### Step 6: 위협 헌팅 KQL 쿼리 준비

`configs/kql_threat_hunting_queries.kql` 파일에 킬체인 단계별 탐지 쿼리를 정리했습니다.

**주요 탐지 규칙**:
- **[WEB-001]** Command Injection: `request_uri: (*%3B* OR *%7C*)`
- **[AUD-001]** 정찰 명령어: `execve_args: (*whoami* OR *id* OR *uname*)`
- **[SYS-001]** SSH 브루트포스: `syslog_message: "Failed password"`

---

### 검증 결과

| 항목 | 결과 | 확인 방법 |
|---|---|---|
| Auditd → Logstash 전송 | ✅ 정상 | `log-all-v1` 인덱스 EXECVE 이벤트 확인 |
| Grok 필터 문법 검증 | ⏳ 적용 예정 | `logstash --config.test_and_exit` |
| Nginx 로그 분리 인덱싱 | ⏳ 적용 예정 | `log-nginx_access-*` 인덱스 생성 확인 |
| Auditd 로그 분리 인덱싱 | ⏳ 적용 예정 | `log-auditd-*` 인덱스 생성 확인 |
| Kibana 인덱스 패턴 생성 | ⏳ 적용 예정 | Kibana Index Patterns 목록 확인 |

