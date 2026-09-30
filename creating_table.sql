PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS authors;


/* ==============================
   1. 테이블 생성
   ============================== */

CREATE TABLE authors (
    author_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
        CHECK (length(name) BETWEEN 1 AND 5)
) STRICT;


CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
        CHECK (length(name) BETWEEN 1 AND 5)
) STRICT;


CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,

    title TEXT NOT NULL
        CHECK (length(title) BETWEEN 1 AND 20),

    author_id INTEGER NOT NULL,

    FOREIGN KEY (author_id)
        REFERENCES authors(author_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) STRICT;


CREATE TABLE loans (
    loan_id INTEGER PRIMARY KEY,

    user_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL, 

    loan_date TEXT NOT NULL
        CHECK (
            length(loan_date) = 10
            AND loan_date GLOB
                '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        ),

    return_date TEXT
        CHECK (
            return_date IS NULL
            OR (
                length(return_date) = 10
                AND return_date GLOB
                    '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                AND return_date >= loan_date
            )
        ),

    FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    FOREIGN KEY (book_id)
        REFERENCES books(book_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) STRICT;
