# Prompt KTMT: Gemini nhập, máy kiểm, Codex sửa, Claude soát

Chạy từ `hoc-tap/ktmt-2026-1-casio`. Thay `<n>` bằng số phiên (K2…K6) và `<bài>` bằng bài của phiên đó (xem PLAN §2, §5.2).
Bài mẫu A2 (phiên K2) **không** qua Gemini: đi thẳng bước 3 với prompt K2 trong PLAN §6.4, để Codex viết, Claude soát, Long duyệt khuôn. Từ K3 trở đi mới dùng cả 4 bước.

## Bước 1. Gemini nhập bản nháp

Thử trước (Long chạy): `agy -p "đếm số dòng file learn/on-tap-btl/PLAN.md" --print-timeout 120s`. Treo thì dừng, dùng thẳng Codex (Bước 3 làm cả việc nhập).

Lưu prompt dưới thành `p1.md`, rồi `agy -p "$(cat p1.md)" --print-timeout 600s` (cú pháp theo `agy --help` ở máy Long).

```
Bạn nhập bản nháp một bài của bộ ôn. Chỉ làm đúng việc này, không quét thư mục khác.
Đọc: learn/on-tap-btl/PLAN.md §3 (luật cứng, mục Người đọc), §5.1 (khuôn 9 mục), §5.3 và §5.4 (dàn bài <bài>), §5.2 (nguồn của bài).
Đọc bài A2 trong learn/on-tap-btl/nguon/01-khoi-a.md để lấy độ dày và giọng văn.
Đọc đúng các file nguồn ghi ở §5.2 cho <bài>. Không đọc file nào khác.

Viết bài <bài> vào learn/on-tap-btl/nguon/<file khối theo §5.2>, đúng khuôn 9 mục.
Luật:
1. Số, tên file, tên lệnh chỉ lấy từ nguồn đã đọc. Số viết bằng {{so:ID}} (ID có sẵn trong so_ktmt.py). Thiếu nguồn thì viết nguyên dòng <LONG: thiếu nguồn cho ...>, KHÔNG tự bịa.
2. Người đọc chưa có kiến thức nền: mỗi từ chuyên môn giải thích ngay chỗ xuất hiện, hình dung đời thường trước rồi mới tới tên kỹ thuật.
3. Mỗi câu hỏi (MCQ, thẻ, vấn đáp) phải có lời giải đầy đủ ngay dưới nó.
4. Không đưa ký hiệu §, chữ PLAN, lời nhắc người dạy vào bài.
5. Chỉ ghi vào file nguon/ của bài này. Không sửa dung.py, kiem/, so_ktmt.py. Không commit.
Xong thì in: tên file đã ghi, số dòng, và danh sách mọi chỗ bạn phải đoán.
```

## Bước 2. Máy kiểm (Long chạy, 10 giây)

```
cd learn/on-tap-btl
python so_ktmt.py ; python dung.py --check > loi.txt 2>&1 ; python kiem/noi_dung.py >> loi.txt 2>&1 ; type loi.txt
```

`loi.txt` là đầu vào của Bước 3. Không có lỗi nào mà vẫn qua Bước 3, vì Codex còn phải đối chiếu nguồn.

## Bước 3. Codex sửa

Mở `codex` ở `hoc-tap/ktmt-2026-1-casio` rồi dán.

```
Đọc .ai/state.md, đuôi .ai/worklog.md, rồi learn/on-tap-btl/PLAN.md §3, §5.1–§5.4, §6, §9.
Bài <bài> trong learn/on-tap-btl/nguon/ do model khác nhập nháp. Bạn không viết lại từ đầu, bạn sửa cho đúng.
1. Đọc learn/on-tap-btl/loi.txt, sửa hết lỗi máy kiểm báo.
2. Với từng khẳng định kỹ thuật trong bài (số, tên tín hiệu, thứ tự chu kỳ, kết quả lệnh): mở file nguồn ở §5.2, đối chiếu. Sai thì sửa theo nguồn. Chỗ có <LONG: thiếu nguồn> mà bạn tìm được nguồn thì điền, không tìm được thì giữ nguyên.
3. Đọc lại như người chưa học ngành: từ nào chưa giải thích thì giải thích, câu hỏi nào chưa có lời giải đầy đủ thì thêm, hình dung đời thường nào sai bản chất thì thay.
4. Chạy đủ §6.1 (có thử nghiệm lệnh trong bài nếu bài có lệnh). Không sửa kiem/noi_dung.py, dung.py. Chỉ ghi trong learn/on-tap-btl/ và .ai/. Không commit.
Báo theo §6.2, thêm 1 bảng: mỗi chỗ đã sửa gồm (vị trí | bản nháp viết gì | nguồn nói gì | đã sửa thành).
```

## Bước 4. Claude soát (dán cho Claude)

```
Soát phiên K<n> trong hoc-tap/ktmt-2026-1-casio theo PLAN.md §9 của learn/on-tap-btl.
Bản nháp do Gemini nhập, Codex sửa. Đọc thẳng nguon/, không tin báo cáo, tự chạy lại §6.1 và lệnh test của bài.
Đối chiếu từng khẳng định kỹ thuật với code. Bắt đầu từ bảng "đã sửa" của Codex để biết Gemini hay sai kiểu nào, rồi tìm chỗ cùng kiểu mà Codex bỏ sót.
Tìm: giải thích sơ sài, từ chuyên môn chưa giải thích, hình dung đời thường sai bản chất, số gõ tay, ý ở PLAN §5.4 bị thiếu. Đọc thử như người ngoài ngành. Báo trước, chưa sửa.
```

## Phiên K3 điền sẵn (09/11)
Thư mục `prompts-k3/` (chỉ làm sau khi Long duyệt khuôn A2):
1. Gemini, mỗi bài một lần: `p1-A1.md`, `p1-A3.md`, `p1-A4.md`, `p1-A5.md`. Mỗi bài ghi vào `nguon/nhap-<bài>.txt`, không đụng `01-khoi-a.md`.
2. Máy kiểm: giữ nguyên Bước 2 ở trên, nhưng chưa có gì để kiểm vì file nháp là `.txt`; Codex chạy sau khi ghép.
3. Codex: `p3-k3.md` (ghép, sửa, chạy đột biến thật, viết `kiem/A1…A5.py`, đề nhanh 25 MCQ).
4. Claude: `p4-k3.md`.
