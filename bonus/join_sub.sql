-- 유저아이디에 대출이 존재하지않는 경우를 join으로 조회하는 쿼리
select u.user_id, u.name
from users u
left join loans l on u.user_id = l.user_id
where l.loan_id is null;

-- 상관쿼리로 유저아이디에 대출이 존재하지않는 경우를 조회하는 쿼리
select u.user_id, u.name
from users u
where not EXISTS (
    select 1
    from loans l
    where l.user_id = u.user_id
);