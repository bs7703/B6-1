-- 카테고리를 포함한 도서관 학습용 구조. SQLite 3.37.0 이상.
-- 새 빈 DB에서 파일 전체를 한 번 실행하세요.
-- 기존 books 테이블에 category_id를 추가하는 마이그레이션 파일은 아닙니다.
/*
테이블 / 기본키(PK) / 외래키(FK)
categories : category_id / 없음         — 카테고리 사전
authors    : author_id   / 없음         — 저자 사전
users      : user_id     / 없음         — 회원 정보
books      : book_id     / author_id, category_id — 소장 도서 1권
loans      : loan_id     / user_id, book_id       — 대출 사건 1건

PK는 행의 식별자, FK는 다른 테이블의 PK를 참조하는 연결이다.
authors/categories 1:N books, users/books 1:N loans.
저자·회원 이름은 중복될 수 있으므로 이름으로 조인하지 않는다.

타입 선택: INTEGER PK는 정수 식별자(rowid의 별칭), FK도 같은 INTEGER.
이름·제목은 가변 길이 Unicode 문자열이므로 TEXT + NOT NULL + 길이 CHECK.
STRICT는 INTEGER/TEXT 등 제한된 타입만 허용하며 DATE 타입은 허용하지 않는다.
날짜는 YYYY-MM-DD TEXT: 읽기 쉽고, 동일 형식에서는 문자열 비교가 날짜 순서와 같다.
날짜 CHECK는 형식과 반납일 >= 대출일만 검사한다. 실제 달력 유효성까지 검사하지 않는다.
return_date NULL은 아직 반납하지 않은 상태를 뜻한다.

FK 동작: 참조 중인 부모 삭제는 RESTRICT, 부모 ID 변경은 CASCADE로 자식에 전파.
외래키 검사는 연결마다 켜야 한다. 재현 로그: result_log/integrity_results.log.
*/
PRAGMA foreign_keys = ON;

CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE CHECK(length(name) BETWEEN 1 AND 20)
) STRICT;

CREATE TABLE authors (
    author_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 5)
) STRICT;

CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 5)
) STRICT;

CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 20),
    author_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    FOREIGN KEY(author_id) REFERENCES authors(author_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY(category_id) REFERENCES categories(category_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) STRICT;

CREATE TABLE loans (
    loan_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL,
    loan_date TEXT NOT NULL CHECK(
        length(loan_date)=10 AND loan_date GLOB
        '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
    ),
    return_date TEXT CHECK(
        return_date IS NULL OR (
            length(return_date)=10 AND return_date GLOB
            '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
            AND return_date>=loan_date
        )
    ),
    FOREIGN KEY(user_id) REFERENCES users(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY(book_id) REFERENCES books(book_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) STRICT;

-- 미반납 행에만 UNIQUE: 같은 책의 현재 대출 중복을 차단한다.
-- bonus/index_examples.sql의 1번처럼 현재 대출을 book_id로 찾을 때도 후보 인덱스다.
CREATE UNIQUE INDEX one_active_loan_per_book ON loans(book_id)
WHERE return_date IS NULL;
-- 저자별 도서 검색 및 authors 삭제 시 자식 참조 확인. 조회 05/08의 조인에도 활용 가능.
CREATE INDEX idx_books_author_id ON books(author_id);
-- 카테고리별 도서 검색(조회 04), 카테고리 조인·집계(조회 06/09/11).
CREATE INDEX idx_books_category_id ON books(category_id);
-- 회원별 대출 검색·집계(조회 10, 핵심 지표 3) 및 users 삭제 시 자식 참조 확인.
CREATE INDEX idx_loans_user_id ON loans(user_id);
-- 특정 책의 전체 대출 이력 조회, NOT EXISTS(조회 12), books 삭제 시 자식 참조 확인.
CREATE INDEX idx_loans_book_id ON loans(book_id);
-- 대출일 범위 검색 및 최근 대출 정렬(조회 02). return_date 검색용 인덱스는 아니다.
CREATE INDEX idx_loans_loan_date ON loans(loan_date);
-- 작은 데이터에서는 SCAN을 선택할 수 있다. 실제 계획은 index_query_plans.log를 확인한다.
