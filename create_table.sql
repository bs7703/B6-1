-- 카테고리를 포함한 도서관 학습용 구조. SQLite 3.37.0 이상.
-- 새 빈 DB에서 파일 전체를 한 번 실행하세요.
-- 기존 books 테이블에 category_id를 추가하는 마이그레이션 파일은 아닙니다.
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

CREATE UNIQUE INDEX one_active_loan_per_book ON loans(book_id)
WHERE return_date IS NULL;
CREATE INDEX idx_books_author_id ON books(author_id);
CREATE INDEX idx_books_category_id ON books(category_id);
CREATE INDEX idx_loans_user_id ON loans(user_id);
CREATE INDEX idx_loans_book_id ON loans(book_id);
CREATE INDEX idx_loans_loan_date ON loans(loan_date);
