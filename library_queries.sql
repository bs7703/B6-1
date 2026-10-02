/*
도서관 SQL 조회 예제 — SQLite

대상 테이블: categories, authors, users, books, loans
준비: create_table.sql과 insert_items.sql로 테이블 및 데이터를 생성한다.
실행: 사용할 쿼리의 SELECT/UPDATE/DELETE부터 세미콜론까지 선택해 실행한다.
      이 파일은 조회만 실행한다. 수정 및 삭제는 modify.sql에 분리되어 있다.

날짜 기준: 2026-10-02, 반납기한은 대출일 + 14일로 가정한다.
return_date는 실제 반납일이며, NULL이면 아직 반납하지 않은 상태이다.
기한이 기준일보다 이전이고 미반납인 경우에만 연체로 판단한다.
book_id 하나는 책 한 권을 나타낸다.

이 파일: 조회 12개. 전체 제출물은 bonus/core.sql 3개 + modify.sql 2개 = 총 17개.

[기본 조회: 4개]
01. 회원 검색             : 이름이 '김'으로 시작하는 회원을 ID순으로 조회한다.
02. 최근 미반납 대출      : 미반납 대출 중 최근 5건을 조회한다.
03. 기간별 반납 내역      : 2026년 8월에 반납한 대출을 조회한다.
04. 과학 도서 검색        : 과학 카테고리(ID 5)의 책을 제목순으로 조회한다.

[조인: 4개]
05. 도서와 저자           : INNER JOIN으로 책 제목과 저자 이름을 조회한다.
06. 도서와 카테고리       : INNER JOIN으로 책 제목과 카테고리를 조회한다.
07. 미반납 상세 내역      : INNER JOIN으로 회원, 책, 기한, 연체 상태를 조회한다.
08. 등록 도서 없는 저자   : LEFT JOIN으로 책이 없는 저자도 찾아낸다.

[집계: 3개]
09. 카테고리별 도서 수    : GROUP BY와 COUNT로 카테고리별 책 수를 계산한다.
10. 회원별 대출 실적      : GROUP BY, COUNT, SUM으로 전체/미반납 건수를 계산한다.
11. 카테고리별 이용 기간  : GROUP BY, COUNT, SUM, AVG로 반납 도서 이용일을 계산한다.

[서브쿼리: 1개]
12. 대출 이력 없는 도서   : NOT EXISTS 서브쿼리로 한 번도 빌리지 않은 책을 찾는다.

*/

-- 01. 회원 검색: 이름이 '김'으로 시작하는 회원
SELECT user_id, name
FROM users
WHERE name LIKE '김%'
ORDER BY user_id;

-- 02. 최근 미반납 대출: 최신 대출 5건
SELECT loan_id, user_id, book_id, loan_date, return_date
FROM loans
WHERE return_date IS NULL
ORDER BY loan_date DESC, loan_id DESC
LIMIT 5;

-- 03. 기간별 반납 내역: 2026년 8월 반납 기록
SELECT loan_id, user_id, book_id, loan_date, return_date
FROM loans
WHERE return_date >= '2026-08-01'
  AND return_date < '2026-09-01'
ORDER BY return_date, loan_id;

-- 04. 과학 도서 검색: 카테고리 5번의 책
SELECT book_id, title, author_id, category_id
FROM books
WHERE category_id = 5
ORDER BY title, book_id;

-- 05. 도서와 저자: INNER JOIN
SELECT b.book_id, b.title, a.name AS author_name
FROM books AS b
INNER JOIN authors AS a ON a.author_id = b.author_id
ORDER BY b.book_id;

-- 06. 도서와 카테고리: INNER JOIN
SELECT b.book_id, b.title, c.name AS category_name
FROM books AS b
INNER JOIN categories AS c ON c.category_id = b.category_id
ORDER BY c.category_id, b.book_id;

-- 07. 미반납 상세 내역: 회원·도서 조인과 연체 상태
SELECT l.loan_id,
       u.user_id,
       u.name AS user_name,
       b.title AS book_title,
       l.loan_date,
       date(l.loan_date, '+14 days') AS due_date,
       l.return_date,
       CASE
           WHEN date(l.loan_date, '+14 days') < '2026-10-02' THEN '연체'
           WHEN date(l.loan_date, '+14 days') = '2026-10-02' THEN '오늘 기한'
           ELSE '기한 전'
       END AS loan_status
FROM loans AS l
INNER JOIN users AS u ON u.user_id = l.user_id
INNER JOIN books AS b ON b.book_id = l.book_id
WHERE l.return_date IS NULL
ORDER BY due_date, l.loan_id;

-- 08. 등록 도서 없는 저자: LEFT JOIN의 미일치 행 조회
-- LEFT JOIN이 만든 미일치 행에서는 오른쪽 b.book_id가 NULL이다. 저자 8번 1행이 나온다.
SELECT a.author_id, a.name AS author_name
FROM authors AS a
LEFT JOIN books AS b ON b.author_id = a.author_id
WHERE b.book_id IS NULL
ORDER BY a.author_id;

-- 09. 카테고리별 도서 수: 책이 없는 카테고리도 0권으로 표시
-- COUNT(*)는 미일치 행도 센다. COUNT(b.book_id)는 NULL을 제외해 카테고리 8~10을 0권으로 센다.
SELECT c.category_id,
       c.name AS category_name,
       COUNT(b.book_id) AS book_count
FROM categories AS c
LEFT JOIN books AS b ON b.category_id = c.category_id
GROUP BY c.category_id, c.name
ORDER BY book_count DESC, c.category_id;

-- 10. 회원별 대출 실적: 전체 대출과 미반납 건수
-- 동명이인은 user_id로 구분한다. COUNT는 loan_id의 NULL을 제외한다.
-- CASE에서 loan_id 존재도 확인해야 대출 없는 회원의 미일치 행을 미반납 1건으로 잘못 세지 않는다.
SELECT u.user_id,
       u.name AS user_name,
       COUNT(l.loan_id) AS total_loan_count,
       SUM(CASE
               WHEN l.loan_id IS NOT NULL AND l.return_date IS NULL THEN 1
               ELSE 0
           END) AS active_loan_count
FROM users AS u
LEFT JOIN loans AS l ON l.user_id = u.user_id
GROUP BY u.user_id, u.name
ORDER BY total_loan_count DESC, u.user_id;

-- 11. 카테고리별 이용 기간: 반납 완료 건의 합계와 평균 이용일
-- SUM/AVG는 NULL을 제외한다. 반납 기록이 없으면 합계는 COALESCE로 0, 평균은 NULL을 유지한다.
-- 평균 NULL은 관측 없음이며, 실제 평균 이용일 0일과 다르다. 반납 조건을 ON에 두어 빈 범주를 보존한다.
SELECT c.category_id,
       c.name AS category_name,
       COUNT(l.loan_id) AS returned_loan_count,
       COALESCE(SUM(julianday(l.return_date) - julianday(l.loan_date)), 0)
           AS total_loan_days,
       ROUND(AVG(julianday(l.return_date) - julianday(l.loan_date)), 2)
           AS avg_loan_days
FROM categories AS c
LEFT JOIN books AS b ON b.category_id = c.category_id
LEFT JOIN loans AS l ON l.book_id = b.book_id AND l.return_date IS NOT NULL
GROUP BY c.category_id, c.name
ORDER BY c.category_id;

-- 12. 대출 이력 없는 도서: NOT EXISTS 서브쿼리
-- 바깥 책 b마다 대출 l이 존재하는지 확인한다. 한 건이라도 있으면 제외한다. 결과는 도서 30번 1행.
SELECT b.book_id, b.title
FROM books AS b
WHERE NOT EXISTS (
    SELECT 1
    FROM loans AS l
    WHERE l.book_id = b.book_id
)
ORDER BY b.book_id;
