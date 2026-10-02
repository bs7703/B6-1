-- 각 인덱스의 대표 검색과 실제 실행 계획. 작은 표의 실행 시간 개선을 보장하는 벤치마크는 아니다.

-- 1. 현재 대출 검색: 부분 UNIQUE 인덱스
EXPLAIN QUERY PLAN
SELECT loan_id FROM loans WHERE book_id = 1 AND return_date IS NULL;

-- 2. 저자별 책 검색: idx_books_author_id
EXPLAIN QUERY PLAN
SELECT book_id FROM books WHERE author_id = 1;

-- 3. 카테고리별 책 검색: idx_books_category_id
EXPLAIN QUERY PLAN
SELECT book_id FROM books WHERE category_id = 5;

-- 4. 회원별 대출 검색: idx_loans_user_id
EXPLAIN QUERY PLAN
SELECT loan_id FROM loans WHERE user_id = 1;

-- 5. 책의 모든 대출 이력 검색: idx_loans_book_id
EXPLAIN QUERY PLAN
SELECT loan_id FROM loans WHERE book_id = 1;

-- 6. 대출일 범위 검색과 정렬: idx_loans_loan_date
EXPLAIN QUERY PLAN
SELECT loan_id FROM loans
WHERE loan_date >= '2026-09-01' AND loan_date < '2026-10-01'
ORDER BY loan_date;
