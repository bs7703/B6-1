#!/usr/bin/env python3
"""실제 검증 결과 JSON을 PNG로 렌더링한다. VS Code 화면 캡처가 아니다.

먼저 python3 verify_submission.py 실행. 이 선택 스크립트에만 Pillow가 필요하다.
전체 한글 결과는 result_log/*.log에 있으며 이미지는 숫자 지표와 ID 열을 표시한다.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
OUTPUT = ROOT / "docs" / "images"


def render(title, lines, destination):
    try:
        regular = ImageFont.truetype(FONT, 20)
        heading = ImageFont.truetype(FONT, 25)
    except OSError:
        regular = ImageFont.load_default(size=20)
        heading = ImageFont.load_default(size=25)
    image = Image.new("RGB", (1150, 140 + len(lines) * 34), "#f7f9fc")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 1150, 90), fill="#182b46")
    draw.text((34, 25), title, font=heading, fill="white")
    for index, line in enumerate(lines):
        draw.text((34, 112 + index * 34), line, font=regular, fill="#152945")
    image.save(destination)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    evidence = json.loads((ROOT / "result_log/evidence_results.json").read_text(encoding="utf-8"))
    lines = [f"Engine: {evidence['engine']} / SQLite {evidence['sqlite_version']}",
             "Reference date: 2026-10-02; initial data", ""]
    for number, item in enumerate(evidence["core"], 1):
        lines.append(f"Core query {number} / actual result")
        lines.extend(f"  {name:<31} {value}" for name, value in zip(item["columns"], item["rows"][0]))
        lines.append("")
    lines.append("Rendered from actual query rows; not a VS Code screenshot.")
    render("SQLite core metrics - result snapshot", lines, OUTPUT / "core_metrics.png")

    inner, left = evidence["inner_join"], evidence["left_join"]
    zero = [row for row in evidence["category_counts"]["rows"] if row[2] == 0]
    lines = [f"Engine: {evidence['engine']} / SQLite {evidence['sqlite_version']}", "",
             f"Q05 INNER JOIN: {len(inner['rows'])} rows", "  book_id (first 5 rows)"]
    lines.extend(f"  {row[0]}" for row in inner["rows"][:5])
    lines.extend(["", f"Q08 LEFT JOIN + IS NULL: {len(left['rows'])} unmatched author", "  author_id"])
    lines.extend(f"  {row[0]}" for row in left["rows"])
    lines.extend(["", "Q09 LEFT JOIN + COUNT: categories without books", "  category_id  book_count"])
    lines.extend(f"  {row[0]:<12} {row[2]}" for row in zero)
    lines.extend(["", "Numeric columns only; full Korean rows: query_results.log",
                  "Rendered from actual query rows; not a VS Code screenshot."])
    render("SQLite joins - result snapshot", lines, OUTPUT / "join_results.png")
    print("Result snapshots:", OUTPUT)


if __name__ == "__main__":
    main()
