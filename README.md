# BTL KTMT — Đồng hồ điện tử WatchChip: SoC + CPU MIPS 32-bit tự thiết kế (Verilog, chỉ mô phỏng)

Đồ án môn MI4344, nhóm chốt đề 01/10/2026. Nhóm tự thiết kế cả con chip của một chiếc đồng hồ điện tử trên FPGA,
đi từ hiển thị → chip (timers, bus, ngắt) → CPU MIPS32-subset (single-cycle → pipeline 5 tầng) → ALU.
Chức năng: xem/chỉnh giờ, bấm giờ, đếm ngược tới ms rồi đếm tiếp sang âm, báo thức, đồng bộ giờ qua PC.
Câu hỏi kiến trúc trung tâm: **muốn chuẩn tới ms thì phần nào phải là phần cứng?**

- **Spec + phân công + lịch:** `PLAN_DONG_HO.md` (v5.0).
- **Cách làm việc, báo cáo, cổng bảo vệ:** `KE-HOACH-LAM-VIEC.md`.
- **Gói việc (output, test, tiêu chí xong cho từng người):** `docs/goi-viec.md`.
- **6 file hợp đồng (bản nháp, freeze S1′):** `docs/isa-spec.md` · `docs/control-table.md` · `docs/pipeline-policy.md` · `docs/mmio-map.md` · `docs/timer-spec.md` · `docs/display-spec.md`.
- **Cài môi trường (portable):** `bash tools/setup_env.sh`, rồi mỗi terminal `source tools/env.sh`.
- **Test vector:** `python tb/vectors/gen_vectors.py` (sinh lại + tự kiểm golden 2 cách).
- **Cây repo:** `src/` Verilog · `tb/` testbench · `tools/` asm/ISS + `setup_env.sh` · `fw/` assembly · `evidence/` log + số đo · `report/` báo cáo.
- **Ngân hàng câu hỏi cổng bảo vệ:** `docs/ngan-hang-cau-hoi.md`.
- **Trạng thái:** `.ai/state.md` · **Lịch sử:** `.ai/worklog.md`.
