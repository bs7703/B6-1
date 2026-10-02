# 압축을 푼 폴더에서 실행: source ./db_alias.sh
# Bash / Zsh 공용. Python 3 필요.
# dbreset: 같은 폴더의 library_practice.db 전체 초기화
# dbreset ./practice.db: 지정한 DB 전체 초기화

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' 'Python 3를 설치한 후 다시 실행하세요.' >&2
    return 1
fi
if [ ! -f ./reset_database.py ]; then
    printf '%s\n' 'reset_database.py가 있는 폴더에서 source ./db_alias.sh를 실행하세요.' >&2
    return 1
fi

_dbreset_command=$(python3 -c 'import pathlib, shlex; print("python3 " + shlex.quote(str(pathlib.Path("reset_database.py").resolve())))')
alias dbreset="$_dbreset_command"
unset _dbreset_command
printf '%s\n' 'alias 등록 완료: dbreset 또는 dbreset "DB 경로"'
