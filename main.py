import sqlite3

query_유저별_책대여 = """SELECT
    users.user_id,
    users.name,
    COUNT(loans.loan_id) AS total_loan_count,
    SUM(
        CASE
            WHEN loans.return_date IS NULL THEN 1
            ELSE 0
        END
    ) AS active_loan_count
FROM users
LEFT JOIN loans
    ON users.user_id = loans.user_id
GROUP BY users.user_id, users.name;"""

query_현재대출가능한책 = """SELECT books.book_id, books.title
FROM books
LEFT JOIN loans ON books.book_id = loans.book_id
WHERE loans.book_id is NULL
"""

query3 = """
WITH user_loan_counts AS (
    SELECT 
        u.user_id,
        u.name,
        COUNT(l.loan_id) AS loan_count
    FROM users u
    LEFT JOIN loans l ON u.user_id = l.user_id
    GROUP BY u.user_id, u.name
),
avg_loan AS (
    SELECT AVG(cnt) AS avg_count
    FROM user_loan_counts
)
SELECT 
    ulc.user_id,
    ulc.name,
    ulc.loan_count
FROM user_loan_counts ulc
CROSS JOIN avg_loan al
WHERE ulc.cnt > al.avg_count;
"""

query4 = """
SELECT u.user_id AS user_id, u.name AS user_name, COUNT(l.loan_id) as count_all, COUNT(CASE WHEN l.return_date IS NULL THEN 1 end) as count_current
FROM users u
LEFT JOIN loans l ON l.user_id = u.user_id
GROUP BY u.user_id
"""
def main():
    try:
        with sqlite3.connect("app.db") as db:
           cursor = db.cursor()
           cursor.execute(query4)
           results = cursor.fetchall()
           for a in results:
                print(a)
    except Exception as e:
            print(e)

def compile():
    try:
        with sqlite3.connect("app.db") as db:
            with open("creating_table.sql", encoding="utf-8") as file:
                with open("creating_items.sql", encoding="utf-8") as file2:
                    r = file.read()
                    y = file2.read()
                    db.executescript(r)
                    db.executescript(y)
    except Exception as e:
            print(e)

if __name__ == "__main__":
    compile()
    main()