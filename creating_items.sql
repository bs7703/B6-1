

/*
현재 대출 중인 책은 동시에 한 사람만 빌릴 수 있다.
return_date가 NULL인 행에만 UNIQUE가 적용된다.
*/
CREATE UNIQUE INDEX one_active_loan_per_book
ON loans(book_id)
WHERE return_date IS NULL;


/* 조회 성능을 위한 인덱스 */
CREATE INDEX idx_books_author_id
ON books(author_id);

CREATE INDEX idx_loans_user_id
ON loans(user_id);

CREATE INDEX idx_loans_book_id
ON loans(book_id);

CREATE INDEX idx_loans_loan_date
ON loans(loan_date);


/* ==============================
   2. 저자 30명 생성
   작가001 ~ 작가030
   각각 5글자 이하
   ============================== */

WITH RECURSIVE sequence(number) AS (
    SELECT 1

    UNION ALL

    SELECT number + 1
    FROM sequence
    WHERE number < 30
)
INSERT INTO authors (author_id, name)
SELECT
    number,
    printf('작가%03d', number)
FROM sequence;


/* ==============================
   3. 사용자 60명 생성
   회원001 ~ 회원060
   각각 5글자 이하
   ============================== */

WITH RECURSIVE sequence(number) AS (
    SELECT 1

    UNION ALL

    SELECT number + 1
    FROM sequence
    WHERE number < 60
)
INSERT INTO users (user_id, name)
SELECT
    number,
    printf('회원%03d', number)
FROM sequence;


/* ==============================
   4. 책 90권 생성
   저자 한 명당 책 3권
   ============================== */

WITH RECURSIVE sequence(number) AS (
    SELECT 1

    UNION ALL

    SELECT number + 1
    FROM sequence
    WHERE number < 90
)
INSERT INTO books (book_id, title, author_id)
SELECT
    number,
    printf('도서%03d', number),

    /*
    book 1~3   → author 1
    book 4~6   → author 2
    ...
    book 88~90 → author 30
    */
    ((number - 1) / 3) + 1
FROM sequence;


/* ==============================
   5. 반납 완료된 과거 대출 180건
   책 한 권마다 과거 대출 2건
   ============================== */

WITH RECURSIVE sequence(number) AS (
    SELECT 1

    UNION ALL

    SELECT number + 1
    FROM sequence
    WHERE number < 180
)
INSERT INTO loans (
    loan_id,
    user_id,
    book_id,
    loan_date,
    return_date
)
SELECT
    number,

    /* 사용자 1~60을 순환 */
    ((number - 1) % 60) + 1,

    /* 책 1~90을 순환 */
    ((number - 1) % 90) + 1,

    /* 대출일 */
    date(
        '2025-01-01',
        printf('+%d days', number - 1)
    ),

    /* 대출일로부터 7~20일 뒤 반납 */
    date(
        '2025-01-01',
        printf(
            '+%d days',
            (number - 1) + 7 + (number % 14)
        )
    )
FROM sequence;


/* ==============================
   6. 현재 대출 중인 기록 45건
   책 1~45는 현재 대출 중
   return_date는 NULL
   ============================== */

WITH RECURSIVE sequence(number) AS (
    SELECT 1

    UNION ALL

    SELECT number + 1
    FROM sequence
    WHERE number < 45
)
INSERT INTO loans (
    loan_id,
    user_id,
    book_id,
    loan_date,
    return_date
)
SELECT
    180 + number,
    ((number * 7 - 1) % 60) + 1,
    number,
    date(
        '2026-09-01',
        printf('+%d days', (number - 1) % 14)
    ),
    NULL
FROM sequence;