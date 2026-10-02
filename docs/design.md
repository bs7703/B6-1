# 설계 근거와 쿼리 해설

## 정규화와 분리 이유

정규화(normalization)는 같은 사실을 여러 곳에 저장하여 수정·삽입·삭제 이상이 생기는 것을 줄인다.
이 모델은 **책 한 권에 대표 저자 한 명, 대표 카테고리 한 개**라는 범위에서 다음 함수 종속을 전제로 한다.

| 테이블 | 함수 종속 | 분리한 이유 |
|---|---|---|
| authors | author_id → name | 저자 이름을 책마다 반복 저장하지 않고 한 곳에서 수정 |
| categories | category_id → name | 카테고리 이름 중복을 UNIQUE로 막고 도서와 분리 |
| users | user_id → name | 회원과 여러 대출을 분리하여 회원 이름을 대출마다 복제하지 않음 |
| books | book_id → title, author_id, category_id | 소장 도서의 정보와 반복되는 대출 사건을 분리 |
| loans | loan_id → user_id, book_id, loan_date, return_date | 같은 책의 여러 과거 대출을 개별 행으로 보존 |

- **1NF(제1정규형)**: 각 열은 이 모델에서 하나의 값이다. 한 셀에 여러 저자나 대출일 목록을 저장하지 않는다.
- **2NF(제2정규형)**: 기본키가 단일 열이므로 복합키 일부에 대한 비키 열의 부분 종속이 없다.
- **3NF(제3정규형)**: 비키 속성이 다른 비키 속성을 결정하는 종속을 이 모델에 두지 않는다.
  books에 author_name을 저장하면 `book_id → author_id → author_name`의 이행 종속이 생긴다.
  현재는 이름을 authors에서 조회하며 loans에도 회원 이름·도서 제목을 복제하지 않는다.

동명이인 및 같은 제목의 책이 가능하므로 `name → ID`, `title → author_id`는 가정하지 않는다.
공동 저자·다중 카테고리·같은 판본의 여러 소장본이 필요하면 연결 테이블과 판본/소장본 분리가 필요하다.
3NF 설명은 위 모델의 함수 종속에 대한 것이며 모든 도서관 업무를 모델링했다는 뜻은 아니다.

## 타입과 제약 선택

| 열 | 타입/제약 | 이유 |
|---|---|---|
| 각 *_id PK | INTEGER PRIMARY KEY | 정수 식별자이며 SQLite rowid의 별칭. 별도의 AUTOINCREMENT는 요구하지 않음 |
| FK 열 | INTEGER NOT NULL + FK | 부모 PK와 같은 표현. 연결의 생략과 존재하지 않는 참조를 거부 |
| 이름·제목 | TEXT NOT NULL + length CHECK | Unicode 문자열. NULL·빈 문자열·과도한 길이를 거부 |
| categories.name | TEXT UNIQUE | 사전 항목의 같은 카테고리 이름 중복 거부 |
| loan_date | YYYY-MM-DD TEXT NOT NULL | 읽기 쉽고 date()/julianday()에 입력 가능 |
| return_date | YYYY-MM-DD TEXT 또는 NULL | 실제 반납일. NULL로 미반납 상태 표현 |

SQLite에는 날짜 전용 저장 클래스가 없으며 `STRICT`에서 `DATE`는 허용 타입이 아니다.
고정된 YYYY-MM-DD 형식끼리는 사전순 비교가 날짜 순서와 같아 `return_date >= loan_date`를 사용한다.
현재 CHECK는 길이·문자 패턴·앞뒤 순서만 검사한다. `2026-02-31` 같은 달력상 불가능한 날짜까지 거부하지는 않는다.
실제 달력 검증은 입력 계층 등의 별도 규칙이 필요하며, 샘플 날짜는 유효한 날짜로 구성했다.

`PRAGMA foreign_keys=ON`은 연결 단위이고 부모 행을 자동 생성하지 않는다. 트랜잭션 중 설정 변경은 적용되지 않는다.
모든 FK의 `ON DELETE RESTRICT`는 참조 중인 부모 삭제를 차단하며 `ON UPDATE CASCADE`는 부모 ID 변경을 자식에 전파한다.
실제 결과는 [무결성 로그](../result_log/integrity_results.log)에 있다.

## 인덱스 선택 근거

| 인덱스 | 대표 요청/쿼리 | 기대 효과 |
|---|---|---|
| one_active_loan_per_book | book_id=1 AND return_date IS NULL | 미반납 중복 차단과 특정 책의 현재 대출 검색 |
| idx_books_author_id | author_id=1 / 조회 05·08 | 저자별 도서 검색과 부모 삭제 시 자식 참조 확인 |
| idx_books_category_id | category_id=5 / 조회 04·06·09·11 | 범주별 도서 검색·조인·집계에 후보 경로 제공 |
| idx_loans_user_id | user_id=1 / 조회 10·핵심 지표 3 | 회원별 대출과 부모 삭제 시 자식 참조 확인 |
| idx_loans_book_id | book_id=1의 전체 이력 / 조회 12 | 과거·현재 이력 검색과 NOT EXISTS 존재 검사 |
| idx_loans_loan_date | 대출일 범위·최근 정렬 / 조회 02 | 날짜 범위와 정렬. return_date 검색에는 직접 대응하지 않음 |

INTEGER PRIMARY KEY 검색은 rowid가 지원하므로 동일 PK 인덱스를 중복 생성하지 않았다.
부분 UNIQUE는 미반납 행만 포함하므로 전체 이력용 idx_loans_book_id와 역할이 다르다.
인덱스는 저장 공간과 쓰기 비용을 늘리므로 모든 열에 만들지 않았다.
각 대표 검색의 `EXPLAIN QUERY PLAN`은 [SQL](../bonus/index_examples.sql)과
[실행 계획 로그](../result_log/index_query_plans.log)에서 확인한다.
전체 집계나 작은 표에서는 SCAN을 선택할 수 있다. 계획은 버전·통계·조건에 따라 달라지고
이번 예제는 큰 데이터에서 속도가 몇 배 빨라지는지를 측정한 벤치마크가 아니다.

## INNER JOIN과 LEFT JOIN 결과

조회 05는 저자가 연결되는 책 30행을 반환한다. 책 없는 저자 8번 황석영은 등장하지 않는다.
조회 08은 authors LEFT JOIN books로 책 없는 저자도 남긴 뒤 `b.book_id IS NULL`로 걸러 황석영 1행을 반환한다.
조회 09는 새 카테고리 8·9·10을 각각 book_count=0으로 반환한다.
[조회 결과](../result_log/query_results.log)와 [스냅샷](images/join_results.png)을 참고한다.

## NULL과 0 처리

- COUNT(*)는 LEFT JOIN의 미일치 행도 센다. COUNT(l.loan_id)는 오른쪽 NULL을 제외하여 대출 없는 회원을 0건으로 센다.
- return_date IS NULL만 검사하면 미일치 행까지 미반납으로 오인한다. loan_id IS NOT NULL도 확인한다.
- SUM/AVG는 NULL을 제외하며 집계할 값이 없으면 NULL이다. 건수와 합계는 COALESCE로 0을 표시한다.
- 이용일 평균은 관측이 없으면 NULL을 유지하여 같은 날 반납한 기록의 평균 0일과 구분한다.
- 도서 0권에서 대출 중 비율은 정의되지 않아 NULLIF로 분모를 NULL로 만든다.
- 반납 조건을 LEFT JOIN의 ON에 두면 기록 없는 카테고리를 보존한다. WHERE에 넣으면 제외될 수 있다.

빈 DB에 실제 실행한 결과는 [empty_database_results.log](../result_log/empty_database_results.log)에 있다.

## 핵심 지표 3의 단계별 집계

1. users LEFT JOIN loans로 대출 없는 회원도 남긴다.
2. user_id로 그룹화하여 loan_count와 active_count를 만든다. 회원 단위 중간 결과는 30행이다.
3. 바깥 SELECT가 이 30행에 COUNT/SUM/AVG를 적용하여 회원 지표 한 행을 만든다.

| user_id | loan_count | active_count | 해석 |
|---:|---:|---:|---|
| 1 | 22 | 4 | 과거와 현재 대출 모두 있음 |
| 8 | 22 | 0 | 반납 이력만 있음 |
| 23 | 0 | 0 | 대출 이력 없음 |
| 25 | 2 | 2 | 현재 대출만 있음 |

[중간 전체 표](../result_log/user_loan_summary.log)의 합계는 185건이다.
최종 결과는 `(30,26,4,11,6.17)`이다. 평균은 미이용 회원까지 포함한 `185/30`이다.
185개 대출 행을 회원 수로 세거나 대출 있는 회원 26명만 분모에 넣지 않는다.

## 조회 12의 상관 서브쿼리

바깥 books의 각 책에 대해 안쪽 loans에 같은 book_id가 존재하는지 확인한다.
한 건이라도 있으면 EXISTS가 참이므로 NOT EXISTS가 거짓이 되어 제외한다.
도서 1번은 이력이 있어 제외, 30번 '돈의 속성'은 없어 포함된다. NULL 날짜 여부는 이 요청과 무관하다.
이는 논리적 설명이며 실제 실행 방식은 SQLite의 계획에 따른다.

## 데이터베이스와 엑셀 비교

| 관점 | SQLite 관계형 DB | 일반 엑셀 워크북 |
|---|---|---|
| 관계 | PK/FK로 선언하고 JOIN으로 조회 | 시트·표·조회 함수로 연결 가능하나 보통 사용자가 규칙 관리 |
| 무결성 | 켜진 FK와 UNIQUE/NOT NULL/CHECK로 위반 쓰기 거부 | 유효성 검사도 가능하지만 DB 참조 제약과 같은 보장은 아님 |
| 변경 원자성 | 트랜잭션으로 묶은 변경의 원자성 지원 | 셀·파일 중심이며 DB 트랜잭션과 동등한 모델은 아님 |
| 동시성 | 여러 읽기 연결, 쓰기는 직렬화·잠금 제약 있음 | 공동 편집 가능한 환경도 있지만 DB 잠금·트랜잭션과 방식이 다름 |
| 장점 | 일관성·반복 가능한 SQL·프로그램 연동 | 손쉬운 편집·수식·차트·소규모 탐색과 보고 |
| 비용 | 스키마·SQL·인덱스·연결 관리 학습 필요 | 커지거나 복잡해지면 중복·참조·수식 관리가 어려워짐 |

차이는 단순 행 수가 아니다. 엑셀도 관계를 표현할 수 있으나 이 과제는 관계와 쓰기 규칙을 DB 엔진에 선언한다.

## 참고

- [SQLite STRICT Tables](https://www.sqlite.org/stricttables.html)
- [SQLite Foreign Key Support](https://www.sqlite.org/foreignkeys.html)
- [SQLite Query Planning](https://www.sqlite.org/queryplanner.html)
- [SQLite Datatypes](https://www.sqlite.org/datatype3.html)
