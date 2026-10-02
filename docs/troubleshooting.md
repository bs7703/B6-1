# 문제와 해결 기록

작업 대화에서 실제 관찰된 오류와 이번 보완을 정리했다. 당시 VS Code 내부 실행 방식까지
확인하지 못한 부분은 추정과 확정을 구분했다.

| 관찰된 문제 | 확인/판단 | 해결과 확인 |
|---|---|---|
| CREATE 이후 SELECT가 비었음 | CREATE는 입력이 아니다. 당시 선택 범위와 DB 연결은 직접 확인하지 못함 | 같은 DB에 생성/입력 순서로 실행. 지금은 reset 스크립트와 table_counts.log로 확인 |
| cannot commit - no transaction is active | COMMIT 시 열린 트랜잭션이 없다는 것은 확인. 확장의 분할/자동 커밋 여부는 미확인 | GUI용 생성/입력 SQL의 수동 BEGIN/COMMIT 제거. 초기화는 Python의 새 DB 생성·검사 후 반영 방식으로 분리 |
| loans만 바꾸려는데 categories.category_id 중복 오류 | 기존 categories PK를 다시 삽입했다는 뜻. 당시 전체 파일/선택 범위는 확정하지 못함 | 전체 seed 재실행과 대출 전용 실행을 구분. 현재는 조회/수정도 분리하고 전체 초기화는 reset 스크립트 사용 |
| 없는 category_id 삽입 오류 여부 | FK가 켜진 연결에서는 없는 부모 참조 거부 | wrong_fk_insert.sql과 integrity_results.log에서 4개 FK 삽입 실패 재현 |
| NULL인 '반납기한'이 안 보임 | return_date는 실제 반납일이며 기한 열이 아님. 미반납 22건은 NULL | date(loan_date,'+14 days')로 기한을 계산하고 핵심 지표로 확인 |
| categories 7행으로 최소 10행 미달 | 다른 표는 충분했지만 categories만 부족 | 역사·예술·여행 추가. 빈 카테고리는 LEFT JOIN 0건 처리도 검증 |
| 평가에서 결과 미첨부 지적 | 최신 main에는 기존 조회·핵심 지표·FK 오류 로그가 존재. 평가 당시 상태/탐지 여부는 미확인 | 실제 SQL 포함 로그로 재생성하고 전체 17개·수정·무결성·빈 DB 로그와 문서 링크 추가 |
| README와 실제 파일 구성이 다름 | 조회 12개, core 3개, modify 2개로 분리되어 있고 초기화 파일은 Git에 없었음 | 실제 구성으로 README 수정. .gitignore의 *.py/*.sh 제거로 스크립트 추적. 생성 DB와 캐시는 제외 |

## 재현

```bash
python3 verify_submission.py
```

새 메모리 DB 입력 → 조회 12개 → 핵심 지표 3개 → 제약/CASCADE → 빈 DB NULL/0 → 수정 2개와 반복 실행 순서다.
제약 테스트는 SAVEPOINT로 되돌리며 사용자 DB를 바꾸지 않는다.
예상 출력의 복사가 아니라 실제 SQLite 예외를 기록한다.
integrity_results.log에는 FK 검사 ON과 실패 후 데이터 보존 여부도 기록된다.
