
/*
[데이터 수정 및 삭제: 2개]
13. 반납 처리             : UPDATE로 미반납 대출 164번의 실제 반납일을 기록한다.
14. 과거 대출 한 건 삭제  : DELETE로 반납 완료된 대출 1번을 삭제한다.
*/

-- 13. 반납 처리: 미반납 대출 164번의 실제 반납일 기록 (데이터 변경)
UPDATE loans
SET return_date = '2026-10-02'
WHERE loan_id = 164
  AND return_date IS NULL
  AND loan_date <= '2026-10-02'
RETURNING loan_id, user_id, book_id, loan_date, return_date;

-- 14. 과거 대출 한 건 삭제: 반납 완료된 대출 1번만 삭제 (데이터 변경)
DELETE FROM loans
WHERE loan_id = 1
  AND return_date IS NOT NULL
RETURNING loan_id, user_id, book_id, loan_date, return_date;
