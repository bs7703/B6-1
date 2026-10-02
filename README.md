# 도서관 SQLite 학습 예제

테이블 5개와 연습 데이터를 담은 완성 DB입니다. 압축을 풀면 바로 조회할 수 있습니다.
SQLite 3.37.0 이상이 필요하며, 3.43.2에서도 사용할 수 있습니다.

## 파일 구성

| 파일 | 내용 |
|---|---|
| `library_practice.db` | 테이블·인덱스·데이터가 들어 있는 DB |
| `create_table.sql` | 테이블 5개와 인덱스 생성 |
| `insert_items.sql` | 모든 테이블에 연습 데이터 입력 |
| `library_queries.sql` | 조회·조인·집계·서브쿼리·핵심 지표·수정·삭제 예제 17개 |
| `reset_database.py` | DB 전체 초기화 후 테이블·데이터 자동 생성 |
| `db_alias.sh` | Bash/Zsh에서 `dbreset` alias 등록 |
| `insert_loans.sql` | 비어 있는 loans에 대출 185건만 입력 |
| `replace_loans.sql` | 기존 loans를 삭제하고 대출 185건으로 교체 |

## 데이터와 관계

카테고리 7개, 저자 12명, 회원 30명, 도서 30권, 대출 185건입니다.
대출은 반납 완료 163건과 미반납 22건으로 구성됩니다.
책·저자 관계는 실제 관계이며, 회원 이름과 대출 기록은 가상 데이터입니다.

저자와 카테고리는 각각 여러 책을 가지며, 회원과 책은 각각 여러 대출 기록에 연결됩니다.
책의 `author_id`, `category_id`와 대출의 `user_id`, `book_id`는 외래키입니다.
`book_id` 하나는 책 한 권이고, 같은 책의 미반납 대출은 최대 1건입니다.
이름은 저자·회원 5자 이하, 제목은 20자 이하입니다.

`return_date`는 **실제 반납일**이며, `NULL`이면 미반납입니다.
반납기한은 별도 열 없이 대출일 + 14일로 계산합니다.
기준일 2026-10-02에서 연체 9건, 오늘 기한 2건, 기한 전 11건입니다.
대출 이력 없는 회원·도서, 등록 도서 없는 저자, 동명이인도 포함합니다.

## DB 열기

VS Code SQLite 확장의 Open Database로 `library_practice.db`를 엽니다.
또는 해당 폴더의 터미널에서 실행합니다.

```bash
sqlite3 "library_practice.db"
```

직접 연결하여 데이터를 수정할 때는 해당 연결에서 먼저 `PRAGMA foreign_keys = ON;`을 실행합니다.
완성 DB에는 이미 데이터가 있으므로 `insert_items.sql`을 다시 실행하면 중복 키 오류가 납니다.

## 전체 초기화

Python 3가 필요하며, Python에 내장된 SQLite도 3.37.0 이상이어야 합니다.
압축을 푼 폴더의 Bash/Zsh 터미널에서 실행합니다.

```bash
source ./db_alias.sh
dbreset
```

`dbreset`은 같은 폴더의 DB 전체를 초기화하고 `create_table.sql` → `insert_items.sql` 순서로 실행합니다.
대상 DB의 기존 테이블·데이터·인덱스·뷰·트리거가 교체됩니다.
다른 DB는 `dbreset "./다른DB.db"`, alias 없이 실행하려면 `python3 reset_database.py`를 사용합니다.
새 터미널에서는 alias를 다시 등록합니다. 초기화 후 VS Code 탐색기를 새로고침하세요.

## 쿼리 실행과 로그 저장

`sqlite3` 명령줄 프로그램이 필요합니다. 원본 DB를 복사한 뒤 예제를 실행합니다.

```bash
cp "library_practice.db" "practice_run.db"
sqlite3 -bail -echo -header -column -cmd "PRAGMA foreign_keys=ON" "practice_run.db" < "library_queries.sql" > "query_results.log" 2>&1
```

SQL 문, 조회 결과, 오류가 `query_results.log`에 저장됩니다.
`>`는 덮어쓰기, `>>`는 누적 저장이며, `-bail`은 오류 이후 실행을 중단합니다.
이미 실행된 변경을 자동으로 되돌리지는 않습니다.
예제 전체 실행 시 16번 UPDATE와 17번 DELETE도 실행되어 대출 184건, 미반납 21건이 됩니다.
조회만 하려면 VS Code에서 1~15번 중 필요한 쿼리만 선택해 실행하세요.
초기화 로그는 `dbreset > reset.log 2>&1`로 저장합니다.
