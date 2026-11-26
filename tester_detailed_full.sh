#!/usr/bin/env bash
# =============================================================================
#  push_swap tester : norminette + Makefile + mandatory + bonus + both + leaks
#
#  Usage:   ./tester.sh [options] [project_dir]
#     --only STEP    norm | mandatory | bonus | both | all
#                    both = mandatory + bonus + integration; all also runs norminette
#     --runs N       random runs per benchmark / differential test (default 20)
#     --no-norm      skip norminette
#     --no-mem       skip valgrind / leaks
#     --full         also test all 720 permutations of 6 numbers
#     --keep-logs    keep the temp directory
#     --verbose      print every individual PASS/FAIL test
#     --no-manual    skip README / defense checklist prompts
#  Env:    CK_OFFICIAL=/path/to/checker_linux   (optional, cross-check)
# =============================================================================

RUNS=20; ONLY=all; NORM=1; MEM=1; FULL=0; KEEP=0; VERBOSE=0; MANUAL=1; DIR=.
PS=./push_swap; CK=./checker
CURRENT_TEST=""
test_name(){ CURRENT_TEST="$1"; }
OPS_LIST="sa sb ss pa pb ra rb rr rra rrb rrr"
FLAGS_ALL=("" "--simple" "--medium" "--complex" "--adaptive")
TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_WARN=0; FAILED_GROUPS=()
STAGE=""; gname=""; gp=0; gf=0; gdetails=(); MAXOPS=0; LAST_OPS=0; WARNED_CLASS=0; MSG=""

if [ -t 1 ]; then
  G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'
else G=; R=; Y=; B=; D=; N=; fi

# ----------------------------------------------------------------- reporting
stage(){ STAGE="$1"; printf "\n%s══ %s ══%s\n" "$B" "$1" "$N"; }
gbegin(){ gname="$1"; CURRENT_TEST="$1"; gp=0; gf=0; gdetails=(); MAXOPS=0; WARNED_CLASS=0; }
gok(){
  gp=$((gp+1))
  if [ "$VERBOSE" -eq 1 ]; then
    printf "    %s[PASS]%s %s\n" "$G" "$N" "${CURRENT_TEST:-$gname}"
  fi
}
gko(){
  gf=$((gf+1))
  gdetails+=("$1")
  printf "    %s[FAIL]%s %s: %s\n" "$R" "$N" "${CURRENT_TEST:-$gname}" "$1"
}
gend(){
  if [ "$gf" -eq 0 ]; then
    printf "  %s✔%s %-64s %s(%s)%s\n" "$G" "$N" "$gname" "$D" "$gp" "$N"
  else
    printf "  %s✘%s %-64s %s(%s failed / %s)%s\n" "$R" "$N" "$gname" "$R" "$gf" "$((gp+gf))" "$N"
    local d; for d in "${gdetails[@]}"; do printf "      %s↳%s %s\n" "$R" "$N" "$d"; done
    FAILED_GROUPS+=("[$STAGE] $gname")
  fi
  TOTAL_PASS=$((TOTAL_PASS+gp)); TOTAL_FAIL=$((TOTAL_FAIL+gf))
}
warn(){ TOTAL_WARN=$((TOTAL_WARN+1)); printf "  %s!%s %s\n" "$Y" "$N" "$1"; }
info(){ printf "  %s·%s %s\n" "$B" "$N" "$1"; }

# ------------------------------------------------------------------- helpers
mtime(){ stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }
trunc(){ local s="$*"; [ "${#s}" -gt 100 ] && s="${s:0:100}..."; echo "$s"; }
ps_exists(){ [ -x "$PS" ]; }

# Reference simulator of the 11 operations (stack a = args, top first).
AWK_VERIFY='
function sa_(  x){ if(ahi-alo>=1){x=A[alo];A[alo]=A[alo+1];A[alo+1]=x} }
function sb_(  x){ if(bhi-blo>=1){x=B[blo];B[blo]=B[blo+1];B[blo+1]=x} }
function pa_(  x){ if(bhi>=blo){x=B[blo];delete B[blo];blo++;A[--alo]=x} }
function pb_(  x){ if(ahi>=alo){x=A[alo];delete A[alo];alo++;B[--blo]=x} }
function ra_(  x){ if(ahi-alo>=1){x=A[alo];delete A[alo];alo++;A[++ahi]=x} }
function rb_(  x){ if(bhi-blo>=1){x=B[blo];delete B[blo];blo++;B[++bhi]=x} }
function rra_(  x){ if(ahi-alo>=1){x=A[ahi];delete A[ahi];ahi--;A[--alo]=x} }
function rrb_(  x){ if(bhi-blo>=1){x=B[bhi];delete B[bhi];bhi--;B[--blo]=x} }
BEGIN{ n=split(list,t," "); alo=1; ahi=n; for(i=1;i<=n;i++)A[i]=t[i]+0; blo=1; bhi=0; isbad=0 }
{ o=$0
  if(o=="sa")sa_(); else if(o=="sb")sb_(); else if(o=="ss"){sa_();sb_()}
  else if(o=="pa")pa_(); else if(o=="pb")pb_();
  else if(o=="ra")ra_(); else if(o=="rb")rb_(); else if(o=="rr"){ra_();rb_()}
  else if(o=="rra")rra_(); else if(o=="rrb")rrb_(); else if(o=="rrr"){rra_();rrb_()}
  else { isbad=1; bad=o; exit } }
END{ if(isbad){print "BADOP[" bad "]"; exit}
     if(bhi>=blo){print "KO"; exit}
     for(i=alo;i<ahi;i++) if(A[i]>A[i+1]){print "KO"; exit}
     print "OK" }'
verify(){ local f="$1"; shift; awk -v list="$*" "$AWK_VERIFY" "$f"; }

disorder_of(){ awk -v list="$*" 'BEGIN{n=split(list,a," ");m=0;t=0;for(i=1;i<=n;i++)for(j=i+1;j<=n;j++){t++;if(a[i]+0>a[j]+0)m++} if(t==0)printf "0.00"; else printf "%.2f",100*m/t}'; }

rand_list(){ awk -v n="$1" -v s="$RANDOM$RANDOM" 'BEGIN{srand(s);m=n*3;for(i=0;i<m;i++)p[i]=i-n;for(i=m-1;i>0;i--){j=int(rand()*(i+1));t=p[i];p[i]=p[j];p[j]=t}for(i=0;i<n;i++)printf "%d ",p[i];print ""}'; }
gen_target(){ awk -v n="$1" -v tg="$2" -v s="$RANDOM$RANDOM" 'BEGIN{srand(s);for(i=1;i<=n;i++)a[i]=i-int(n/2);
  while(1){inv=0;for(i=1;i<=n;i++)for(j=i+1;j<=n;j++)if(a[i]>a[j])inv++; if(inv/(n*(n-1)/2)>=tg)break;
    for(c=0;c<3;c++){i=int(rand()*n)+1;j=int(rand()*n)+1;t=a[i];a[i]=a[j];a[j]=t}}
  for(i=1;i<=n;i++)printf "%d ",a[i];print ""}'; }
mk_list(){ case "$1" in
  sorted) seq 1 "$2" | tr '\n' ' ';; reverse) seq "$2" -1 1 | tr '\n' ' ';;
  low) gen_target "$2" 0.10;; mid) gen_target "$2" 0.30;; random) rand_list "$2";; esac; echo; }
rand_ops(){ awk -v k="$1" -v s="$RANDOM$RANDOM" 'BEGIN{srand(s);split("sa sb ss pa pb ra rb rr rra rrb rrr",o," ");for(i=0;i<k;i++)print o[int(rand()*11)+1]}'; }
mutate(){ awk -v s="$RANDOM$RANDOM" 'BEGIN{srand(s);mode=int(rand()*4)} {l[NR]=$0}
  END{ if(NR>0){i=int(rand()*NR)+1; if(mode==2)l[i]=l[i] "\n" l[i]; else if(mode==3&&i<NR){t=l[i];l[i]=l[i+1];l[i+1]=t}}
       for(j=1;j<=NR;j++) if(!(mode==1&&j==i)) print l[j] }'; }
permute(){ local pre="$1"; shift
  if [ $# -eq 0 ]; then echo "$pre"; return; fi
  local i x; for ((i=1;i<=$#;i++)); do x=${!i}; permute "$pre $x" "${@:1:i-1}" "${@:i+1}"; done; }
class_of(){ case "$1" in *log*) echo nlogn;; *√*|*sqrt*) echo nsqrtn;; *'n^2'*|*'n²'*|*'n2'*|*'n*n'*) echo n2;; *) echo "?";; esac; }

TMO=""
if command -v timeout >/dev/null 2>&1; then TMO="timeout 10"; elif command -v gtimeout >/dev/null 2>&1; then TMO="gtimeout 10"; fi
TMO_MEM="${TMO/10/180}"

ps_run(){ $TMO $PS "$@" >"$LOG/out" 2>"$LOG/err"; PS_RC=$?; }
ck_run(){ local in="$1"; shift; $TMO $CK "$@" <"$in" >"$LOG/out" 2>"$LOG/err"; CK_RC=$?; }

# core "valid input must be sorted" test: returns 0/1, sets MSG
t_core(){
  local label="$1" flags="$2" v; shift 2
  ps_run $flags "$@"
  if [ "$PS_RC" -eq 124 ]; then MSG="$label: TIMEOUT -> $PS $flags $(trunc "$*")"; return 1; fi
  if [ "$PS_RC" -ge 128 ]; then MSG="$label: CRASH rc=$PS_RC -> $PS $flags $(trunc "$*")"; echo "$PS $flags $*" >>"$LOG/fails.txt"; return 1; fi
  if [ "$PS_RC" -ne 0 ]; then MSG="$label: exit code $PS_RC on valid input -> $PS $flags $(trunc "$*")"; return 1; fi
  if [ -s "$LOG/err" ]; then MSG="$label: stderr not empty ($(head -c 50 "$LOG/err")) -> $PS $flags $(trunc "$*")"; return 1; fi
  if [ -s "$LOG/out" ] && [ "$(tail -c1 "$LOG/out" | od -An -c | tr -d ' ')" != '\n' ]; then MSG="$label: output must end with \\n"; return 1; fi
  v=$(verify "$LOG/out" "$@")
  if [ "$v" != OK ]; then MSG="$label: result $v -> $PS $flags $(trunc "$*")"; echo "$PS $flags $*" >>"$LOG/fails.txt"; return 1; fi
  LAST_OPS=$(wc -l <"$LOG/out" | tr -d ' ')
  [ "$LAST_OPS" -gt "$MAXOPS" ] && MAXOPS=$LAST_OPS
  return 0
}
t_sort(){
  test_name "$1 | flags='$2' | args='${*:3}'"
  if t_core "$@"; then gok; else gko "$MSG"; fi
}
t_zero(){
  test_name "$1 | flags='$2' | args='${*:3}'"
  if t_core "$@"; then
    if [ "$LAST_OPS" -eq 0 ]; then gok; else gko "$1: already sorted but $LAST_OPS ops printed ($PS $2 $(trunc "${*:3}"))"; fi
  else gko "$MSG"; fi
}

t_error(){ # args...  -> must print nothing on stdout, exactly "Error\n" on stderr
  test_name "invalid args: $*"
  ps_run "$@"
  if [ "$PS_RC" -eq 124 ]; then gko "TIMEOUT on [$*]"; return; fi
  if [ "$PS_RC" -ge 128 ]; then gko "CRASH rc=$PS_RC on [$*]"; return; fi
  printf 'Error\n' >"$LOG/exp_e"
  if [ -s "$LOG/out" ]; then gko "stdout not empty on [$*]"; return; fi
  if ! cmp -s "$LOG/err" "$LOG/exp_e"; then gko "[$*] -> stderr='$(head -c 40 "$LOG/err")' (want 'Error\\n')"; return; fi
  gok
}

kv(){ sed -n "s/^$1=//p" "$LOG/kv" | head -1; }
t_bench(){ # label "flags incl --bench" stack...
  local label="$1" flags="$2" d tot real k act c exp_d sl got want dn; shift 2
  test_name "bench $label | flags='$flags' | args='$(trunc "$*")'"
  ps_run $flags "$@"
  if [ "$PS_RC" -ne 0 ]; then gko "$label: rc=$PS_RC ($flags)"; return; fi
  cp "$LOG/out" "$LOG/out_b"; cp "$LOG/err" "$LOG/err_b"
  v=$(verify "$LOG/out_b" "$@"); [ "$v" = OK ] || { gko "$label: $flags does not sort ($v)"; return; }
  if [ ! -s "$LOG/err_b" ] || grep -qv '^\[bench\]' "$LOG/err_b"; then
    gko "$label: $flags -> stderr must only hold [bench] lines; got: $(head -c 120 "$LOG/err_b" | od -An -tx1c | tr '\n' ' ')"; return
  fi
  if ! cmp -s <(tr -d '\000' <"$LOG/err_b") "$LOG/err_b"; then
    gko "$label: benchmark stderr contains NUL bytes (\0)"; return
  fi
  awk '{for(i=1;i<NF;i++) if($i ~ /:$/){k=$i; sub(/:$/,"",k); if(k!="strategy") print k"="$(i+1)}}' "$LOG/err_b" >"$LOG/kv"
  d=$(kv disorder); tot=$(kv total_ops)
  echo "$d" | grep -Eq '^[0-9]+\.[0-9]{2}%$' || { gko "$label: disorder '$d' (want xx.xx%)"; return; }
  exp_d=$(disorder_of "$@")
  awk -v a="${d%\%}" -v b="$exp_d" 'BEGIN{x=a-b;if(x<0)x=-x;exit !(x<=0.011)}' || { gko "$label: disorder $d but real value is $exp_d%"; return; }
  real=$(wc -l <"$LOG/out_b" | tr -d ' ')
  [ "$tot" = "$real" ] || { gko "$label: total_ops=$tot but $real lines on stdout"; return; }
  for k in $OPS_LIST; do
    act=$(grep -cx "$k" "$LOG/out_b"); c=$(kv "$k")
    [ "$c" = "$act" ] || { gko "$label: [bench] $k=$c but stdout has $act"; return; }
  done
  sl=$(grep -i 'strategy' "$LOG/err_b" | head -1)
  [ -n "$sl" ] || { gko "$label: no 'strategy' line in bench"; return; }
  got=$(class_of "$sl")
  case "$flags" in *simple*) want=n2;; *medium*) want=nsqrtn;; *complex*) want=nlogn;; *) want="";; esac
  if [ -z "$want" ]; then
    dn=${d%\%}; want=$(awk -v x="$dn" 'BEGIN{print (x<20)?"n2":((x<50)?"nsqrtn":"nlogn")}')
  fi
  if [ "$got" = "?" ]; then
    [ "$WARNED_CLASS" -eq 0 ] && { WARNED_CLASS=1; warn "can't recognise complexity class in: '$sl'"; }
  elif [ "$got" != "$want" ]; then
    case "$flags" in *simple*|*medium*|*complex*) gko "$label: '$sl' -> class should be $want"; return;;
      *) [ "$WARNED_CLASS" -eq 0 ] && { WARNED_CLASS=1; warn "adaptive at disorder $d prints '$sl' (expected class $want)"; };; esac
  fi
  ps_run ${flags//--bench/} "$@"
  cmp -s "$LOG/out" "$LOG/out_b" || { gko "$label: --bench changes the stdout operations"; return; }
  gok
}

perf_run(){ # flags n -> P_MIN P_AVG P_MAX
  local flags="$1" n="$2" i L v
  : >"$LOG/ops_count"
  for ((i=0;i<RUNS;i++)); do
    L=$(rand_list "$n"); ps_run $flags $L
    if [ "$PS_RC" -ne 0 ]; then MSG="rc=$PS_RC (n=$n flags='$flags')"; return 1; fi
    v=$(verify "$LOG/out" $L)
    if [ "$v" != OK ]; then MSG="n=$n flags='$flags': $v"; echo "$PS $flags $L" >>"$LOG/fails.txt"; return 1; fi
    wc -l <"$LOG/out" | tr -d ' ' >>"$LOG/ops_count"
  done
  read -r P_MIN P_AVG P_MAX < <(awk 'NR==1{mn=mx=$1}{s+=$1;if($1<mn)mn=$1;if($1>mx)mx=$1}END{printf "%d %.0f %d\n",mn,s/NR,mx}' "$LOG/ops_count")
}
tier(){ local e g p; if [ "$1" -eq 100 ]; then e=700; g=1500; p=2000; else e=5500; g=8000; p=12000; fi
  if [ "$2" -lt $e ]; then echo "excellent"; elif [ "$2" -lt $g ]; then echo "good"; elif [ "$2" -lt $p ]; then echo "pass(min)"; else echo "FAIL"; fi; }

# ------------------------------------------------------------------- memory
mem_run(){ # label stdin cmd...
  local label="$1" in="$2"; shift 2
  test_name "$label | command: $*"
  case "$MEMTOOL" in
    valgrind)
      rm -f "$LOG/vg.log"
      $TMO_MEM valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all \
        --error-exitcode=42 --log-file="$LOG/vg.log" -q "$@" <"$in" >/dev/null 2>&1
      if [ -s "$LOG/vg.log" ]; then cp "$LOG/vg.log" "$LOG/vg_fail_$((gf+1)).log"; gko "$label -> valgrind issues (log: $LOG/vg_fail_$((gf+1)).log)"; else gok; fi;;
    leaks)
      leaks --atExit -- "$@" <"$in" >"$LOG/leaks.txt" 2>&1
      if grep -q ' 0 leaks for 0 total leaked bytes' "$LOG/leaks.txt"; then gok; else gko "$label -> leaks reported"; fi;;
  esac
}
test_memory_ps(){
  [ "$MEM" -eq 1 ] || return
  if [ "$MEMTOOL" = none ]; then warn "no valgrind / leaks found -> memory tests skipped"; return; fi
  gbegin "memory ($MEMTOOL): push_swap (errors, sorted, random) × strategies"
  local f L10 L100 L200; L10=$(rand_list 10); L100=$(rand_list 100); L200=$(rand_list 200)
  for f in "${FLAGS_ALL[@]}"; do
    mem_run "err 'one' [$f]" /dev/null $PS $f 1 one 3
    mem_run "err dup [$f]" /dev/null $PS $f 1 2 2
    mem_run "err overflow [$f]" /dev/null $PS $f 2147483648
    mem_run "err late dup [$f]" /dev/null $PS $f 5 4 3 2 1 5
    mem_run "sorted [$f]" /dev/null $PS $f 1 2 3 4 5
    mem_run "single [$f]" /dev/null $PS $f 7
    mem_run "reverse 5 [$f]" /dev/null $PS $f 5 4 3 2 1
    mem_run "random 10 [$f]" /dev/null $PS $f $L10
    mem_run "random 100 [$f]" /dev/null $PS $f $L100
    mem_run "random 200 [$f]" /dev/null $PS $f $L200
    mem_run "bench 100 [$f]" /dev/null $PS $f --bench $L100
  done
  mem_run "no args" /dev/null $PS
  gend
}
test_memory_ck(){
  [ "$MEM" -eq 1 ] && [ "$MEMTOOL" != none ] && [ -x "$CK" ] || return
  gbegin "memory ($MEMTOOL): checker"
  : >"$LOG/m_empty"; printf 'rra\npb\nsa\nrra\npa\n' >"$LOG/m_ok"; printf 'sa\nxx\n' >"$LOG/m_bad"
  local L; L=$(rand_list 100)
  if ps_exists; then $PS $L >"$LOG/m_big" 2>/dev/null; mem_run "checker 100 + push_swap output" "$LOG/m_big" $CK $L; fi
  mem_run "checker ok" "$LOG/m_ok" $CK 3 2 1 0
  mem_run "checker bad instruction" "$LOG/m_bad" $CK 3 2 1 0
  mem_run "checker bad arg" "$LOG/m_empty" $CK 3 2 one 0
  mem_run "checker duplicate" "$LOG/m_empty" $CK 1 1
  mem_run "checker empty arg" "$LOG/m_empty" $CK "" 1
  mem_run "checker no args" "$LOG/m_empty" $CK
  mem_run "checker KO" "$LOG/m_empty" $CK 2 1
  gend
}

# ------------------------------------------------------------ static checks
test_static(){ # binary
  local bin="$1" ext glob
  [ -x "$bin" ] && command -v nm >/dev/null 2>&1 || return
  ext=$(nm -u "$bin" 2>/dev/null | awk '{print $NF}' | sed 's/@.*//; s/^_//' \
    | grep -vE '^(read|write|malloc|free|exit|_exit|libc_start_main|cxa_finalize|ITM_.*|gmon_start__|stack_chk_fail|stack_chk_guard|dyld_stub_binder|_*)$' | sort -u | tr '\n' ' ')
  [ -n "$ext" ] && warn "$bin uses external symbols besides read/write/malloc/free/exit: $ext(check they're allowed: printf, memcpy, ...)"
  glob=$(nm "$bin" 2>/dev/null | awk '$2 ~ /^[BbDd]$/ {print $3}' | grep -vE '^(_|\.|completed|data_start|dtor_idx)' | tr '\n' ' ')
  [ -n "$glob" ] && warn "$bin: possible global/static variables in .data/.bss: $glob(globals are forbidden)"
}

# --------------------------------------------------------------- README audit
check_readme(){
  gbegin "README.md: required sections and project documentation"
  if [ ! -f README.md ]; then gko "README.md missing at repository root"; gend; return; fi
  local first plain
  first=$(head -n 1 README.md | tr -d '\r')
  plain=${first#\*}; plain=${plain%\*}
  if [[ "$first" == \**\* ]] && [[ "$plain" =~ ^This\ activity\ has\ been\ created\ as\ part\ of\ the\ 42\ curriculum[[:space:]]+[^,]+,[[:space:]]+[^,]+$ ]]; then
    gok
  else gko "first line must be italicized: This activity has been created as part of the 42 curriculum <login1>, <login2>"; fi
  for h in Description Instructions Resources; do
    grep -Eiq "^#{1,6}[[:space:]]+$h([[:space:]]|$)" README.md && gok || gko "missing '$h' section";
  done
  grep -Eiq 'simple.{0,30}O\(n.?²|O\(n\^?2\)|O\(n\*n\)' README.md && gok || gko "README should explain/justify Simple O(n²)";
  grep -Eiq 'medium.{0,40}O\(n.?√n|O\(n.?sqrt\(n\)\)|O\(n\*sqrt\(n\)\)' README.md && gok || gko "README should explain/justify Medium O(n√n)";
  grep -Eiq 'complex.{0,40}O\(n.?log.?n\)' README.md && gok || gko "README should explain/justify Complex O(n log n)";
  grep -Eiq 'adaptive' README.md && gok || gko "README should explain Adaptive strategy";
  grep -Eiq 'AI|ChatGPT|GPT|Claude|Copilot|artificial intelligence' README.md && gok || gko "Resources should explain how AI was used (or explicitly state none)";
  grep -Eiq 'contribution|responsibilit|Akram|login' README.md && gok || gko "README should document each learner's contributions";
  gend
}

manual_review(){
  [ "$MANUAL" -eq 1 ] || return
  stage "MANUAL DEFENSE CHECKLIST (must be checked by evaluator)"
  cat <<'EOF'
  These items cannot be honestly verified by a shell script. Review them during the defense:
    [ ] Exactly 2 learners are contributors; both are present and can defend the whole codebase.
    [ ] README identifies both learners and clearly documents each contribution.
    [ ] Both learners explain Simple O(n²), Medium O(n√n), Complex O(n log n), and Adaptive.
    [ ] No segfault, crash, premature exit, or uncontrolled termination during the whole defense.
    [ ] Quick live coding: add --count-only; print only the total operation count (e.g. 3 2 1 -> 3) within 10 minutes.
EOF
}

# ------------------------------------------------------------------- stages
stage_norm(){
  stage "NORMINETTE"
  if ! command -v norminette >/dev/null 2>&1; then warn "norminette not installed -> skipped"; return; fi
  gbegin "norminette (all .c/.h : mandatory + bonus + libft)"
  local out bad; out=$(norminette 2>&1); bad=$(echo "$out" | grep -v ': OK!$' | grep -v '^$')
  if [ -z "$bad" ]; then gok; else gko "norm errors found (listing below)"; fi
  gend
  [ -n "$bad" ] && echo "$bad" | head -40 | sed 's/^/        /'
}

build_checks(){ # target binary
  local tgt="$1" bin="$2" out out2 rc m1 m2 cmds r
  gbegin "make $tgt : build / flags / warnings / no relink"
  make fclean >/dev/null 2>&1
  make -n $tgt >"$LOG/make_n" 2>&1
  out=$(make $tgt 2>&1); rc=$?
  [ $rc -eq 0 ] && gok || gko "make $tgt failed: $(echo "$out" | tail -3 | tr '\n' ' ')"
  [ -x "$bin" ] && gok || gko "'$bin' not created by make $tgt"
  echo "$out" | grep -Eqi 'warning:|error:' && gko "warnings/errors in compiler output" || gok
  cmds="$LOG/make_n"; grep -Eq '(^|[[:space:]])(cc|gcc|clang)[[:space:]]' "$cmds" || cmds=Makefile
  for r in Wall Wextra Werror; do grep -q -- "-$r" "$cmds" && gok || gko "flag -$r not found in compile commands"; done
  grep -Eq '(^|[[:space:]=@])cc([[:space:]]|$)' "$cmds" && gok || gko "compiler must be cc"
  sleep 1.1; m1=$(mtime "$bin"); out2=$(make $tgt 2>&1); m2=$(mtime "$bin")
  if [ "$m1" != "$m2" ] || echo "$out2" | grep -Eq '(^|[[:space:]])(cc|gcc|clang|ar)[[:space:]]'; then
    gko "relink: second 'make $tgt' rebuilt something"; else gok; fi
  gend
}
rules_checks(){ # target binary
  local tgt="$1" bin="$2" r objs
  gbegin "Makefile rules (NAME all clean fclean re ${tgt/all/})"
  grep -Eq '^\$\(NAME\)[[:space:]]*:' Makefile && gok || gko "rule \$(NAME) missing"
  for r in all clean fclean re; do grep -Eq "^$r[[:space:]]*:" Makefile && gok || gko "rule '$r' missing"; done
  [ "$tgt" = bonus ] && { grep -Eq '^bonus[[:space:]]*:' Makefile && gok || gko "rule 'bonus' missing"; }
  make $tgt >/dev/null 2>&1; make clean >/dev/null 2>&1
  objs=$(find . -name '*.o' -not -path './.git/*' | head -1)
  [ -z "$objs" ] && gok || gko "make clean leaves object files ($objs)"
  [ -e "$bin" ] && gok || gko "make clean must keep the binary '$bin'"
  make fclean >/dev/null 2>&1
  [ ! -e "$bin" ] && gok || gko "make fclean must remove '$bin'"
  make re >/dev/null 2>&1; make $tgt >/dev/null 2>&1
  [ -x "$bin" ] && gok || gko "'$bin' missing after re / $tgt"
  gend
}

test_mandatory(){
  local f n r L k kind lst
  gbegin "no arguments -> prints nothing, returns prompt"
  ps_run
  if [ -s "$LOG/out" ] || [ -s "$LOG/err" ] || [ "$PS_RC" -ne 0 ]; then gko "no args: must print nothing (rc=$PS_RC)"; else gok; fi
  gend

  gbegin "error management (stderr = 'Error\\n', stdout empty) × strategies"
  for f in "${FLAGS_ALL[@]}" "--bench"; do
    t_error $f 0 one 2 3;        t_error $f 3 2 3;            t_error $f 1 2 2147483648
    t_error $f 1 -2147483649 3;  t_error $f 99999999999999999999 1
    t_error $f 1 "" 2;           t_error $f "";               t_error $f 1 - 2
    t_error $f 1 + 2;            t_error $f 1 2a 3;           t_error $f 1 --3 2
    t_error $f 1 01;             t_error $f 0 -0;             t_error $f 5 4 3 2 1 4
    t_error $f 1 2.5 3;          t_error $f --foo 1 2
  done
  gend

  gbegin "valid edge values (INT_MIN / INT_MAX / negatives / single) × strategies"
  for f in "${FLAGS_ALL[@]}"; do
    t_sort edge "$f" 2147483647 -2147483648 0
    t_sort edge "$f" -2147483648 2147483647
    t_sort edge "$f" 42
    t_sort edge "$f" -5 -4 -3 -9 -1
    t_sort edge "$f" 0 -1
    t_sort edge "$f" 2147483647 -2147483648 1 -1 0 5 -5
  done
  gend

  gbegin "already sorted input -> 0 operations × strategies"
  for f in "${FLAGS_ALL[@]}"; do for n in 1 2 3 5 10 100 500; do
    t_zero sorted "$f" $(seq 1 "$n" | tr '\n' ' ')
  done; done
  gend

  gbegin "strategy selection flags: simple / medium / complex / adaptive / default"
  L="5 4 3 2 1"
  for f in "--simple" "--medium" "--complex" "--adaptive" ""; do
    t_sort "official strategy smoke test" "$f" 5 4 3 2 1
  done
  gend

  gbegin "3-number instruction count (<=5 acceptable)"
  for L in "2 1 0" "0 2 1" "1 0 2" "2 0 1" "1 2 0" "0 1 2"; do
    t_core "3-number count" "" $L
    if [ $? -eq 0 ]; then
      [ "$LAST_OPS" -le 5 ] && gok || gko "[$L] uses $LAST_OPS operations (expected <=5)"
    else gko "$MSG"; fi
  done
  gend

  gbegin "5-number instruction count (<=15 acceptable)"
  for L in "1 5 2 4 3" "5 1 4 2 3" "3 5 1 4 2" "5 4 3 2 1"; do
    t_core "5-number count" "" $L
    if [ $? -eq 0 ]; then
      [ "$LAST_OPS" -le 15 ] && gok || gko "[$L] uses $LAST_OPS operations (expected <=15)"
    else gko "$MSG"; fi
  done
  gend

  gbegin "default behaviour == --adaptive (same output)"
  for n in 3 5 10 100 500; do
    L=$(rand_list $n); ps_run $L; cp "$LOG/out" "$LOG/o1"; ps_run --adaptive $L
    cmp -s "$LOG/o1" "$LOG/out" && gok || gko "n=$n: default output differs from --adaptive"
  done
  gend

  for n in 2 3 4 5 $([ "$FULL" -eq 1 ] && echo 6); do
    gbegin "all permutations of $n numbers × 5 strategies"
    while read -r lst; do
      for f in "${FLAGS_ALL[@]}"; do t_sort "perm" "$f" $lst; done
    done < <(permute "" $(seq -1 $((n-2))))
    gend; info "max ops used for n=$n: $MAXOPS"
  done

  gbegin "random lists (n=1..1000) × 5 strategies"
  for f in "${FLAGS_ALL[@]}"; do for n in 1 2 3 5 10 20 50 100 200 500 1000; do for r in 1 2; do
    t_sort "n=$n" "$f" $(rand_list $n)
  done; done; done
  gend

  gbegin "disorder regimes (sorted/low/mid/random/reverse) × sizes × strategies"
  for n in 10 100 500; do for kind in sorted low mid random reverse; do
    L=$(mk_list $kind $n)
    for f in "${FLAGS_ALL[@]}"; do t_sort "$kind n=$n" "$f" $L; done
  done; done
  gend

  gbegin "--bench output (format, counts, disorder, class, flag order)"
  for n in 10 100 500; do for kind in sorted low mid random reverse; do
    L=$(mk_list $kind $n)
    for f in "${FLAGS_ALL[@]}"; do
      t_bench "$kind n=$n" "$f --bench" $L
      [ "$n" -eq 100 ] && t_bench "$kind n=$n" "--bench $f" $L
    done
  done; done
  gend

  gbegin "official scale inputs: 100 numbers (<2000 ops) and 500 numbers (<12000 ops)"
  for n in 100 500; do
    L=$(shuf -i 1-$((n*2)) -n "$n" | tr '\n' ' ')
    t_core "scale n=$n" "" $L
    if [ $? -eq 0 ]; then
      lim=12000; [ "$n" -eq 100 ] && lim=2000
      [ "$LAST_OPS" -lt "$lim" ] && gok || gko "n=$n used $LAST_OPS operations (scale requires <$lim)"
    else gko "$MSG"; fi
  done
  gend

  stage "PERFORMANCE  ($RUNS random runs per size)"
  for n in 100 500; do
    for f in "" "--adaptive" "--simple" "--medium" "--complex"; do
      lab="${f:-default}"
      if perf_run "$f" $n; then
        if [ -z "$f" ]; then
          gbegin "default (adaptive) n=$n : min=$P_MIN avg=$P_AVG max=$P_MAX"
          if [ "$(tier $n $P_MAX)" = FAIL ]; then gko "max $P_MAX ops >= pass limit"; else gok; fi
          gend; info "tier  avg: $(tier $n $P_AVG)   |   worst run: $(tier $n $P_MAX)"
        else
          printf "      %-10s n=%-4s min=%-7s avg=%-8s max=%-7s tier(avg)=%s\n" "$lab" "$n" "$P_MIN" "$P_AVG" "$P_MAX" "$(tier $n $P_AVG)"
        fi
      else gbegin "performance $lab n=$n"; gko "$MSG"; gend; fi
    done
  done

  stage "MEMORY (push_swap)"
  test_memory_ps
}

ck_expect(){ # label verdict(OK|KO|ERR|NONE) opsfile args...
  local label="$1" want="$2" in="$3"; shift 3
  test_name "checker $label | args=$* | expect=$want"
  ck_run "$in" "$@"
  if [ "$CK_RC" -eq 124 ]; then gko "$label: TIMEOUT"; return; fi
  if [ "$CK_RC" -ge 128 ]; then gko "$label: CRASH rc=$CK_RC"; return; fi
  case "$want" in
    OK|KO) printf '%s\n' "$want" >"$LOG/exp_o"
      if cmp -s "$LOG/out" "$LOG/exp_o" && [ ! -s "$LOG/err" ]; then gok
      else gko "$label: want $want, got stdout='$(head -c 30 "$LOG/out")' stderr='$(head -c 30 "$LOG/err")'"; fi;;
    ERR) printf 'Error\n' >"$LOG/exp_e"
      if [ ! -s "$LOG/out" ] && cmp -s "$LOG/err" "$LOG/exp_e"; then gok
      else gko "$label: want Error on stderr, got stdout='$(head -c 30 "$LOG/out")' stderr='$(head -c 30 "$LOG/err")'"; fi;;
    NONE) if [ ! -s "$LOG/out" ] && [ ! -s "$LOG/err" ]; then gok; else gko "$label: must print nothing"; fi;;
  esac
}
mkops(){ printf "$1" >"$LOG/$2"; }

test_checker(){
  if [ ! -x "$CK" ]; then warn "checker not built -> skipped"; return; fi
  local op st exp i n L og OFFICIAL=""
  for c in "${CK_OFFICIAL:-}" ./checker_linux ../checker_linux ./checker_Mac ../checker_Mac; do
    [ -n "$c" ] && [ -x "$c" ] && { OFFICIAL="$c"; break; }; done
  : >"$LOG/ops_empty"
  mkops 'rra\npb\nsa\nrra\npa\n' ops_ok1; mkops 'sa\nrra\npb\n' ops_ko1
  mkops 'xx\n' ops_b1; mkops 'sa \n' ops_b2; mkops ' sa\n' ops_b3; mkops 'SA\n' ops_b4
  mkops 'sa pb\n' ops_b5; mkops 'sa\nxx\nsa\n' ops_b6; mkops 'pa\n' ops_pa; mkops 'pb\n' ops_pb
  mkops 'sa\npa\nrb\nrra\nrrb\nss\nrr\nrrr\nsb\n' ops_noop

  gbegin "checker: official scale examples (OK / KO / errors)"
  # Official KO example: sa, pb, rrr on the specified 10-number stack.
  mkops 'sa\npb\nrrr\n' ops_scale_ko
  ck_expect official-KO KO "$LOG/ops_scale_ko" 0 9 1 8 2 7 3 6 4 5
  # Official OK example from the scale.
  mkops 'pb\nra\npb\nra\nsa\nra\npa\npa\n' ops_scale_ok
  ck_expect official-OK OK "$LOG/ops_scale_ok" 0 9 1 8 2
  ck_expect valid-3 OK "$LOG/ops_empty" 1 2 3
  ck_expect unsorted-3 KO "$LOG/ops_empty" 2 1 3
  ck_expect nonnumeric ERR "$LOG/ops_empty" 3 2 one 0
  ck_expect empty-arg ERR "$LOG/ops_empty" "" 1
  ck_expect noargs NONE "$LOG/ops_empty"
  gend

  gbegin "checker: argument errors"
  ck_expect dup ERR "$LOG/ops_empty" 1 2 1
  ck_expect overflow ERR "$LOG/ops_empty" 2147483648
  ck_expect underflow ERR "$LOG/ops_empty" -2147483649 1
  ck_expect huge ERR "$LOG/ops_empty" 99999999999999999999 1
  ck_expect alpha ERR "$LOG/ops_empty" 1 2a 3
  ck_expect sign ERR "$LOG/ops_empty" 1 - 3
  ck_expect float ERR "$LOG/ops_empty" 1 2.5
  gend

  gbegin "checker: bad instructions -> Error"
  for i in 1 2 3 4 5 6; do ck_expect "bad$i" ERR "$LOG/ops_b$i" 3 2 1; done
  gend

  gbegin "checker: whitespace / malformed instruction edge cases"
  mkops ' sa\n' ops_lead; ck_expect leading-space ERR "$LOG/ops_lead" 3 2 1
  mkops 'sa \n' ops_trail; ck_expect trailing-space ERR "$LOG/ops_trail" 3 2 1
  mkops ' sa \n' ops_bothspace; ck_expect both-spaces ERR "$LOG/ops_bothspace" 3 2 1
  mkops 'sa\t\n' ops_tab; ck_expect tab ERR "$LOG/ops_tab" 3 2 1
  mkops 'SA\n' ops_upper; ck_expect uppercase ERR "$LOG/ops_upper" 3 2 1
  mkops 'sa\r\n' ops_crlf; ck_expect CRLF ERR "$LOG/ops_crlf" 3 2 1
  gend

  gbegin "checker: OK / KO basics"
  ck_expect sorted OK "$LOG/ops_empty" 1 2 3
  ck_expect single OK "$LOG/ops_empty" 5
  ck_expect unsorted KO "$LOG/ops_empty" 2 1
  ck_expect b-not-empty KO "$LOG/ops_pb" 1 2 3
  ck_expect noops-single OK "$LOG/ops_noop" 5
  ck_expect pa-on-empty-b OK "$LOG/ops_pa" 1 2
  ck_expect negatives OK "$LOG/ops_empty" -3 -1 0 7
  ck_expect int-limits OK "$LOG/ops_empty" -2147483648 0 2147483647
  gend

  gbegin "checker: every instruction vs reference model"
  for op in $OPS_LIST; do for st in "2 1" "1 2" "3 1 2" "1" "5 4 3 2 1"; do
    printf '%s\n' "$op" >"$LOG/ops_one"; exp=$(verify "$LOG/ops_one" $st)
    ck_expect "$op on [$st]" "$exp" "$LOG/ops_one" $st
  done; done
  gend

  gbegin "checker: differential test vs reference model${OFFICIAL:+ and official checker}"
  for ((i=0;i<RUNS*5;i++)); do
    n=$(( (RANDOM % 8) + 1 )); L=$(rand_list $n)
    if ps_exists && [ $((i%2)) -eq 0 ]; then $PS $L 2>/dev/null | mutate >"$LOG/ops_r"
    else rand_ops $((RANDOM % 16)) >"$LOG/ops_r"; fi
    exp=$(verify "$LOG/ops_r" $L)
    ck_run "$LOG/ops_r" $L
    if [ "$(cat "$LOG/out")" = "$exp" ] && [ ! -s "$LOG/err" ]; then gok
    else gko "stack [$L] ops [$(tr '\n' ' ' <"$LOG/ops_r")] -> checker '$(head -c 20 "$LOG/out")' expected $exp"; fi
    if [ -n "$OFFICIAL" ]; then
      og=$($OFFICIAL $L <"$LOG/ops_r" 2>/dev/null)
      [ "$og" = "$exp" ] && gok || gko "official checker says '$og', model says $exp (stack [$L])"
    fi
  done
  gend
  [ -z "$OFFICIAL" ] && info "tip: set CK_OFFICIAL=./checker_linux to cross-check with the official checker"
  stage "MEMORY (checker)"
  test_memory_ck
}

test_pipeline(){ # push_swap | checker
  if ! ps_exists || [ ! -x "$CK" ]; then warn "need both push_swap and checker for pipeline tests"; return; fi
  local f n r L v OFFICIAL=""
  for c in "${CK_OFFICIAL:-}" ./checker_linux ../checker_linux ./checker_Mac ../checker_Mac; do
    [ -n "$c" ] && [ -x "$c" ] && { OFFICIAL="$c"; break; }; done
  gbegin "push_swap | checker -> OK${OFFICIAL:+  (and official checker)} × strategies × sizes"
  for f in "${FLAGS_ALL[@]}"; do for n in 1 2 3 5 10 20 100 500; do for r in 1 2; do
    L=$(rand_list $n)
    v=$($TMO $PS $f $L 2>/dev/null | $TMO $CK $L 2>&1)
    [ "$v" = OK ] && gok || gko "n=$n [$f] -> checker said '$v'"
    if [ -n "$OFFICIAL" ]; then
      v=$($TMO $PS $f $L 2>/dev/null | $OFFICIAL $L 2>&1); [ "$v" = OK ] && gok || gko "n=$n [$f] -> official said '$v'"
    fi
  done; done; done
  gend
  gbegin "push_swap --bench | checker : stdout ops only"
  for n in 5 100; do L=$(rand_list $n)
    v=$($TMO $PS --bench $L 2>/dev/null | $TMO $CK $L 2>&1); [ "$v" = OK ] && gok || gko "n=$n -> '$v'"; done
  gend
}

stage_mandatory(){
  stage "MANDATORY  (make -> push_swap)"
  check_readme
  build_checks "" "$PS"; rules_checks "" "$PS"
  test_static "$PS"
  ps_exists || { warn "push_swap missing -> mandatory tests skipped"; return; }
  test_mandatory
}
stage_bonus(){
  stage "BONUS  (make bonus -> checker)"
  build_checks bonus "$CK"; rules_checks bonus "$CK"
  test_static "$CK"
  [ -n "$(find . -name '*_bonus.c' -not -path './.git/*' | head -1)" ] || warn "no *_bonus.c file found (bonus files must be named *_bonus.{c,h})"
  test_checker
}
stage_both(){
  stage "BOTH  (make + make bonus together)"
  local m1 m2
  gbegin "make ; make bonus -> both binaries coexist"
  make fclean >/dev/null 2>&1
  make >/dev/null 2>&1; ps_exists && gok || gko "make did not create push_swap"
  sleep 1.1; m1=$(mtime "$PS")
  make bonus >/dev/null 2>&1; [ -x "$CK" ] && gok || gko "make bonus did not create checker"
  ps_exists && gok || gko "push_swap vanished after make bonus"
  m2=$(mtime "$PS"); [ "$m1" = "$m2" ] || warn "make bonus relinked push_swap (fine if intended)"
  make fclean >/dev/null 2>&1
  { [ ! -e "$PS" ] && [ ! -e "$CK" ]; } && gok || gko "make fclean must remove both push_swap and checker"
  gend
  test_pipeline
  gbegin "make bonus ; make -> both binaries coexist (reverse order)"
  make fclean >/dev/null 2>&1; make bonus >/dev/null 2>&1; make >/dev/null 2>&1
  { ps_exists && [ -x "$CK" ]; } && gok || gko "after 'make bonus; make' one binary is missing"
  gend
  test_pipeline
  gbegin "make re / make all bonus"
  make re >/dev/null 2>&1; ps_exists && gok || gko "make re failed"
  make fclean >/dev/null 2>&1; make all bonus >/dev/null 2>&1
  { ps_exists && [ -x "$CK" ]; } && gok || gko "'make all bonus' did not build both"
  gend
}

finish(){
  printf "\n%s════════════════ SUMMARY ════════════════%s\n" "$B" "$N"
  printf "  passed: %s%s%s   failed: %s%s%s   warnings: %s%s%s\n" "$G" "$TOTAL_PASS" "$N" "$R" "$TOTAL_FAIL" "$N" "$Y" "$TOTAL_WARN" "$N"
  if [ "${#FAILED_GROUPS[@]}" -gt 0 ]; then
    echo "  failed groups:"; local g; for g in "${FAILED_GROUPS[@]}"; do printf "    %s- %s%s\n" "$R" "$g" "$N"; done
  fi
  if [ "$TOTAL_FAIL" -gt 0 ]; then
    echo "  logs / repro commands kept in: $LOG   (fails.txt = commands to replay)"
    exit 1
  fi
  [ "$KEEP" -eq 1 ] || rm -rf "$LOG"
  printf "  %sALL GOOD%s\n" "$G" "$N"; exit 0
}

# --------------------------------------------------------------------- main
[ "${PS_TESTER_SOURCE_ONLY:-0}" = 1 ] && return 0

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift;;
    --runs) RUNS="$2"; shift;;
    --no-norm) NORM=0;; --no-mem) MEM=0;; --full) FULL=1;; --keep-logs) KEEP=1;;
    --verbose|-v) VERBOSE=1;; --no-manual) MANUAL=0;;
    -h|--help) sed -n '2,15p' "$0"; exit 0;;
    *) DIR="$1";;
  esac; shift
done
cd "$DIR" 2>/dev/null || { echo "bad project dir: $DIR"; exit 2; }
[ -f Makefile ] || { echo "no Makefile in $(pwd)"; exit 2; }
LOG=$(mktemp -d /tmp/ps_tester.XXXXXX); trap 'exit 130' INT
if command -v valgrind >/dev/null 2>&1; then MEMTOOL=valgrind
elif [ "$(uname)" = Darwin ] && command -v leaks >/dev/null 2>&1; then MEMTOOL=leaks
else MEMTOOL=none; fi
printf "%spush_swap tester%s  dir=%s  runs=%s  mem=%s\n" "$B" "$N" "$(pwd)" "$RUNS" "$MEMTOOL"

case "$ONLY" in
  all)       [ "$NORM" -eq 1 ] && stage_norm; stage_mandatory; stage_bonus; stage_both;;
  norm)      stage_norm;;
  mandatory) stage_mandatory;;
  bonus)     stage_bonus;;
  both)      stage_mandatory; stage_bonus; stage_both;;
  *) echo "unknown --only value"; exit 2;;
esac
manual_review
finish