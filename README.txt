도서관 SQLite 초기화 alias

1. 이 압축 파일을 풀고 VS Code 터미널에서 해당 폴더로 이동합니다.
2. alias 등록: source ./db_alias.sh
3. 기본 DB 초기화: dbreset
4. 다른 DB 초기화: dbreset "/실제/경로/사용중인DB.db"

기본 DB는 reset_database.py와 같은 폴더의 library_practice.db입니다.
지정한 DB의 모든 테이블, 데이터, 인덱스, 뷰, 트리거가 교체됩니다.
create_table.sql → insert_items.sql 순서로 자동 실행됩니다.
두 SQL 파일의 변경 내용은 다음 dbreset 실행에 반영됩니다.
새 DB를 먼저 생성하고 검사한 뒤 대상 DB에 반영합니다.
기존 DB 파일이나 WAL 파일을 직접 삭제하지 않습니다.

필요 환경: Bash 또는 Zsh, Python 3 (내장 SQLite 3.37.0 이상).
별도 sqlite3 명령줄 프로그램 설치는 필요 없습니다.
정상 결과: categories 7, authors 12, users 30, books 30, loans 185, 현재 대출 22.
현재 터미널에서 등록한 alias는 새 터미널을 열면 다시 등록해야 합니다.
계속 사용하려면 위 등록 후 alias dbreset으로 출력된 alias 한 줄을
Zsh는 ~/.zshrc, Bash는 ~/.bashrc에 추가하세요.
macOS의 Bash 로그인 터미널에서는 ~/.bash_profile을 사용할 수 있습니다.
초기화 후 VS Code SQLite 탐색기를 새로고침하거나 DB를 다시 엽니다.
