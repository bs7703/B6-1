
/*
초기 데이터에서 핵심 지표 예상값 (16~17번 실행 전)
1: 전체 30권 / 대출 중 22권 / 대출 가능 8권 / 대출 중 비율 73.33%
2: 전체 185건 / 반납 163건 / 미반납 22건 / 연체 9건 / 오늘 기한 2건 / 기한 전 11건
3: 전체 30명 / 이용 26명 / 미이용 4명 / 현재 대출 11명 / 회원당 평균 6.17건
데이터 수정 및 삭제 후에는 위 지표도 달라진다.
*/

-- 1. 핵심 지표: 도서 가용 현황 (현재 미반납 대출은 책당 최대 1건)
SELECT COUNT(b.book_id) AS total_book_count,
       COUNT(l.loan_id) AS loaned_book_count,
       COUNT(b.book_id) - COUNT(l.loan_id) AS available_book_count,
       ROUND(100.0 * COUNT(l.loan_id) / NULLIF(COUNT(b.book_id), 0), 2)
           AS loaned_book_pct
FROM books AS b
LEFT JOIN loans AS l ON l.book_id = b.book_id AND l.return_date IS NULL;

-- 2. 핵심 지표: 대출 및 연체 현황 (기준일 2026-10-02)
SELECT COUNT(*) AS total_loan_count,
       COALESCE(SUM(CASE WHEN return_date IS NOT NULL THEN 1 ELSE 0 END), 0)
           AS returned_loan_count,
       COALESCE(SUM(CASE WHEN return_date IS NULL THEN 1 ELSE 0 END), 0)
           AS active_loan_count,
       COALESCE(SUM(CASE WHEN return_date IS NULL
                         AND date(loan_date, '+14 days') < '2026-10-02'
                        THEN 1 ELSE 0 END), 0) AS overdue_loan_count,
       COALESCE(SUM(CASE WHEN return_date IS NULL
                         AND date(loan_date, '+14 days') = '2026-10-02'
                        THEN 1 ELSE 0 END), 0) AS due_today_count,
       COALESCE(SUM(CASE WHEN return_date IS NULL
                         AND date(loan_date, '+14 days') > '2026-10-02'
                        THEN 1 ELSE 0 END), 0) AS not_yet_due_count
FROM loans;

-- 3. 핵심 지표: 회원 이용 현황 (이용 회원은 대출 이력이 있는 회원)
SELECT COUNT(*) AS total_user_count,
       COALESCE(SUM(CASE WHEN loan_count > 0 THEN 1 ELSE 0 END), 0)
           AS borrowing_user_count,
       COALESCE(SUM(CASE WHEN loan_count = 0 THEN 1 ELSE 0 END), 0)
           AS never_borrowed_user_count,
       COALESCE(SUM(CASE WHEN active_count > 0 THEN 1 ELSE 0 END), 0)
           AS active_borrower_count,
       ROUND(AVG(loan_count), 2) AS avg_loans_per_user
FROM (
    SELECT u.user_id,
           COUNT(l.loan_id) AS loan_count,
           SUM(CASE
                   WHEN l.loan_id IS NOT NULL AND l.return_date IS NULL THEN 1
                   ELSE 0
               END) AS active_count
    FROM users AS u
    LEFT JOIN loans AS l ON l.user_id = u.user_id
    GROUP BY u.user_id
) AS user_loan_summary;