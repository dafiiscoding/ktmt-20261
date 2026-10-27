# Nạp công cụ portable cho terminal hiện tại (chỉ phiên này, không sửa PATH hệ thống).
#   source tools/env.sh
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$_ROOT/.toolchain/oss-cad-suite/bin:$_ROOT/.toolchain/oss-cad-suite/lib:$PATH"
unset _ROOT
# Verilator: gói Windows cần biết thư mục share (script wrapper `verilator` cần Perl đủ module → dùng thẳng verilator_bin)
export VERILATOR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.toolchain/oss-cad-suite/share/verilator"
alias verilator=verilator_bin
