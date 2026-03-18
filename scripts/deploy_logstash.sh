#!/bin/bash
# SIEM 서버: 새 Logstash 설정 검증 및 적용 스크립트

echo "=========================================="
echo " Logstash 설정 검증 및 업데이트"
echo "=========================================="

echo ""
echo "[1] 현재 설정 백업..."
cp /etc/logstash/conf.d/beats.conf /etc/logstash/conf.d/beats.conf.bak_$(date +%Y%m%d_%H%M%S)
echo "    완료: beats.conf.bak_$(date +%Y%m%d_%H%M%S)"

echo ""
echo "[2] Elasticsearch CA 인증서 확인..."
if [ -f /etc/elasticsearch/certs/http_ca.crt ]; then
    mkdir -p /etc/logstash/certs
    cp /etc/elasticsearch/certs/http_ca.crt /etc/logstash/certs/
    chmod 644 /etc/logstash/certs/http_ca.crt
    echo "    [OK] CA 인증서 복사 완료"
else
    echo "    [WARN] CA 인증서 파일이 없음. SSL 없이 진행합니다."
    # SSL 없이 동작하도록 설정 수정
    sed -i 's/ssl_enabled.*=> true/ssl_enabled      => false/g' /tmp/beats_new.conf
    sed -i 's/ssl_certificate_authorities.*//g' /tmp/beats_new.conf
    echo "    [INFO] SSL 설정을 false로 변경했습니다."
fi

echo ""
echo "[3] 새 설정 파일 적용..."
cp /tmp/beats_new.conf /etc/logstash/conf.d/beats.conf
echo "    완료"

echo ""
echo "[4] Logstash 설정 문법 검증..."
/usr/share/logstash/bin/logstash --config.test_and_exit \
  -f /etc/logstash/conf.d/beats.conf 2>&1 | tail -20

LOGSTASH_EXIT=$?
echo "    검증 exit code: $LOGSTASH_EXIT"

if [ $LOGSTASH_EXIT -eq 0 ]; then
    echo ""
    echo "[5] 검증 성공! Logstash 재시작..."
    systemctl restart logstash
    sleep 5
    echo "    서비스 상태: $(systemctl is-active logstash)"

    echo ""
    echo "[6] Logstash 시작 로그 확인 (최근 10줄):"
    journalctl -u logstash --no-pager -n 10 2>/dev/null || \
      tail -10 /var/log/logstash/logstash-plain.log 2>/dev/null

else
    echo ""
    echo "[!] 설정 검증 실패! 기존 설정으로 복원합니다."
    cp /etc/logstash/conf.d/beats.conf.bak_* /etc/logstash/conf.d/beats.conf 2>/dev/null | tail -1
    echo "    기존 설정 복원 완료"
fi

echo ""
echo "=========================================="
echo " 완료"
echo "=========================================="
