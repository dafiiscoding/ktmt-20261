"""Mở trang bằng Chrome/Edge headless (hồ sơ tạm, không đụng hồ sơ thật): chụp ảnh, bấm thử 1 câu MCQ, tải lại xem còn nhớ.
Chạy: python thu_trinh_duyet.py ON-TAP-KTMT.html ảnh.png   (cần ghi trong thư mục tạm của hệ thống)"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TRANG = Path(sys.argv[1]).resolve()
ANH = Path(sys.argv[2]).resolve()
TRINH = next((p for p in [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    shutil.which("chromium") or "",
] if p and Path(p).exists()), None)
assert TRINH, "không thấy Chrome/Edge"

# Bấm đáp án đúng câu đầu rồi tải lại trang; kết quả ghi vào <title> để đọc từ --dump-dom.
THU = """<script>addEventListener('load',()=>setTimeout(()=>{
const loi=[];addEventListener('error',e=>loi.push(e.message));
if(sessionStorage.getItem('thu')){const n=Object.keys(localStorage).filter(k=>k.startsWith('on-tap')).map(k=>localStorage.getItem(k).length);
 document.title='THU|da-tai-lai|luu='+n.join(',')+'|mcq='+document.querySelectorAll('[data-id]').length+'|hinh='+[...document.images].filter(i=>i.naturalWidth>0).length+'/'+document.images.length;return;}
const q=document.querySelector('[data-id]');const nut=q&&q.querySelector('input,button,label');
if(nut){nut.click();}
const gui=q&&[...q.querySelectorAll('button')].find(b=>/kiểm|chấm|trả lời/i.test(b.textContent));if(gui)gui.click();
sessionStorage.setItem('thu','1');location.reload();},300));</script>"""

with tempfile.TemporaryDirectory() as tmp:
    ban = Path(tmp) / TRANG.name
    ban.write_text(TRANG.read_text(encoding="utf-8").replace("</body>", THU + "</body>"), encoding="utf-8")
    chung = [TRINH, "--headless=new", "--disable-gpu", f"--user-data-dir={tmp}/ho-so", "--virtual-time-budget=8000"]
    subprocess.run(chung + [f"--screenshot={ANH}", "--window-size=1280,1600", TRANG.as_uri()], capture_output=True, timeout=120)
    ra = subprocess.run(chung + ["--dump-dom", ban.as_uri()], capture_output=True, timeout=120, encoding="utf-8", errors="replace").stdout

m = re.search(r"<title>(THU\|[^<]*)", ra)
print(m.group(1) if m else "KHÔNG THẤY KẾT QUẢ BẤM THỬ")
print("ảnh:", ANH, ANH.exists())
sys.exit(0 if m and ANH.exists() else 1)
