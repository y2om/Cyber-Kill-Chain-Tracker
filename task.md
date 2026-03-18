# Cyber-Kill-Chain Tracker: 프로젝트 태스크

## Phase 1: 인프라 및 네트워크 설계 (EVE-NG)
- [x] 노드 배치 구상 (네트워크 라우터 + Ubuntu 서버 4대: Attacker, Web, DB, SIEM)
- [x] IP 구상표 작성 (외부망, 내부망 분류 및 정확한 IP 할당)
- [x] 라우터 ACL(Access Control List)를 활용한 포트포워딩 및 접근 제어 정책 설계

## Phase 2: 대상(Target) 환경 구성 및 취약점 배치
- [x] DMZ Web 서버 구성: Nginx 설치, 취약한 웹 서비스(DVWA 등) 업로드
- [x] Internal DB 서버 구성: MariaDB 설치, Web 서버 연동 계정(10.10.10.10) 설정

## Phase 3: 중앙 집중형 로깅 인프라 및 에이전트 구축
- [x] MGMT Log 서버 구성: ELK (Elasticsearch, Logstash, Kibana) 환경 구축 완료
- [x] Web/DB 서버 Auditd 설정: 파일 변조 감시, 특권 명령어 실행 탐지 등 주요 룰셋 적용
- [x] Web/DB 서버 Filebeat 설치: 시스템 로그 및 Auditd 이벤트 Logstash로 포워딩
- [x] 통합 로그 수집 검증: Kibana에서 수집된 로그 인덱스 확인 완료

## Phase 4: 로그 파싱(정규화) 및 위협 사냥 대시보드 구현
- [x] Logstash conf 작성: Nginx access 로그, Auditd계열 필터링 파싱 (Grok) → `configs/logstash_beats.conf`
- [/] Kibana 연동: 인덱스 패턴 생성 및 기초 대시보드 구성 (Data Visualization)
- [/] 위협 헌팅용 타임라인 쿼리 준비 (KQL 활용) → `configs/kql_threat_hunting_queries.kql`

## Phase 5: 킬체인 기반 공격 시나리오 시뮬레이션
- [x] **1단계 (Initial Access):** 파라미터 변조 등을 통한 외부망(Kali)에서의 웹 쉘(Web Shell) 업로드
- [x] **2단계 (Execution & C2):** 리버스 쉘(Reverse Shell) 연결로 시스템 Shell 획득
- [x] **3단계 (Privilege Escalation):** 크론탭/SUID 익스플로잇이나 커널 취약점을 통한 관리자 권한(root) 획득
- [x] **4단계 (Lateral Movement):** 획득한 시스템/네트워크 정보를 토대로 내부 DB 침투 및 민감 정보 접근

## Phase 6: 시나리오 분석 및 포트폴리오(IR Report) 문서화
- [x] Kibana 대시보드를 통해 각 킬체인 단계별 공격자의 로그 증적(Evidence) 추출
- [x] 추출된 증적을 바탕으로 침해 사고 타임라인(IR Timeline) 역추적 보고서 도출
- [x] GitHub README 작성: 인프라 아키텍처 다이어그램, 공격 시나리오, 헌팅 쿼리 예시, 오탐/튜닝 기록, 프로젝트 소회 등 정리
