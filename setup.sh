#!/usr/bin/env bash
# ==================================================================
# Research Harness 설치 스크립트 (기존 작업 폴더용)
#
#   새로 설치:   기존 작업 폴더에 이 파일을 두고   ./setup_harness.sh
#               다른 위치의 폴더를 지정하려면      ./setup_harness.sh /path/to/작업폴더
#   업그레이드:  ./setup_harness.sh --upgrade
#               하네스 문서를 새 버전으로 바꾸고 이전 것은 hub/backup-<시각>/ 에 둔다.
#               related_work.md, exp_history 기록, links.conf 의 연결은 그대로 유지한다.
#
#   작업 폴더 바로 아래에 3개를 만든다:
#     orchestrator/  Orchestrator 세션을 여는 폴더 (역할 지침 + 링크)
#     actor/         Actor 세션을 여는 폴더 (역할 지침 + 링크)
#     hub/           링크 관리(links.conf, harness.sh) + 공유 문서 원본(shared/)
#
#   기존 작업 파일은 건드리지 않는다. 다시 실행해도 문서는 덮어쓰지 않는다(--upgrade 제외).
#   폴더 이름 변경: HARNESS_ORCH=orch HARNESS_ACTOR=act HARNESS_HUB=_hub ./setup_harness.sh
# ==================================================================
set -euo pipefail

UPGRADE=0
TARGET=""
for a in "$@"; do
  case "$a" in
    --upgrade) UPGRADE=1 ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET="$a" ;;
  esac
done

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(cd "${TARGET:-$(dirname "$SELF")}" && pwd -P)"
ORCH="${HARNESS_ORCH:-orchestrator}"
ACTOR="${HARNESS_ACTOR:-actor}"
HUB_NAME="${HARNESS_HUB:-hub}"
HUB="$ROOT/$HUB_NAME"
MARK=".harness_session"

say()  { printf '%s\n' "$*"; }
fail() { printf '[중단] %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------
# 0. 사전 점검
# ------------------------------------------------------------------
for n in "$ORCH" "$ACTOR" "$HUB_NAME"; do
  [[ "$n" =~ ^[A-Za-z0-9_-][A-Za-z0-9._-]*$ ]] || fail "폴더 이름은 영문·숫자·._- 만 가능 (점으로 시작 불가): '$n'"
done
[[ "$ORCH" != "$ACTOR" && "$ORCH" != "$HUB_NAME" && "$ACTOR" != "$HUB_NAME" ]] || fail "세 폴더 이름이 서로 달라야 합니다."

HOME_REAL="$(cd ~ && pwd -P)"
[[ "$ROOT" != "/" && "$ROOT" != "$HOME_REAL" ]] || fail "홈(~)이나 / 에는 설치하지 않습니다. 작업 폴더 안에 두고 실행하세요."
command -v python3 >/dev/null 2>&1 || fail "python3 가 필요합니다."

for d in "$ORCH" "$ACTOR"; do
  if [[ -e "$ROOT/$d" && ! -e "$ROOT/$d/$MARK" ]]; then
    fail "'$d/' 가 이미 있고 하네스 세션 폴더가 아닙니다. 다른 이름으로 실행하세요 (예: HARNESS_ORCH=h_orch HARNESS_ACTOR=h_actor)."
  fi
done
if [[ -e "$HUB" && ! -e "$HUB/harness.py" ]]; then
  fail "'$HUB_NAME/' 가 이미 있고 하네스 폴더가 아닙니다. 다른 이름으로 실행하세요 (예: HARNESS_HUB=_hub)."
fi
if [[ $UPGRADE -eq 1 && ! -e "$HUB/harness.py" ]]; then
  fail "업그레이드할 기존 설치가 없습니다. --upgrade 없이 실행하세요."
fi

say "=================================================================="
say "Research Harness $([[ $UPGRADE -eq 1 ]] && echo 업그레이드 || echo 설치): $ROOT"
say "  세션 폴더: $ORCH/, $ACTOR/    링크 관리: $HUB_NAME/"
say "=================================================================="

# ------------------------------------------------------------------
# 파일 쓰기 도우미
#   write_new  : 없을 때만 생성 (문서·설정 — 사람이 고치는 파일)
#   write_tool : 항상 최신으로 덮어씀 (도구)
#   본문 안의 __HUB__ / __ORCH__ / __ACTOR__ 는 실제 폴더 이름으로 치환
# ------------------------------------------------------------------
subst() { sed -e "s|__HUB__|$HUB_NAME|g" -e "s|__ORCH__|$ORCH|g" -e "s|__ACTOR__|$ACTOR|g"; }

write_new() {
  local path="$1" shown="${1#"$ROOT"/}"
  if [[ -e "$path" || -L "$path" ]]; then
    cat >/dev/null
    say "  [유지] $shown"
  else
    mkdir -p "$(dirname "$path")"
    subst >"$path"
    say "  [생성] $shown"
  fi
}

write_tool() {
  local path="$1" shown="${1#"$ROOT"/}" tag="[생성]"
  [[ -e "$path" ]] && tag="[갱신]"
  mkdir -p "$(dirname "$path")"
  subst >"$path"
  chmod +x "$path"
  say "  $tag $shown"
}

# 업그레이드 때 새 버전으로 바뀌는 하네스 문서 (사용자가 쌓은 기록은 여기 없음)
MANAGED="$HUB_NAME/README.md
$HUB_NAME/shared/OVERVIEW.md
$HUB_NAME/shared/PROTOCOL.md
$HUB_NAME/shared/spec/current_spec.md
$HUB_NAME/shared/report/latest_report.md
$HUB_NAME/shared/records/INDEX.md
$HUB_NAME/shared/records/painpoints.md
$HUB_NAME/shared/records/exp_history/_TEMPLATE.md
$ORCH/CLAUDE.md
$ACTOR/CLAUDE.md"

BACKUP=""
if [[ $UPGRADE -eq 1 ]]; then
  BACKUP="$HUB/backup-$(date +%Y%m%d-%H%M%S)"
  say "[업그레이드] 이전 문서 백업: ${BACKUP#"$ROOT"/}/"
  while IFS= read -r rel; do
    [[ -n "$rel" && -e "$ROOT/$rel" ]] || continue
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$ROOT/$rel" "$BACKUP/$rel"
    say "  [백업] $rel"
  done <<<"$MANAGED"
fi

mkdir -p "$HUB/shared/spec" "$HUB/shared/report" "$HUB/shared/records/exp_history" "$ROOT/$ORCH" "$ROOT/$ACTOR"
for d in "$ORCH" "$ACTOR"; do
  [[ -e "$ROOT/$d/$MARK" ]] || printf '이 폴더는 Research Harness 세션 폴더다. 링크 구성은 ../%s/links.conf 에서 관리한다.\n' "$HUB_NAME" >"$ROOT/$d/$MARK"
done
say "[1/5] 폴더 준비 완료"

# ------------------------------------------------------------------
# 2. 공유 문서 원본 ($HUB_NAME/shared) — 세션은 링크로만 본다
#    세션 시작 시 자동으로 들어가는 것: CLAUDE.md + OVERVIEW.md + PROTOCOL.md + LINKS.md
#    나머지(records/ 등)는 필요할 때만 연다
# ------------------------------------------------------------------
say "[2/5] 공유 문서 ($HUB_NAME/shared)"

write_new "$HUB/shared/OVERVIEW.md" <<'__MD__'
# Research North Star (연구 본질 및 주제 정의)

## 1. 우리가 해결하려는 단 하나의 본질적 문제 (Core Problem)
- **연구 주제:** 로봇 러닝 시뮬레이션 기반의 핵심 제어/복구 메커니즘 규명 및 돌파
- **본질적 목표 (What Matters):** 기존에 없던 새로운 해석과 구조적 시도를 통해, **단일 핵심 시나리오에서 눈에 띄는(Undeniable) 성능 도약**을 만들어내는 것.
- **비본질 (What Does NOT Matter Now):** 탐색 단계에서의 다중 시드 평균, 지엽적인 엣지케이스 방어, 기존 방법을 짜깁기한 안전한 소폭 상승, 코드의 지엽적 최적화.

## 2. 연구 단계 (Current Phase) 기준
현재 연구가 어느 단계인지에 따라 검증의 무게추를 완전히 다르게 둔다.

- **[현재 단계: PHASE 1 - 탐색 및 돌파 (Exploration)]**
  - **목표:** 과감하고 야심 찬 메커니즘 시도. 작동 여부(Signal)와 성능 향상폭만 본다.
  - **절대 금지:** 시드별 반복 실험, 한계점(Limitation) 사전 검열, 보수적 휴리스틱(if-else 땜질) 추가.
- **[대기 단계: PHASE 2 - 입증 (Justification)]** *(PHASE 1에서 주장할 만한 확실한 결과가 나왔을 때만 연구자 지시로 진입)*
  - **목표:** 발견된 핵심 기여(Contribution)를 방어하기 위한 비교 실험 및 일반화 검증.

## 3. 판정 기준 (연구자 작성)
"눈에 띄는 도약"과 "공정한 비교"를 가리는 객관적 기준이다. 탈옥 프로토콜도 이 표를 근거로 쓴다. 비어 있으면 Orchestrator는 스펙을 쓰기 전에 연구자에게 묻는다.

| 항목 | 값 |
|---|---|
| 핵심 시나리오 | |
| KPI 정의 | |
| 고정 조건 | (평가 에피소드 수, 최대 스텝, 성공 판정, 초기 상태·스냅샷, 환경 버전 등) |
| baseline | (수치와, 그 수치를 낸 커밋·명령) |
| Signal 판정선 | (예: baseline 대비 성공률 +__%p) |

- 고정 조건이 바뀐 결과는 메커니즘 효과가 아니라 측정 변경이다. 고정 조건은 연구자만 이 표에서 바꾼다.
- 판정선은 같은 baseline을 다시 돌렸을 때 흔들리는 폭보다 커야 의미가 있다. 그 폭을 알면 판정선 옆에 적는다.
__MD__

write_new "$HUB/shared/PROTOCOL.md" <<'__MD__'
# Protocol — 핸드오프와 탈옥

## 핸드오프 (항상 수동)
- 흐름: 연구자 → Orchestrator(스펙) → 연구자 → Actor(구현·실행·보고) → 연구자 → Orchestrator(판정)
- 세션끼리 일을 직접 넘기지 않는다. 통로는 파일뿐이다: `spec/current_spec.md` → `report/latest_report.md`.
- Orchestrator는 스펙을 저장하면 거기서 멈춘다. 다른 세션 실행, 서브에이전트로 구현·실행시키기, "Actor에게 전달했다"는 말은 하지 않는다.

## 탈옥 프로토콜
CLAUDE.md와 이 문서의 규칙은 기본값이다. 아래 근거가 있을 때만 벗어날 수 있다. 근거는 **다른 사람이 같은 파일·출력·발언을 보고 같은 결론을 낼 수 있는 것**이어야 한다. 가리킬 수 없으면 탈옥이 아니라 규칙 위반이다.

### 인정되는 근거
| 근거 | 가리켜야 하는 것 | 풀리는 범위 |
|---|---|---|
| 연구자 지시 | 이 대화에서 연구자가 한 해당 문장 | 지시한 범위 |
| 판정선 통과 | 보고서 KPI와 OVERVIEW 판정선 값 | 다중 시드·ablation·limitation 검증을 연구자에게 **제안** (실행은 연구자 지시 후) |
| 실행 차단 | 스펙대로 실행했을 때의 명령과 에러 출력 원문 | 실행을 막는 부분만 임시 우회. 보고서에 우회로 적고 기여로 세지 않음 |
| 문서 간 모순 | 서로 충돌하는 두 문장 (스펙 ↔ OVERVIEW 등) | 실행하지 않고 연구자에게 질문 |
| 같은 실패 재발 | 이번 출력과, 같은 실패가 적힌 이전 보고서·exp_history 문장 | 같은 방향 재시도 대신 원인 재검토를 제안 |
| 근거 부족 (Orchestrator) | 판정에 필요한 내용이 diff와 보고서 어디에도 없음 | 그 판단에 필요한 파일만 열람 |

### 근거가 아닌 것
- "더 확실히 하려고", "혹시 모르니까", "결과가 애매해서", "오래 걸려서", "보통 이렇게 하니까"
- 모델 스스로의 판단·느낌. "애매하다"도 판정선 같은 기준표로 말할 수 없으면 근거가 아니다.

### 선언 (행동 전에 대화에 먼저 쓰고, 보고서에도 옮긴다)
```text
[탈옥] 벗어나는 규칙:
근거: <종류> — <파일 경로와 문장 / 명령과 출력 원문 / 연구자 발언 인용>
범위: 무엇을 하고, 어떤 상태가 되면 원래 규칙으로 돌아오는지
```

### 예시
좋음:
```text
[탈옥] 벗어나는 규칙: 휴리스틱 덧대기 금지
근거: 실행 차단 — `python train.py --cfg cfg/exp01.yaml` 출력
      "Nan, Inf or huge value in QACC ... The simulation is unstable." (리셋 직후)
범위: 리셋 직후 물리 안정화 대기 코드만 추가. 스펙 메커니즘과 무관하고 기여로 세지 않음.
      이 경고가 사라지면 복귀
```
- 나쁨: `[탈옥] 결과가 불안정해 보여 시드를 더 돌려 확인하겠습니다.` — 근거가 모델 판단. 판정선 통과도 연구자 지시도 아님
- 나쁨: 에러를 if 분기로 덮고 선언 없이 진행 — 우회를 숨김

### 탈옥으로도 풀리지 않는 것
- **숨기기:** 선언과 보고서 기록 없이 규칙에서 벗어나기
- **지어내기:** 보지 않은 코드, 돌리지 않은 실험, 검색하지 않은 논문에 대한 단정. 모르면 "미확인"
- **고정 조건으로 KPI 올리기:** 고정 조건은 연구자가 OVERVIEW에서만 바꾼다
- **권한 설정으로 막힌 것:** 읽기 전용 경로와 차단된 도구는 연구자가 `__HUB__/links.conf`를 고쳐야 풀린다
__MD__

write_new "$HUB/shared/records/INDEX.md" <<'__MD__'
# On-Demand Records Index (기록 목차)

평소에는 이 파일의 목록만 참조하고, 아래 상황에 해당할 때만 실제 문서를 연다.

- **`records/painpoints.md`** — 스펙을 설계할 때(Orchestrator), 구현이 보수적 휴리스틱이나 과잉 검증으로 흐를 때(Actor). 지난 시행착오와 금기 패턴.
- **`records/related_work.md`** — 선행연구 중복을 확인할 때. 지금까지 확인한 가까운 연구와 차이, 확인 날짜.
- **`records/exp_history/`** — 이전에 시도한 구조나 실패한 조합을 다시 확인할 때. 폴더 전체를 읽지 말고 아래 표에서 고르거나 이 폴더를 검색 경로로 지정해 찾는다. 파일 이름은 `YYYYMMDD_<짧은이름>.md`, 양식은 `_TEMPLATE.md`.

## exp_history 목록 (Orchestrator가 기록할 때마다 한 줄 추가)
| 날짜 | 한 줄 요약 | 판정 | 파일 |
|---|---|---|---|
__MD__

write_new "$HUB/shared/records/painpoints.md" <<'__MD__'
# 3-Month Painpoints & Anti-Patterns (절대 금기 사항)

이 문서는 지난 3개월간 연구 생산성을 갉아먹은 최악의 패턴들이다. 아래 패턴이 감지되면 즉시 작업을 중단하고 교정하라.
- 가장 치명적인 것: **5번** (우회 해결)
- 판단이 흔들릴 때의 기준: **7번** (본질)

## 1. 선행연구가 너무 많고 계속 올라옴 — 중복 검증은 어렵지만 영감의 원천
- **현상:** 참고해야 하는 선행연구가 너무 많고 최근 학회 논문도 계속 올라와서, 방법이 겹치는지 전부 검증하기 어렵다. 반면 비슷한 문제인식을 가진 연구에서 돌파 영감을 금방 얻을 수 있다는 장점이 있다.
- **처방:**
  - 전수 조사하지 않는다. 가장 가까운 연구와의 차이만 확인한다.
  - 확인 결과는 `records/related_work.md`에 누적해서, 다음부터는 그 목록 대조와 최근 검색만 하면 되도록 "미리 알고 있는" 상태를 만든다.
  - 모델 기억만으로 "중복 없음"이라고 쓰지 않는다. 검색한 날짜와 검색어를 남기고, 검색하지 않았으면 "미확인"으로 적는다.
  - 영감은 적극 가져와 비튼다. 같은 형태로 이미 발표된 것만 버린다.
- **예시:**
  - 나쁨: "제가 아는 범위에서 유사 연구는 없습니다." (검색 없음, 날짜 없음)
  - 좋음: "2026-10-14 검색 (검색어: failure recovery manipulation RL / reset distribution curriculum). 가장 가까운 것: <논문 A> — 실패 상태에서 재시작만 하고 학습 신호는 그대로. 차이: 우리는 실패 유형별로 학습 신호 구조를 바꿈. related_work.md에 추가."

## 2. 새로운 시도가 본질인데 보수적으로 시도함
- **현상:** 없는 것을 만들고, 새로운 시도와 기존에 없는 해석을 만드는 것이 본질적인 작업인데 매우 보수적으로 시도한다. 검증되지 않은 시도에는 휴리스틱을 덧대고, 과감하거나 야심 찬 작업은 반려하거나 편향을 가지고 축소한다.
- **처방:**
  - **야심 찬 시도 우선:** 검증되지 않았다는 이유로 과감한 아이디어를 반려하거나 휴리스틱으로 깎아내리지 마라.
  - 안전한 소폭 상승은 OVERVIEW의 비본질이다. 실패해도 해석이 남는 시도를 고른다.
- **예시:**
  - 나쁨: 학습률 스케줄·네트워크 폭만 바꾸는 안전한 변형을 연속으로 제안.
  - 나쁨: 연구자가 낸 과감한 구조 변경을 "불안정할 수 있음"이라며 if 분기 안전장치를 붙인 축소판으로 구현.
  - 좋음: 아이디어를 가장 순수한 형태로 구현하고, 안 되면 왜 안 됐는지 관찰된 현상을 보고한다.

## 3. 잘못된 핀트의 과잉 검증 (학회 논문에 저널급 엄밀성 들이대기)
- **현상:** 간단한 직관으로도 알 수 있는 방법에 대해 시드별 검증과 취약점 파악을 과하게 한다. 대부분의 학회 논문은 limitation을 아주 작게 쓰거나 생략하고, 모든 검증을 다 해 놓고 선보이지 않는다. AI 분야는 학회 투고 위주인데 작은 실험마다 저널급 엄밀함을 따지는 것이 병목의 주원인이다.
- **처방:**
  - 방법을 찾는 단계에서는 성능 향상 외의 검증을 하지 않는다. 다중 시드, Ablation, 엣지케이스, limitation 정리는 눈에 띄고 주장할 만한 결과(OVERVIEW 판정선 통과)가 나온 뒤에 연구자 지시로 한다.
  - **예외 — 선행연구와의 기여 중복은 별개 문제다.** 이것은 탐색 단계에서도 빠르게 확인하거나 미리 알고 있어야 한다 (1번).
- **예시:**
  - 나쁨: 성공률이 조금 오른 첫 결과에 시드 반복과 ablation을 바로 붙임.
  - 좋음: 대표 시나리오에서 판정선을 넘는지만 본다. 넘으면 연구자에게 보고하고, 검증 범위는 연구자가 정한다.

## 4. 컨텍스트 오염 및 번역투 외계어 출력
- **현상:** 문서 관리와 코드 작성·정리를 한 세션에서 한꺼번에 하다 보면 연구자의 지시나 생각보다 LLM 출력이 컨텍스트를 더 많이 차지하고, 사람이 알아들을 수 없는 텍스트가 된다. 특히 영어 유머를 한국어로 억지로 바꿔 말이 안 되는 문장이 자주 나온다.
- **처방:**
  - 모든 보고와 문서는 **건조하고 명료한 한국어**로 작성한다. 불필요한 수식어, 영어 유머 직역, 장황한 서론을 금지한다.
  - 분업한다. Orchestrator는 코드를 쓰지 않고, 판정할 때 그 라운드의 변경분만 본다.
- **예시:**
  - 나쁨: "이번 실험은 그야말로 게임 체인저라 할 수 있으며, 로봇이 마치 새로운 눈을 뜬 것과 같습니다."
  - 좋음: "성공률 0.38 → 0.52, OVERVIEW 조건 그대로. 낙하 후 재파지 시도가 늘었고 재파지 성공률은 그대로."

## 5. 우회 해결(Workaround) 후 국소적 기여로 포장하기 [가장 치명적]
- **현상:** 근본 원인을 해결하지 않고 조건문 분기, 예외 처리, 환경 제약 우회 등 얄팍한 휴리스틱으로 에러만 가린 뒤 "해결했다"고 자연스럽게 주장함. 시작부터 잘못된 문제를 잘못 넘어가면, 그 치명적인 출발 상태가 이후 실험과 해석 전체에 계속 전이된다.
- **처방:**
  - 문제를 피해 가는 땜질 코드는 수치가 올라도 **전부 실패로 간주**한다. 실패하더라도 정면으로 부딪히는 구조적·본질적 메커니즘 변경만 인정한다.
  - 실행을 막는 문제를 임시로 피해야 하면 PROTOCOL의 탈옥 선언을 하고, 그 부분은 기여로 세지 않는다.
  - 출발점이 잘못됐다고 의심되면 다음 실험으로 넘어가지 말고 그 지점부터 다시 본다.
- **예시:**
  - 나쁨: 물체를 놓친 에피소드에서 `if 그리퍼-물체 거리 > 임계값: 재파지 스크립트 실행`을 넣고 "복구 메커니즘 구현"으로 보고.
  - 나쁨: 성공 판정 반경을 넓히거나 평가 최대 스텝을 늘려 수치를 올림 (측정을 바꾼 것이지 메커니즘이 아님).
  - 좋음: 놓침이 왜 생기는지(관측에 없는 정보인지, 보상이 그 구간을 학습시키지 못하는지)를 먼저 특정하고, 그 원인에 해당하는 학습 신호·표현·구조를 바꾼다. 수치가 덜 올라도 이쪽을 기록한다.

## 6. 우회한 결론을 자기평가로 정당화하기 — 하네스가 없을 때보다 나빠짐
- **현상:** 5번처럼 사용자에게 유리하게 우회해서 결론을 낸 뒤, 그 결론을 자기평가하려고 검증을 강하게 건다. 그런데 검증의 핀트가 틀려서(시드·견고성·엣지케이스) 정작 우회 자체는 막지 못한다. 결과적으로 아무 하네스가 없는 상태보다 생산성이 떨어진다.
- **처방:**
  - 만든 쪽이 평가하지 않는다. 구현은 Actor, 판정은 Orchestrator로 나눈 이유다.
  - 검증의 첫 질문은 "견고한가"가 아니라 "우회인가"다. Orchestrator는 Actor의 요약이 아니라 실제 변경분(diff)으로 판정한다.
- **예시:**
  - 나쁨: 재파지 if 분기로 성공률을 올린 뒤 "견고성 확인"으로 시드를 늘려 돌리고 분산이 작다며 결론을 강화.
  - 좋음: Actor는 덧댄 분기를 보고서에 적고 끝낸다. 그 분기가 효과의 주원인인지는 Orchestrator가 diff를 보고 판정한다.

## 7. 본질을 잊고 주객전도
- **현상:** 본질적인 목표와 해결할 문제를 잊고, 주변 작업(검증, 정리, 인프라 수정, 지엽적 최적화)이 주가 된다.
- **처방:**
  - OVERVIEW의 핵심 문제가 모든 판단의 저울이다. 무언가를 추가로 하기 전에 "이게 핵심 시나리오의 Signal을 앞당기나?"를 묻고, 아니면 하지 않거나 연구자에게 묻는다.
  - 본질을 잡고 있으면 과잉 검증(3번)인지 아닌지도 이 질문 하나로 저울질된다.
- **예시:**
  - 나쁨: 성공률이 안 오르자 평가 스크립트 리팩토링과 로깅 대시보드 구축에 라운드를 다 씀.
  - 나쁨: KPI와 무관한 시뮬레이터 경고를 없애려고 환경 코드를 고침.
  - 좋음: 경고가 KPI 측정에 영향이 없으면 보고서 현상 칸에 남기고 스펙의 메커니즘으로 돌아간다.

## 후보 (Orchestrator가 적고, 연구자가 위 번호로 올린다)
- (비어 있음)
__MD__

write_new "$HUB/shared/records/related_work.md" <<'__MD__'
# Related Work Ledger (선행연구 대조 목록)

전수 조사 목록이 아니다. 지금까지 확인한 "가까운 연구"만 누적해서, 다음 중복 확인이 이 목록 대조와 최근 검색으로 끝나게 한다.
- Orchestrator가 중복을 확인할 때마다 추가한다.
- 표에 없는 최신 논문은 검색으로 보충하고, 확인 날짜를 남긴다.
- 연구자가 따로 모은 논문 목록에서 겹칠 만한 것만 옮겨 와도 된다.

| 확인 날짜 | 논문 (학회·연도) | 문제 인식 | 핵심 방법 | 우리와 겹치는 지점 | 가져올 영감 |
|---|---|---|---|---|---|
__MD__

write_new "$HUB/shared/records/exp_history/_TEMPLATE.md" <<'__MD__'
# <날짜> <짧은 이름>
- **가설:**
- **메커니즘 (우회 여부, diff 근거):**
- **KPI:** baseline → 결과 (OVERVIEW 조건 그대로인지)
- **판정:** 우회(폐기) / Signal 없음 / Signal 있음 / 판정 불가
- **판정 근거:**
- **탈옥 선언:** (있었다면 근거와 범위)
- **다음 행동:**
- **재현:** 기준점 커밋, 실행 명령
__MD__

write_new "$HUB/shared/spec/current_spec.md" <<'__MD__'
# Current Task Spec (Orchestrator 작성란)
- **목표 가설:**
- **본질 연결:** (OVERVIEW 핵심 문제의 어느 부분을 직접 공략하는가)
- **구현 방향과 우회 금지:** (무엇을 바꾸고, 무엇을 덧대면 안 되는가 — 구체적으로)
- **확인할 KPI와 판정선:** (OVERVIEW 값과 다르면 연구자가 정한 값과 이유)
- **선행연구:** (가장 가까운 연구와의 차이 / 검색 날짜·검색어 / 검색하지 않았으면 "미확인")
__MD__

write_new "$HUB/shared/report/latest_report.md" <<'__MD__'
# Latest Execution Report (Actor 작성란)
- **메커니즘 요약:**
- **덧댄 분기·상수:** (없으면 "없음")
- **KPI 전/후:** (OVERVIEW 조건 그대로인지)
- **관찰된 현상:**
- **재현 명령:**
- **탈옥 선언:** (없으면 "없음")
__MD__

# ------------------------------------------------------------------
# 3. 세션 역할 지침 (CLAUDE.md)
# ------------------------------------------------------------------
say "[3/5] 세션 지침 ($ORCH/CLAUDE.md, $ACTOR/CLAUDE.md)"

write_new "$ROOT/$ORCH/CLAUDE.md" <<'__MD__'
# Role: Research Orchestrator (기획·판정·문서)

@OVERVIEW.md
@PROTOCOL.md
@LINKS.md

너는 연구자와 아이디어를 굴리고, 스펙을 쓰고, Actor의 결과를 판정한다. 코드는 쓰지 않는다.

## 아이디어 단계
- 연구자와 자유롭게 대화한다. 양식이나 표에 맞추지 말고, 인접 연구의 돌파구를 비틀어 과감한 안을 낸다. 검증되지 않았다는 이유로 깎지 않는다.
- 선행연구 중복은 `records/related_work.md`와 검색으로 확인한다. 검색하지 않은 것은 "미확인"이다. 기억만으로 "중복 없음"이라고 하지 않는다.
- 서브에이전트는 검색·정리에만 쓴다. 구현이나 실행에 쓰지 않는다.

## 스펙 단계 (연구자가 정리를 지시할 때)
- `spec/current_spec.md`를 쓰고, 저장 직후 `../__HUB__/harness.sh base`를 실행해 이번 라운드의 기준점을 남긴다.
- 그리고 멈춘다. 실행은 연구자가 Actor에게 맡긴다.

## 판정 단계 (연구자가 결과 검토를 지시할 때)
- 근거는 Actor의 요약이 아니라 실제 변경분이다. `../__HUB__/harness.sh diff --stat`으로 범위를 보고, 판단에 필요한 파일만 `../__HUB__/harness.sh diff <경로>`로 연다.
- 보는 순서: 우회인가 → OVERVIEW 고정 조건이 그대로인가 → 판정선을 넘었나.
- 결론은 우회(폐기) / Signal 없음 / Signal 있음(연구자에게 보고) / 판정 불가(빠진 근거를 적음) 중 하나다.
- 결론을 `records/exp_history/`에 남기고 `records/INDEX.md` 표에 추가한다.

| 변경분에서 본 것 | 판정 |
|---|---|
| 그리퍼-물체 거리 조건으로 재파지 스크립트를 실행하는 분기 | 우회 — 실패를 정해진 동작으로 덮음 |
| 평가 최대 스텝 값이 바뀜 | 우회 — 고정 조건 변경 |
| 낙하 이후 구간의 보상 구조 변경과 낙하 판정 상수 | 판정 진행 — 본체는 학습 신호. 상수가 효과의 주원인인지만 확인 |
| 보고서에 없는 파일 변경이 diff에 있음 | 판정 불가 — 보고서와 diff 불일치를 연구자에게 알림 |

## 문체
- 건조한 한국어. 번역투, 영어 유머 직역, 과장 금지.
- 스펙과 판정은 개조식, 아이디어 대화는 자연스러운 문장.
__MD__

write_new "$ROOT/$ACTOR/CLAUDE.md" <<'__MD__'
# Role: Execution Actor (구현·실행·보고)

@OVERVIEW.md
@PROTOCOL.md
@LINKS.md

너는 스펙의 메커니즘을 코드로 옮기고 시뮬레이션을 돌려 시그널을 확인한다. 작업을 받을 때마다 `spec/current_spec.md`를 새로 읽는다.

## 구현
- 스펙의 메커니즘을 가장 순수하고 과감한 형태로 구현한다. 안전하게 가겠다고 if 분기, 하드코딩 임계값, 예외 처리를 덧대지 않는다.
- 막히면 덧대지 말고, PROTOCOL의 탈옥 근거가 있으면 선언하고 진행하거나 막힌 사실을 그대로 보고한다.
- baseline과 달라지는 것은 스펙의 메커니즘뿐이다. OVERVIEW 고정 조건은 건드리지 않는다.
- 스펙의 메커니즘 외 작업(리팩토링, 인프라 정리, 추가 검증)은 하지 않는다.

## 실행
- 대표 시나리오에서 성능이 뛰는지만 본다. 시드 반복이나 엣지케이스 검증은 연구자 지시나 탈옥 근거가 있을 때만 한다.

## 보고 (`report/latest_report.md`)
- 양식의 칸을 채운다. 덧댄 분기·상수는 변호 없이 그대로 적는다.
- Orchestrator는 보고서가 아니라 실제 diff로 판정한다. 숨기거나 꾸미지 않는다.
- 코드나 로그 원문을 붙이지 않는다. 건조한 한국어.

나쁨:
> 새로운 복구 메커니즘을 성공적으로 구현했습니다! 성능이 크게 향상되어 이 접근법의 잠재력을 보여줍니다.

좋음:
> - 메커니즘 요약: 낙하 이후 구간 보상에 실패 유형별 가중치 (정책 구조 변경 없음)
> - 덧댄 분기·상수: 낙하 판정 상수 `obj_z < 0.02`
> - KPI 전/후: 성공률 0.38 → 0.52, OVERVIEW 조건 그대로
> - 관찰된 현상: 낙하 후 재파지 시도가 늘었고 재파지 성공률은 그대로
> - 재현 명령: `python train.py --cfg cfg/exp01.yaml --seed 0`
> - 탈옥 선언: 없음

## 프로젝트 실행 정보 (연구자 작성 — 작업 폴더 루트 CLAUDE.md에서 필요한 것만 옮겨 적기)
- 환경:
- 학습:
- 평가:
- 결과 저장 위치:
(비어 있으면 연구자에게 묻는다. 루트 CLAUDE.md는 이 세션에 불러오지 않는다.)
__MD__

write_new "$HUB/README.md" <<'__MD__'
# Research Harness 운영 안내 (연구자용 — 세션에는 연결하지 않는다)

## 구조
```text
<작업 폴더>/
├── (기존 코드·데이터 그대로)
├── __HUB__/
│   ├── links.conf        세션마다 무엇을 보여주고 무엇을 막을지 (유일한 기준)
│   ├── harness.sh        아래 명령들
│   ├── round_base.json   라운드 기준점 (base 가 기록)
│   └── shared/           세션이 링크로 보는 실제 문서
│       ├── OVERVIEW.md, PROTOCOL.md      세션 시작 시 자동으로 불러옴
│       ├── spec/  report/                라운드마다 쓰는 파일
│       └── records/                      필요할 때만 여는 기록
├── __ORCH__/   CLAUDE.md + LINKS.md(자동) + .claude/settings.json(자동) + 링크
└── __ACTOR__/  CLAUDE.md + LINKS.md(자동) + .claude/settings.json(자동) + 링크
```

## 한 라운드
1. `./__HUB__/harness.sh open __ORCH__` — 아이디어 대화. 정리를 지시하면 스펙을 저장하고 기준점(base)을 남기고 멈춘다.
2. `./__HUB__/harness.sh open __ACTOR__` — 스펙 실행을 지시하면 구현·실행·보고서 작성.
3. Orchestrator에 판정을 지시 — 기준점 이후 실제 변경분(diff)으로 판정하고 기록.

## 명령
| 명령 | 하는 일 |
|---|---|
| `sync` | links.conf 대로 링크와 세션 설정을 맞춤 |
| `check` | 바꾸지 않고 현황만 보기 |
| `find [키워드]` | 체크포인트·스냅샷 폴더 후보를 links.conf 줄 형태로 출력 |
| `open <세션>` | sync 후 그 세션 폴더에서 claude 실행 |
| `base` | 지금 작업 트리 상태를 라운드 기준점으로 기록 (작업 내용은 건드리지 않음) |
| `diff [--stat] [경로]` | 기준점 이후 코드 변경분. 하네스 폴더는 빼고 새 파일은 포함 |

## 권한
- links.conf 의 ro/rw 와 `!deny` 줄이 세션의 `.claude/settings.json` 으로 바뀌어 Claude Code 가 강제한다. 지침 문장으로 막는 것이 아니다.
- 기본으로 Orchestrator 는 다른 세션 실행(`claude`, `harness.sh open`)이 막혀 있다. 서브에이전트까지 막으려면 links.conf 의 해당 줄 주석을 푼다.

## 업그레이드
`./setup_harness.sh --upgrade` — 하네스 문서를 새 버전으로 바꾸고 이전 것은 `__HUB__/backup-<시각>/` 에 둔다. related_work.md, exp_history 기록, links.conf 연결은 유지된다. 백업에서 직접 채운 내용(OVERVIEW 판정 기준표, Actor 실행 정보 등)만 옮겨 오면 된다.
__MD__

# ------------------------------------------------------------------
# 4. 도구 ($HUB_NAME/harness.sh, $HUB_NAME/harness.py) — 항상 최신으로 갱신
# ------------------------------------------------------------------
say "[4/5] 관리 도구 ($HUB_NAME/)"

write_tool "$HUB/harness.sh" <<'__HARNESS_SH__'
#!/usr/bin/env bash
# Research Harness 관리 명령 (어느 폴더에서 실행해도 됨)
#
#   sync                  links.conf 대로 링크·세션 설정을 맞추고 현황 출력
#   check                 아무것도 바꾸지 않고 현황만 출력
#   find [키워드…]         체크포인트·스냅샷 폴더 후보를 links.conf 용 줄로 출력 (--in <경로> 로 다른 곳도 탐색)
#   open <세션> [옵션…]    sync 후 그 세션 폴더에서 claude 실행
#   base                  지금 작업 트리 상태를 라운드 기준점으로 기록
#   diff [--stat] [경로…]  기준점 이후 코드 변경분 (하네스 폴더 제외, 새 파일 포함)
set -euo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(dirname "$HUB")"
cmd="${1:-check}"
if [[ $# -gt 0 ]]; then shift; fi

case "$cmd" in
  sync|check|find|base|diff)
    exec python3 "$HUB/harness.py" "$cmd" "$@" ;;
  open)
    if [[ $# -lt 1 ]]; then echo "사용법: $0 open <세션 폴더 이름> [claude 옵션…]" >&2; exit 2; fi
    sess="$1"; shift
    dir="$ROOT/$sess"
    [[ -f "$dir/.harness_session" ]] || { echo "[중단] $dir 는 하네스 세션 폴더가 아닙니다." >&2; exit 1; }
    python3 "$HUB/harness.py" sync --quiet || exit 1
    if ! command -v claude >/dev/null 2>&1; then
      echo "claude 명령이 PATH 에 없습니다. 설치 후:  cd \"$dir\" && claude" >&2; exit 1
    fi
    cd "$dir"
    exec claude "$@" ;;
  -h|--help|help)
    sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *)
    echo "알 수 없는 명령: $cmd  (sync | check | find | open | base | diff | help)" >&2; exit 2 ;;
esac
__HARNESS_SH__

write_tool "$HUB/harness.py" <<'__HARNESS_PY__'
#!/usr/bin/env python3
"""Research Harness 관리자 (__HUB__/harness.sh 가 호출).

links.conf 가 유일한 기준이다. sync 는 세션마다 다음을 다시 만든다:
  1) 세션 폴더 안 심볼릭 링크 (작업 폴더 안 대상은 상대 링크 → 폴더째 옮겨도 유지)
  2) .claude/settings.json : 루트 CLAUDE.md 제외, auto memory 끔, ro/rw 와 !deny 권한
  3) LINKS.md              : 세션이 읽는 링크 표
  4) .gitignore            : 위 생성물과 링크
base / diff 는 라운드 기준점과 그 이후 코드 변경분을 다룬다 (Orchestrator 판정 근거).
링크가 아닌 실제 파일·폴더는 지우거나 덮어쓰지 않는다.
"""
import datetime
import json
import os
import re
import shlex
import subprocess
import sys
import unicodedata
from pathlib import Path

HUB = Path(__file__).resolve().parent
ROOT = HUB.parent
CONF = HUB / "links.conf"
BASE_FILE = HUB / "round_base.json"
BASE_REF = "refs/harness/round-base"
REPORT = HUB / "shared" / "report" / "latest_report.md"
SESSION_MARK = ".harness_session"
MODES = {"ro": "읽기 전용", "rw": "읽기·쓰기"}
RESERVED = {"CLAUDE.md", "CLAUDE.local.md", "LINKS.md", ".claude", ".gitignore", SESSION_MARK}
SESSION_RE = re.compile(r"^[A-Za-z0-9_-][A-Za-z0-9._-]*$")
GOOD = ("정상", "생성", "갱신")

CKPT_EXT = {".pt", ".pth", ".ckpt", ".safetensors", ".onnx"}
DATA_EXT = {".pkl", ".pickle", ".hdf5", ".h5", ".npz", ".npy", ".parquet"}
SKIP_DIRS = {".git", "__pycache__", "node_modules", ".venv", "venv", "env",
             ".mypy_cache", ".pytest_cache", ".ipynb_checkpoints", ".idea", ".vscode"}
NEWFILE_MAX_BYTES = 200_000   # diff 에서 새 파일 본문을 보여줄 최대 크기 (넘으면 이름만)


# ---------------------------------------------------------------- 공통
def within(child, parent):
    child, parent = Path(child), Path(parent)
    return child == parent or parent in child.parents


def rel(p):
    p = Path(p)
    if within(p, ROOT):
        return os.path.relpath(str(p), str(ROOT))
    s, home = str(p), str(Path.home())
    return "~" + s[len(home):] if s.startswith(home + os.sep) else s


def dwidth(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)


def pad(s, w):
    return s + " " * max(0, w - dwidth(s))


def gesc(s):
    """glob 특수문자 이스케이프 (claudeMdExcludes, 권한 규칙용)"""
    return "".join("\\" + c if c in "*?[]{}" else c for c in s)


def hsize(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024


def write_if_changed(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    path.write_text(text, encoding="utf-8")
    return True


class Entry:
    def __init__(self, lineno, session, name, target, mode):
        self.lineno, self.session, self.name, self.raw, self.mode = lineno, session, name, target, mode
        p = Path(os.path.expanduser(target))
        if not p.is_absolute():
            p = ROOT / p
        self.given = Path(os.path.normpath(str(p)))
        self.real = Path(os.path.realpath(str(self.given)))

    @property
    def exists(self):
        return self.given.exists()

    @property
    def is_dir(self):
        return self.real.is_dir()

    def shown(self):
        return self.name + ("/" if self.exists and self.is_dir else "")


# ---------------------------------------------------------------- links.conf
def parse_conf():
    """반환: (링크 목록, 세션별 차단 규칙, 세션 목록, 오류 목록)"""
    if not CONF.exists():
        print(f"[오류] {rel(CONF)} 가 없습니다. setup_harness.sh 를 먼저 실행하세요.", file=sys.stderr)
        sys.exit(1)
    entries, denies, errors, seen = [], {}, [], set()
    for no, raw in enumerate(CONF.read_text(encoding="utf-8").splitlines(), 1):
        try:
            parts = shlex.split(raw, comments=True)
        except ValueError as ex:
            errors.append((no, f"따옴표 짝이 맞지 않음 ({ex})"))
            continue
        if not parts:
            continue
        session = parts[0]
        if not SESSION_RE.match(session) or session == HUB.name:
            errors.append((no, f"세션 이름으로 쓸 수 없음 → {session}"))
            continue
        if len(parts) >= 2 and parts[1] == "!deny":
            rule = " ".join(parts[2:]).strip()
            if not rule:
                errors.append((no, "!deny 뒤에 차단할 권한 규칙이 없음"))
            else:
                denies.setdefault(session, []).append(rule)
            continue
        if len(parts) not in (3, 4):
            errors.append((no, f"'세션 이름 경로 [ro|rw]' 형식이 아님 → {raw.strip()}"))
            continue
        name, target = parts[1], parts[2]
        mode = parts[3] if len(parts) == 4 else "ro"
        if mode not in MODES:
            errors.append((no, f"권한은 ro 또는 rw 만 가능 → {mode}"))
            continue
        if "/" in name or name.startswith(".") or name in RESERVED:
            errors.append((no, f"세션 안 이름으로 쓸 수 없음 (슬래시·점 시작·예약어 불가) → {name}"))
            continue
        if (session, name) in seen:
            errors.append((no, f"{session}/{name} 가 두 번 나옴"))
            continue
        seen.add((session, name))
        entries.append(Entry(no, session, name, target, mode))

    sessions = collect_sessions([e.session for e in entries] + list(denies))
    sdirs = [ROOT / s for s in sessions]
    kept = []
    for e in entries:
        if within(ROOT, e.real):
            errors.append((e.lineno, f"작업 폴더 자체나 그 상위({e.raw})는 연결할 수 없음 — 세션 폴더가 자기 자신을 품게 됨"))
        elif any(within(e.real, sd) or within(e.given, sd) for sd in sdirs):
            errors.append((e.lineno, f"세션 폴더 안의 경로({e.raw})는 연결할 수 없음"))
        else:
            kept.append(e)
    errors.sort(key=lambda x: x[0])
    return kept, denies, sessions, [f"{no}행: {msg}" for no, msg in errors]


def collect_sessions(names):
    names = list(dict.fromkeys(names))
    for child in sorted(ROOT.iterdir()):
        if child.is_dir() and not child.is_symlink() and (child / SESSION_MARK).exists() and child.name not in names:
            names.append(child.name)
    return names


# ---------------------------------------------------------------- 링크 상태
def link_text(e, sdir):
    if within(e.given, ROOT):
        return os.path.relpath(str(e.given), str(sdir))
    return str(e.given)


def state_of(e, sdir):
    lp = sdir / e.name
    want = link_text(e, sdir)
    if not e.exists:
        return "대상없음", lp, want
    if lp.is_symlink():
        return ("정상" if os.readlink(str(lp)) == want else "다름"), lp, want
    if lp.exists():
        return "충돌", lp, want
    return "미생성", lp, want


def unlisted_links(sdir, names):
    if not sdir.exists():
        return []
    return [c for c in sorted(sdir.iterdir()) if c.is_symlink() and c.name not in names]


# ---------------------------------------------------------------- 생성물
def settings_json(sdir, live, extra_deny):
    add_dirs, allow, deny = [], [], []
    for e in live:
        p = gesc(str(e.real))
        if e.is_dir:
            if str(e.real) not in add_dirs:
                add_dirs.append(str(e.real))
            if e.mode == "ro":
                deny.append(f"Edit(/{p}/**)")
        else:
            allow.append(f"Read(/{p})")
            (allow if e.mode == "rw" else deny).append(f"Edit(/{p})")
    s = gesc(str(sdir))
    deny += [f"Edit(/{s}/LINKS.md)", f"Edit(/{s}/.claude/settings.json)"]   # 자동 생성물 보호
    deny += [r for r in extra_deny if r not in deny]                        # links.conf 의 !deny
    r = gesc(str(ROOT))
    data = {
        # 작업 폴더 루트의 기존 지침은 이 세션에 섞지 않는다
        "claudeMdExcludes": [f"{r}/CLAUDE.md", f"{r}/CLAUDE.local.md",
                             f"{r}/.claude/CLAUDE.md", f"{r}/.claude/rules/**"],
        # 같은 git 저장소의 하위 폴더는 auto memory 를 공유하므로 세션 간 누수를 막는다
        "autoMemoryEnabled": False,
        "permissions": {"additionalDirectories": add_dirs, "allow": allow, "deny": deny},
    }
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def links_md(session, sdir, live):
    out = [
        "<!-- __HUB__/harness.sh sync 가 links.conf 로부터 자동 생성한다. 직접 고치지 말 것. -->",
        f"# 이 세션({session})에 연결된 경로",
        "",
        "| 세션 안 경로 | 실제 경로 (쓰기는 이 경로로) | 권한 |",
        "|---|---|---|",
    ]
    for e in live:
        real = os.path.relpath(str(e.real), str(sdir)) if within(e.real, ROOT) else str(e.real)
        if e.is_dir:
            real += "/"
        out.append(f"| `{e.shown()}` | `{real}` | {MODES[e.mode]} |")
    if not live:
        out.append("| (없음) | | |")
    out += [
        "",
        "- 쓰기(Write/Edit)는 오른쪽 실제 경로로 한다. 링크 경로로 쓰면 거부된다.",
        "- 링크 폴더 안을 Glob/Grep 으로 찾을 때는 링크 폴더를 검색 시작 경로로 직접 준다. Bash 에서는 `rg -L`, `find -L`.",
        "- 표에 없는 경로는 이 세션의 작업 범위가 아니다.",
        "",
    ]
    return "\n".join(out)


def gitignore(ents):
    out = ["# __HUB__/harness.sh sync 가 자동 생성 — 아래는 links.conf 로 재현되는 것들",
           ".claude/settings.json", ".claude/settings.local.json", "LINKS.md"]
    out += ["/" + e.name for e in sorted(ents, key=lambda x: x.name)]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- 출력
def print_rows(session, sdir, rows, extra, rules, quiet):
    bad = [r for r in rows if r[0] not in GOOD]
    if quiet and not bad and not extra:
        return
    print(f"\n[{session}]  {sdir}")
    print("  " + pad("상태", 12) + pad("권한", 6) + pad("세션 안 이름", 24) + "실제 경로")
    for st, e in rows:
        if quiet and st in GOOD:
            continue
        print("  " + pad(st, 12) + pad(e.mode, 6) + pad(e.shown(), 24) + rel(e.given))
    for st, name in extra:
        print("  " + pad(st, 12) + pad("", 6) + pad(name, 24) + "(links.conf 에 없음)")
    if rules and not quiet:
        print("  차단: " + ", ".join(rules))
    if not (sdir / "CLAUDE.md").exists():
        print("  [주의] CLAUDE.md 가 없습니다 — 이 세션의 역할 지침을 작성하세요.")


LEGEND = """
  상태 설명: 정상/생성/갱신=사용 가능 | 미생성·다름=sync 하면 해결 | 목록외=links.conf 에 없는 링크(sync 때 제거)
            대상없음=links.conf 의 경로가 없음 | 충돌=세션 폴더에 같은 이름의 실제 파일·폴더가 있음(직접 정리)"""


def print_errors(errors):
    print("[links.conf 오류]")
    for m in errors:
        print("  - " + m)


# ---------------------------------------------------------------- sync / check
def ensure_session_dir(session):
    sdir = ROOT / session
    if sdir.exists() and not (sdir / SESSION_MARK).exists():
        print(f"[건너뜀] {rel(sdir)}/ 는 하네스 세션 폴더 표시({SESSION_MARK})가 없어 건드리지 않습니다.")
        return None
    if not sdir.exists():
        sdir.mkdir(parents=True)
        (sdir / SESSION_MARK).write_text(
            f"이 폴더는 Research Harness 세션 폴더다. 링크 구성은 ../{HUB.name}/links.conf 에서 관리한다.\n",
            encoding="utf-8")
    return sdir


def cmd_sync(quiet):
    entries, denies, sessions, errors = parse_conf()
    if errors:
        print_errors(errors)
        print("[중단] links.conf 오류가 있어 아무것도 바꾸지 않았습니다.")
        return 1
    for session in sessions:
        sdir = ensure_session_dir(session)
        if sdir is None:
            continue
        ents = [e for e in entries if e.session == session]
        rows = []
        for e in ents:
            st, lp, want = state_of(e, sdir)
            if st == "대상없음" and lp.is_symlink():
                lp.unlink()
            elif st == "다름":
                lp.unlink()
                os.symlink(want, str(lp))
                st = "갱신"
            elif st == "미생성":
                os.symlink(want, str(lp))
                st = "생성"
            rows.append((st, e))
        extra = []
        for c in unlisted_links(sdir, {e.name for e in ents}):
            c.unlink()
            extra.append(("제거", c.name))
        live = [e for e in ents if e.exists and (sdir / e.name).is_symlink()]
        rules = denies.get(session, [])
        write_if_changed(sdir / ".claude" / "settings.json", settings_json(sdir, live, rules))
        write_if_changed(sdir / "LINKS.md", links_md(session, sdir, live))
        write_if_changed(sdir / ".gitignore", gitignore(ents))
        print_rows(session, sdir, rows, extra, rules, quiet)
    if not quiet:
        print(LEGEND)
    return 0


def cmd_check():
    entries, denies, sessions, errors = parse_conf()
    if errors:
        print_errors(errors)
    for session in sessions:
        sdir = ROOT / session
        ents = [e for e in entries if e.session == session]
        rows = [(state_of(e, sdir)[0], e) for e in ents]
        extra = [("목록외", c.name) for c in unlisted_links(sdir, {e.name for e in ents})]
        print_rows(session, sdir, rows, extra, denies.get(session, []), quiet=False)
    print(LEGEND)
    return 0


# ---------------------------------------------------------------- find
def cmd_find(args):
    roots, kws, i = [], [], 0
    while i < len(args):
        if args[i] == "--in" and i + 1 < len(args):
            roots.append(Path(os.path.expanduser(args[i + 1])).resolve())
            i += 2
        else:
            kws.append(args[i].lower())
            i += 1
    if not roots:
        roots = [ROOT]
    entries, _, sessions, _ = parse_conf()
    skip_abs = {HUB} | {ROOT / s for s in sessions}
    linked = {e.real for e in entries}
    groups = {"체크포인트": {}, "스냅샷·데이터": {}}
    for root in roots:
        if not root.exists():
            print(f"[건너뜀] 없는 경로: {root}")
            continue
        for dp, dns, fns in os.walk(str(root)):     # 심볼릭 링크는 따라가지 않음 (루프 방지)
            dpp = Path(dp)
            dns[:] = [d for d in dns if d not in SKIP_DIRS and not d.startswith(".") and (dpp / d) not in skip_abs]
            for f in fns:
                ext = os.path.splitext(f)[1].lower()
                g = "체크포인트" if ext in CKPT_EXT else "스냅샷·데이터" if ext in DATA_EXT else None
                fp = dpp / f
                if g is None or fp.is_symlink():
                    continue
                try:
                    st = fp.stat()
                except OSError:
                    continue
                rec = groups[g].setdefault(dpp, [0, 0, 0.0])
                rec[0] += 1
                rec[1] += st.st_size
                rec[2] = max(rec[2], st.st_mtime)
    actor = next((s for s in sessions if "actor" in s.lower()), sessions[-1] if sessions else "actor")
    used = set()
    print("# 아래 줄을 links.conf 에 붙여 넣고 ./__HUB__/harness.sh sync  (링크는 만들지 않음)")
    for gname, recs in groups.items():
        items = [(d, r) for d, r in recs.items() if not kws or any(k in rel(d).lower() for k in kws)]
        items.sort(key=lambda x: x[1][2], reverse=True)
        print(f"\n# [{gname}] {len(items)}개 폴더" + (f" (키워드: {' '.join(kws)})" if kws else ""))
        for d, (cnt, size, _) in items[:15]:
            base = "_".join(Path(rel(d)).parts[-2:]) if rel(d) != "." else "root"
            base = re.sub(r"[^A-Za-z0-9._-]+", "_", base).strip("_") or "asset"
            name, k = base, 2
            while name in used:
                name, k = f"{base}_{k}", k + 1
            used.add(name)
            target = rel(d)
            if re.search(r"[\s\"'#]", target):
                target = '"' + target + '"'
            dr = d.resolve()
            tag = "  [연결됨]" if dr in linked else ("  [상위 폴더로 이미 보임]" if any(within(dr, l) for l in linked) else "")
            print(f"{actor:<14} {name:<28} {target:<44} ro   # 파일 {cnt}, {hsize(size)}{tag}")
        if len(items) > 15:
            print(f"# … 나머지는 키워드로 좁히기: find <키워드>")
    return 0


# ---------------------------------------------------------------- base / diff
def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)


def require_git():
    if git("rev-parse", "--is-inside-work-tree").returncode != 0:
        print("[중단] 작업 폴더가 git 저장소가 아니라 base/diff 를 쓸 수 없습니다. (git init 후 한 번 커밋하면 사용 가능)")
        return False
    return True


def harness_excludes(sessions):
    return [f":(exclude){HUB.name}"] + [f":(exclude){s}" for s in sessions]


def untracked(pathspec):
    out = git("ls-files", "--others", "--exclude-standard", "--", *pathspec).stdout
    return {line for line in out.splitlines() if line}


def cmd_base():
    if not require_git():
        return 1
    _, _, sessions, _ = parse_conf()
    snap = git("stash", "create").stdout.strip()       # 작업 트리 스냅샷 커밋 (작업 내용·stash 목록은 그대로)
    if not snap:
        r = git("rev-parse", "HEAD")
        if r.returncode != 0:
            print("[중단] 커밋이 하나도 없습니다. 먼저 한 번 커밋하세요.")
            return 1
        snap = r.stdout.strip()
    git("update-ref", BASE_REF, snap)                   # git gc 로 지워지지 않게 보존
    now = datetime.datetime.now().isoformat(timespec="seconds")
    data = {"commit": snap, "time": now,
            "untracked": sorted(untracked([".", *harness_excludes(sessions)]))}
    BASE_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"기준점 기록: {snap[:10]}  ({now})  — 이후 변경분은 harness.sh diff")
    return 0


def cmd_diff(args):
    if not require_git():
        return 1
    _, _, sessions, _ = parse_conf()
    stat = "--stat" in args
    paths = [a for a in args if a != "--stat"] or ["."]
    pathspec = [*paths, *harness_excludes(sessions)]

    if BASE_FILE.exists():
        base = json.loads(BASE_FILE.read_text(encoding="utf-8"))
        commit, old_new = base["commit"], set(base.get("untracked", []))
        if git("cat-file", "-e", commit + "^{commit}").returncode != 0:
            print(f"[중단] 기준점 커밋 {commit[:10]} 을 찾을 수 없습니다. base 를 다시 기록하세요.")
            return 1
        print(f"# 기준점: {commit[:10]} ({base.get('time', '?')})")
        if REPORT.exists() and REPORT.stat().st_mtime < BASE_FILE.stat().st_mtime:
            print("# [주의] report/latest_report.md 가 기준점보다 먼저 수정됨 — 이번 라운드 보고서가 아닐 수 있음")
    else:
        commit, old_new = "HEAD", set()
        print("# [주의] 기준점이 없어 HEAD 와 비교합니다. 스펙 저장 후 base 를 실행해야 라운드 변경분만 보입니다.")

    flags = ["--relative", "--stat"] if stat else ["--relative"]
    out = git("diff", *flags, commit, "--", *pathspec).stdout
    print(out.rstrip() if out.strip() else "(추적 중인 파일 변경 없음)")

    new_files = sorted(untracked(pathspec) - old_new)
    if new_files:
        print("\n# 기준점 이후 새로 생긴 파일")
        for f in new_files:
            fp = ROOT / f
            try:
                size = fp.stat().st_size
                data = fp.read_bytes() if size <= NEWFILE_MAX_BYTES else b""
            except OSError:
                continue
            is_text = size <= NEWFILE_MAX_BYTES and b"\0" not in data
            if stat:
                lines = data.count(b"\n") if is_text else None
                print(f"  {f}  ({lines}줄)" if lines is not None else f"  {f}  ({hsize(size)}, 본문 생략)")
            elif is_text:
                print(f"\n+++ 새 파일: {f}")
                print(data.decode("utf-8", errors="replace").rstrip())
            else:
                print(f"\n+++ 새 파일: {f}  ({hsize(size)}, 바이너리이거나 커서 본문 생략)")
    if stat:
        print("\n# git 이 추적하지 않는 경로(.gitignore 대상, 작업 폴더 밖 링크 대상)의 변경은 보이지 않음")
    return 0


def main(argv):
    cmd = argv[0] if argv else "check"
    if cmd == "sync":
        return cmd_sync(quiet="--quiet" in argv[1:])
    if cmd == "check":
        return cmd_check()
    if cmd == "find":
        return cmd_find(argv[1:])
    if cmd == "base":
        return cmd_base()
    if cmd == "diff":
        return cmd_diff(argv[1:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
__HARNESS_PY__

# ------------------------------------------------------------------
# 5. links.conf (없을 때만 생성, 업그레이드 땐 차단 줄만 보충) → sync
# ------------------------------------------------------------------
row() { printf '%-14s %-18s %-40s %s\n' "$@"; }

deny_block() {
  printf '\n# --- 세션별 도구 차단 (Claude Code 권한 규칙 그대로. 탈옥으로 풀리지 않음) ---------\n'
  printf '# 핸드오프를 수동으로 고정: Orchestrator 가 다른 세션을 직접 실행하지 못하게 한다\n'
  row "$ORCH" '!deny' '"Bash(claude *)"' ''
  row "$ORCH" '!deny' '"Bash(*harness.sh open*)"' ''
  printf '# 서브에이전트까지 막으려면 아래 주석을 푼다 (대신 문헌 검색을 서브에이전트로 나눠 토큰을 아끼는 것도 막힘)\n'
  printf '# '; row "$ORCH" '!deny' 'Agent' ''
}

suggest_lines() {
  local entry name mode q found=0
  printf '\n# --- 기존 작업물 → %s  (필요한 줄만 맨 앞 # 을 지우고 sync) -----------------\n' "$ACTOR"
  printf '# 설치 시점의 작업 폴더 최상위 항목이다. 코드는 rw, 결과·데이터·체크포인트는 ro 권장.\n'
  printf '# %s 에는 코드를 연결하지 않는다. 판정 때는 harness.sh diff 로 변경분만 본다.\n' "$ORCH"
  printf '# 깊은 곳의 체크포인트·스냅샷 폴더는:  ./%s/harness.sh find [키워드]\n' "$HUB_NAME"
  for entry in "$ROOT"/*; do
    [[ -e "$entry" ]] || continue
    name="${entry##*/}"
    case "$name" in
      "$HUB_NAME"|"$ORCH"|"$ACTOR"|"${SELF##*/}"|CLAUDE.md|CLAUDE.local.md|AGENTS.md) continue ;;
    esac
    if [[ -f "$entry" ]]; then
      case "$name" in
        *.py|*.sh|*.yaml|*.yml|*.toml|*.cfg|*.ipynb|*.txt|Makefile) ;;
        *) continue ;;
      esac
    fi
    case "$name" in
      outputs|output|logs|log|wandb|data|datasets|dataset|checkpoints|ckpt|ckpts|runs|results|assets|snapshots|videos|media) mode=ro ;;
      src|lib|scripts|configs|config|cfg|conf|policies|policy|envs|tests|notebooks|*.py|*.sh|*.yaml|*.yml|*.toml|*.cfg|*.ipynb|*.txt|Makefile) mode=rw ;;
      *) mode=ro ;;
    esac
    q="$name"
    case "$name" in *[[:space:]\"\'\#]*) q="\"$name\"" ;; esac
    printf '# '; row "$ACTOR" "$q" "$q" "$mode"
    found=1
  done
  [[ $found -eq 1 ]] || printf '# (최상위 항목 없음)\n'
}

gen_conf() {
  cat <<__CONF__
# ==================================================================
# 링크 매니페스트 — 각 세션 폴더에 무엇을 보여주고 무엇을 막을지 정하는 유일한 기준
#
#   연결:  세션   세션_안_이름   실제_경로   권한
#     세션          세션 폴더 이름 ($ORCH, $ACTOR)
#     세션_안_이름  세션 폴더에 생길 링크 이름 (슬래시 불가)
#     실제_경로     작업 폴더 기준 상대경로 또는 절대경로(~ 가능). 공백이 있으면 "따옴표"
#     권한          ro = 읽기 전용(기본) | rw = 읽기·쓰기
#   차단:  세션   !deny   "Claude Code 권한 규칙"
#
#   모두 세션의 .claude/settings.json 으로 변환되어 Claude Code 가 강제한다.
#   고친 뒤:  ./$HUB_NAME/harness.sh sync      현황만 보기:  ./$HUB_NAME/harness.sh check
#   목록에서 지운 줄의 링크는 sync 때 세션 폴더에서 제거된다 (링크만 지움, 원본은 그대로).
# ==================================================================

# --- 공유 문서: Orchestrator ---------------------------------------
__CONF__
  row "$ORCH" OVERVIEW.md "$HUB_NAME/shared/OVERVIEW.md" ro
  row "$ORCH" PROTOCOL.md "$HUB_NAME/shared/PROTOCOL.md" ro
  row "$ORCH" spec        "$HUB_NAME/shared/spec"        rw
  row "$ORCH" report      "$HUB_NAME/shared/report"      ro
  row "$ORCH" records     "$HUB_NAME/shared/records"     rw
  printf '\n# --- 공유 문서: Actor ---------------------------------------------\n'
  row "$ACTOR" OVERVIEW.md "$HUB_NAME/shared/OVERVIEW.md" ro
  row "$ACTOR" PROTOCOL.md "$HUB_NAME/shared/PROTOCOL.md" ro
  row "$ACTOR" spec        "$HUB_NAME/shared/spec"        ro
  row "$ACTOR" report      "$HUB_NAME/shared/report"      rw
  row "$ACTOR" records     "$HUB_NAME/shared/records"     ro
  deny_block
  suggest_lines
}

say "[5/5] 링크 매니페스트와 동기화"
gen_conf | write_new "$HUB/links.conf"
if ! grep -q '!deny' "$HUB/links.conf"; then
  deny_block >>"$HUB/links.conf"
  say "  [보충] $HUB_NAME/links.conf 에 세션별 도구 차단 줄 추가"
fi

# 업그레이드: 이전 INDEX.md 의 exp_history 목록 행을 새 INDEX.md 로 옮긴다
if [[ -n "$BACKUP" && -f "$BACKUP/$HUB_NAME/shared/records/INDEX.md" ]]; then
  awk 'f && /^\|/ {n++; if (n>2) print} /^## exp_history 목록/ {f=1}' \
    "$BACKUP/$HUB_NAME/shared/records/INDEX.md" >>"$HUB/shared/records/INDEX.md"
fi

"$HUB/harness.sh" sync

say ""
say "=================================================================="
if [[ $UPGRADE -eq 1 ]]; then
  say "업그레이드 완료. 이전 문서는 ${BACKUP#"$ROOT"/}/ 에 있습니다."
  say "  직접 채웠던 내용(OVERVIEW 판정 기준표, $ACTOR/CLAUDE.md 실행 정보 등)만 새 파일로 옮겨 오세요."
  say "  열려 있는 세션은 다시 열어야 새 지침이 적용됩니다."
else
  say "설치 완료. 다음 순서로 진행하세요."
  say ""
  say "  1) $HUB_NAME/links.conf 에서 Actor 에 연결할 기존 폴더 줄의 # 을 지우고:  ./$HUB_NAME/harness.sh sync"
  say "  2) 세션 열기 (터미널 2개):  ./$HUB_NAME/harness.sh open $ORCH  /  ./$HUB_NAME/harness.sh open $ACTOR"
  say "  3) 첫 실행 때 '폴더 신뢰'와 '외부 import 허용' 확인이 한 번씩 뜹니다 → 허용"
  say "  4) 세션 안에서 /context 로 루트 CLAUDE.md 가 빠졌는지, /permissions 로 차단 규칙이 들어갔는지 확인"
  say "  5) $HUB_NAME/shared/OVERVIEW.md 판정 기준표와 $ACTOR/CLAUDE.md 실행 정보를 채우세요"
  say "  운영 안내: $HUB_NAME/README.md"
fi
say "=================================================================="
