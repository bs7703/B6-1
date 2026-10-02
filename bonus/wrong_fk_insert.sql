PRAGMA foreign_keys = ON;
-- category_id=11은 카테고리 1~10에 존재하지 않으므로 FK 오류가 나야 한다.
-- 한 번의 삽입이 실패하는 확인용 파일이며 실제 책·저자 관계를 나타내지 않는다.
insert into books (book_id, title, author_id, category_id)
values (32, '외래키 검증용', 5, 11);
