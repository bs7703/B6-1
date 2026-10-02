
/*
[데이터 수정 및 삭제: 2개]
전체 17개 중 수정 2개를 이 파일에 분리했다. 조회 실행만으로 데이터가 바뀌지 않는다.
초기 데이터에 한 번 실행하면 대출 184건, 미반납 21건이 된다.
다시 실행하면 조건에 맞는 행이 없으므로 RETURNING 결과가 0행이다.
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
