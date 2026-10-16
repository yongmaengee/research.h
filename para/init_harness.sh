#!/usr/bin/env bash
# ==================================================================
# Research Harness 설치 스크립트 (기존 작업 폴더용)
#
#   사용법: 기존 작업 폴더에 이 파일을 두고        ./setup_harness.sh
#          다른 위치에서 대상 폴더를 지정하려면    ./setup_harness.sh /path/to/작업폴더
#
#   작업 폴더 바로 아래에 3개를 만든다:
#     orchestrator/  Orchestrator 세션을 여는 폴더 (역할 지침 + 링크만 있음)
#     actor/         Actor 세션을 여는 폴더 (역할 지침 + 링크만 있음)
#     hub/           링크 관리(links.conf, harness.sh) + 공유 문서 원본(shared/)
#
#   기존 파일은 건드리지 않는다. 다시 실행해도 안전하다:
#     - 문서·links.conf·CLAUDE.md 는 이미 있으면 그대로 둔다
#     - 도구(hub/harness.sh, hub/harness.py)만 최신 내용으로 갱신한다
#   폴더 이름 변경: HARNESS_ORCH=orch HARNESS_ACTOR=act HARNESS_HUB=_hub ./setup_harness.sh
# ==================================================================
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(cd "${1:-$(dirname "$SELF")}" && pwd -P)"
ORCH="${HARNESS_ORCH:-orchestrator}"
ACTOR="${HARNESS_ACTOR:-actor}"
HUB_NAME="${HARNESS_HUB:-hub}"
HUB="$ROOT/$HUB_NAME"
MARK=".harness_session"

say()  { printf '%s\n' "$*"; }
fail() { printf '[중단] %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------
# 0. 사전 점검 — 엉뚱한 곳에 설치하거나 기존 폴더를 덮어쓰지 않도록
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

say "=================================================================="
say "Research Harness 설치: $ROOT"
say "  세션 폴더: $ORCH/, $ACTOR/    링크 관리: $HUB_NAME/"
say "=================================================================="

# 이전 버전 스크립트(.orchestrator/.actor 를 루트에 만들던 방식)의 흔적이 있으면 알리기만 한다
legacy=""
for p in .orchestrator .actor OVERVIEW.md PROTOCOL.md work/current_spec.md work/latest_report.md records/painpoints.md scripts/link_assets.sh; do
  [[ -e "$ROOT/$p" ]] && legacy="$legacy $p"
done
if [[ -n "$legacy" ]]; then
  say "[알림] 이전 버전 하네스 흔적:$legacy"
  say "       자동으로 옮기지 않습니다. 내용을 이어 쓰려면 설치 후 $HUB_NAME/shared/ 아래 같은 이름 파일에 직접 옮기세요."
fi

# ------------------------------------------------------------------
# 파일 쓰기 도우미
#   write_new  : 없을 때만 생성 (문서·설정 — 사람이 고치는 파일)
#   write_tool : 항상 최신으로 덮어씀 (도구 — 사람이 고치지 않는 파일)
#   본문 안의 __HUB__ / __ORCH__ / __ACTOR__ 는 실제 폴더 이름으로 치환된다
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

mkdir -p "$HUB/shared/spec" "$HUB/shared/report" "$HUB/shared/records/exp_history" "$ROOT/$ORCH" "$ROOT/$ACTOR"
for d in "$ORCH" "$ACTOR"; do
  [[ -e "$ROOT/$d/$MARK" ]] || printf '이 폴더는 Research Harness 세션 폴더다. 링크 구성은 ../%s/links.conf 에서 관리한다.\n' "$HUB_NAME" >"$ROOT/$d/$MARK"
done
say "[1/5] 폴더 준비 완료"

# ------------------------------------------------------------------
# 2. 공유 문서 원본 ($HUB_NAME/shared) — 두 세션은 링크로만 본다
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

## 3. 핵심 시나리오와 KPI (연구자 작성)
"눈에 띄는 도약"을 판정하는 기준표다. 비어 있으면 Orchestrator는 스펙을 쓰기 전에 연구자에게 이 칸부터 묻는다.

| 항목 | 값 |
|---|---|
| 단일 핵심 시나리오 | (예: 특정 태스크 + 실패 스냅샷 묶음 이름) |
| 시나리오·스냅샷 경로 | (Actor 세션 안 이름 기준. `__HUB__/links.conf`에 연결된 이름) |
| KPI 정의 | (예: 성공률 = 성공 에피소드 수 / 평가 에피소드 수) |
| KPI 측정 조건 | (평가 에피소드 수, 최대 스텝, 성공 판정 기준, 시드 값) |
| 현재 baseline 수치 | (수치 + 그 수치를 낸 커밋·실행 명령) |
| Signal 판정선 | (예: baseline 대비 성공률 +15%p 이상) |

- 단일 실험 수치를 믿으려면 판정선이 "같은 baseline을 같은 조건으로 한 번 더 돌렸을 때 흔들리는 폭"보다 커야 한다. 그 폭을 이미 알고 있으면 판정선 옆에 적어 둔다.

## 4. 실험 간 고정 조건 (바꾸면 비교 무효)
- 평가 에피소드 수, 최대 스텝 수, 성공 판정 기준
- 초기 상태·스냅샷 묶음, 시뮬레이터·환경 버전
- (연구자 추가)
- 위 조건이 바뀐 결과는 메커니즘 효과가 아니라 측정 변경으로 본다. 바꿔야 하면 연구자가 이 문서에서 먼저 바꾸고 baseline을 다시 잰다.

## 5. 단계 전환 기록
| 날짜 | 전환 | 근거 (records/exp_history 문서) |
|---|---|---|
| | PHASE 1 시작 | |
__MD__

write_new "$HUB/shared/PROTOCOL.md" <<'__MD__'
# Orchestrator - Actor Interaction Protocol

본 워크스페이스는 연구자(User)의 직접 통제하에 운영되며, 두 에이전트 세션(Orchestrator, Actor)은 컨텍스트 오염을 막기 위해 서로 다른 층위의 파일만 다룬다.

- **분업 이유:** 한 세션이 구현과 평가를 같이 하면 검증이 자기 결론을 정당화하는 쪽으로 쏠리고, 정작 우회는 막지 못했다 (painpoints 6번). 그래서 만드는 쪽(Actor)과 판정하는 쪽(Orchestrator)을 나눈다.

## 0. 폴더 구조 (기존 작업 폴더 안)
```text
<작업 폴더>/
├── (기존 코드·데이터 — 그대로 둠)
├── __HUB__/                       링크 관리 + 공유 문서 원본
│   ├── links.conf                 세션별로 무엇을 연결할지 정하는 유일한 기준
│   ├── harness.sh                 sync / check / find / open
│   └── shared/                    두 세션이 링크로 보는 실제 파일
│       ├── OVERVIEW.md, PROTOCOL.md
│       ├── spec/current_spec.md        Orchestrator 작성
│       ├── report/latest_report.md     Actor 작성
│       └── records/                    Orchestrator 정리
├── __ORCH__/                      Orchestrator 세션을 여는 곳
│   ├── CLAUDE.md, LINKS.md(자동), .claude/settings.json(자동)
│   └── OVERVIEW.md PROTOCOL.md spec/ report/ records/      ← 전부 링크
└── __ACTOR__/                     Actor 세션을 여는 곳
    ├── CLAUDE.md, LINKS.md(자동), .claude/settings.json(자동)
    └── OVERVIEW.md PROTOCOL.md spec/ report/ records/ + 기존 코드 링크
```

## 1. 컨텍스트 위생 및 온디맨드(On-Demand) 열람 규칙
- **상시 열람:** 두 세션 모두 시작 시 자기 `CLAUDE.md`와, 그것이 불러오는 `OVERVIEW.md`·`PROTOCOL.md`·`LINKS.md`만 컨텍스트에 들어간다. 작업 폴더 루트의 기존 `CLAUDE.md`와 auto memory는 세션 설정(`.claude/settings.json`)으로 꺼져 있다.
- **필요시 열람 (`records/`):** 과거 기록이 담긴 `records/` 폴더는 평소에 전부 읽지 않는다. 새로운 계획을 세우거나 반복되는 문제에 막혔을 때만 `records/INDEX.md`를 확인하고 필요한 문서(`painpoints.md` 등)만 발췌하여 읽는다.
- **단계마다 다시 읽기:** Actor는 작업을 받을 때마다 `spec/current_spec.md`를, Orchestrator는 판정할 때마다 `report/latest_report.md`를 새로 읽는다. 세션 도중 상대가 파일을 바꿨을 수 있다.

## 2. 역할 및 권한 경계
| 구분 | Orchestrator (기획·가시화·본질 감시) | Actor (과감한 구현·단일 실험·팩트 보고) |
| :--- | :--- | :--- |
| **주 작업 공간** | `spec/current_spec.md`, `records/*` | 연결된 코드 폴더, `report/latest_report.md` |
| **코드 접근** | **원칙적 블라인드** — 세션 폴더에 코드가 연결돼 있지 않다 (구조 정리/명시적 지시 시에만 연구자가 준 경로로 열람, 직접 수정 금지) | **전권 보유** (초안 작성, 구현, 서브에이전트 실험) |
| **쓰기 가능 경로 (설정으로 강제)** | `spec/`, `records/` | `report/`, links.conf에서 `rw`로 연결한 코드 폴더 |
| **검증 및 평가** | KPI와 메커니즘 설명만 보고 **'우회(꼼수) 여부'와 '선행연구 중복'** 심사 | **자기 합리화(Self-eval) 금지**, 단일 시나리오 결과 수치만 건조하게 덤프 |

- 권한은 지침 문장이 아니라 설정으로 막는다. `__HUB__/links.conf`의 `ro`/`rw`가 각 세션의 `.claude/settings.json`으로 변환되어 `ro` 경로는 파일 도구로 수정할 수 없다.

## 3. 수동 핸드오프(Handoff) 워크플로우
1. **[연구자 -> Orchestrator]:** 아이디어 제시 및 스펙 작성 지시
   - Orchestrator는 선행연구 중복 체크 및 우회 금지 조건을 담아 `spec/current_spec.md` 작성. 새 스펙마다 **스펙 ID**(`YYYYMMDD-NN`)를 올린다.
2. **[연구자 -> Actor]:** 구현 및 빠른 시그널 검증 지시
   - Actor는 `spec/current_spec.md`를 읽고 연결된 코드 폴더에 과감하게 구현 후, 다중 시드 없이 핵심 스냅샷에서 빠르게 시그널만 확인하여 `report/latest_report.md`에 수치와 메커니즘 요약만 기록. 보고서 첫 줄에 **대상 스펙 ID**를 그대로 적는다.
3. **[연구자 -> Orchestrator]:** 결과 정리 및 본질 부합 검토 지시
   - Orchestrator는 `report/latest_report.md`를 읽고 꼼수 해결 여부를 판별한 뒤, 가시성 있게 문서를 재작성하고 중요 이력을 `records/exp_history/`에 아카이빙.
   - 보고서의 대상 스펙 ID가 현재 스펙 ID와 다르면 판정하지 않고 연구자에게 알린다.

## 4. 판정 결과 (Orchestrator는 하나만 고른다)
| 판정 | 조건 | 다음 행동 |
| :--- | :--- | :--- |
| 우회(폐기) | 실패 상황을 감지해 정해진 동작으로 덮음 / 평가 조건 변경 / 신고된 하드코딩 값이 효과의 주원인 | 폐기 기록, painpoints 대조 |
| Signal 없음 | 우회는 아니나 OVERVIEW §3 판정선 미달 | 가설 수정 또는 다음 아이디어 |
| Signal 있음 | 우회 아님 + 판정선 이상 | 연구자에게 보고. PHASE 2 진입은 연구자만 결정 |
| 판정 불가 | 스펙 ID 불일치 / baseline과 다른 조건 있음 / 재현 정보 누락 | Actor에게 누락 항목만 요청 |

## 5. 기록 규칙
- 판정이 끝난 라운드는 Orchestrator가 `records/exp_history/YYYYMMDD-NN_<짧은이름>.md`로 남기고(`_TEMPLATE.md` 사용), `records/INDEX.md` 목록 표에 한 줄 추가한다.
- 새로 반복되는 실패 패턴은 `records/painpoints.md` 맨 아래 "후보"에 적는다. 본문 번호로 올리는 것은 연구자가 한다.
- 중복 체크에서 확인한 가까운 연구는 `records/related_work.md`에 한 줄씩 누적한다.

## 6. 링크 관리 (연구자용)
- 세션에 폴더를 보이게 하기: `__HUB__/links.conf`에 한 줄 추가 → `./__HUB__/harness.sh sync`
- 현황 보기: `./__HUB__/harness.sh check`
- 체크포인트·스냅샷 폴더 찾기: `./__HUB__/harness.sh find [키워드]` (링크는 만들지 않고 links.conf에 붙일 줄만 출력)
- 세션 열기: `./__HUB__/harness.sh open __ORCH__`, `./__HUB__/harness.sh open __ACTOR__` (또는 `cd __ACTOR__ && claude`)
__MD__

write_new "$HUB/shared/records/INDEX.md" <<'__MD__'
# On-Demand Records Index (기록 목차)

평소에는 이 파일의 목록만 참조하고, 작업 중 아래 상황에 해당할 때만 실제 문서를 열어 컨텍스트에 로드하라.

1. **`records/painpoints.md`**
   - **열람 시점:** 새로운 실험 스펙을 설계할 때(Orchestrator), 혹은 구현 방향이 보수적인 휴리스틱으로 흐르거나 과잉 검증을 하려 할 때(Actor).
   - **내용:** 지난 3개월간의 핵심 시행착오 7가지와 절대 금기 패턴(Anti-Patterns). 가장 치명적인 것은 5번(우회 해결), 판단 기준은 7번(본질).
2. **`records/related_work.md`**
   - **열람 시점:** 스펙을 쓰기 전 선행연구 중복을 확인할 때(Orchestrator), 구현하려는 방법이 기존 것과 같아 보일 때(Actor).
   - **내용:** 지금까지 확인한 가까운 연구, 우리와 겹치는 지점, 가져올 영감, 확인 날짜.
3. **`records/exp_history/`**
   - **열람 시점:** 이전에 시도했던 아키텍처나 실패했던 파라미터 조합을 다시 확인해야 할 때.
   - **파일 규칙:** `YYYYMMDD-NN_<짧은이름>.md` (번호는 스펙 ID와 동일). 양식은 `_TEMPLATE.md`.
   - **찾는 법:** 폴더 전체를 읽지 않는다. 아래 표에서 고르거나 `records/exp_history`를 검색 경로로 지정해 키워드로 찾는다.

## exp_history 목록 (Orchestrator가 아카이빙할 때마다 한 줄 추가)
| 스펙 ID | 한 줄 요약 | 판정 | 파일 |
|---|---|---|---|
__MD__

write_new "$HUB/shared/records/painpoints.md" <<'__MD__'
# 3-Month Painpoints & Anti-Patterns (절대 금기 사항)

이 문서는 지난 3개월간 연구 생산성을 갉아먹은 최악의 패턴 7가지다. 아래 패턴이 감지되면 즉시 작업을 중단하고 교정하라.
- 가장 치명적인 것: **5번** (우회 해결)
- 판단이 흔들릴 때의 기준: **7번** (본질)

## 1. 선행연구가 너무 많고 계속 올라옴 — 중복 검증은 어렵지만 영감의 원천
- **현상:** 참고해야 하는 선행연구가 너무 많고 최근 학회 논문도 계속 올라와서, 방법이 겹치는지 전부 검증하기 어렵다. 반면 비슷한 문제인식을 가진 연구에서 돌파 영감을 금방 얻을 수 있다는 장점이 있다.
- **처방:**
  - 전수 조사하지 않는다. 가장 가까운 연구 1~3개와의 차이만 확인한다.
  - 확인 결과는 `records/related_work.md`에 누적한다. 다음 스펙부터는 그 목록 대조 + 최근 검색만 하면 되도록, 중복 여부를 "미리 알고 있는" 상태를 만든다.
  - 모델 기억만으로 "중복 없음"이라고 쓰지 않는다. 검색한 날짜와 검색어를 남기고, 검색하지 않았으면 "미확인"으로 적는다.
  - 영감은 적극 가져와 비튼다. 같은 형태로 이미 발표된 것만 버린다.
- **예시:**
  - 나쁨: "제가 아는 범위에서 유사 연구는 없습니다." (검색 없음, 날짜 없음)
  - 좋음: "2026-10-14 검색 (검색어: failure recovery manipulation RL / reset distribution curriculum). 가장 가까운 것: <논문 A> — 실패 상태에서 재시작만 하고 학습 신호는 그대로. 차이: 우리는 실패 유형별로 학습 신호 구조를 바꿈. related_work.md 2행 추가."

## 2. 새로운 시도가 본질인데 보수적으로 시도함
- **현상:** 없는 것을 만들고, 새로운 시도와 기존에 없는 해석을 만드는 것이 본질적인 작업인데 매우 보수적으로 시도한다. 검증되지 않은 시도에는 휴리스틱을 덧대고, 과감하거나 야심 찬 작업은 반려하거나 편향을 가지고 축소한다.
- **처방:**
  - **야심 찬 시도 우선:** 검증되지 않았다는 이유로 과감한 아이디어를 반려하거나 휴리스틱으로 깎아내리지 마라.
  - 안전한 소폭 상승은 OVERVIEW §1의 비본질이다. 실패해도 해석이 남는 시도를 고른다.
- **예시:**
  - 나쁨: 학습률 스케줄·네트워크 폭만 바꾸는 안전한 변형을 연속으로 제안.
  - 나쁨: 연구자가 낸 과감한 구조 변경을 "불안정할 수 있음"이라며 if 분기 안전장치를 붙인 축소판으로 구현.
  - 좋음: 아이디어를 가장 순수한 형태로 구현하고, 안 되면 왜 안 됐는지 관찰된 현상을 보고한다.

## 3. 잘못된 핀트의 과잉 검증 (학회 논문에 저널급 엄밀성 들이대기)
- **현상:** 간단한 직관으로도 알 수 있는 방법에 대해 시드별 검증과 취약점 파악을 과하게 한다. 대부분의 학회 논문은 limitation을 아주 작게 쓰거나 생략하고, 모든 검증을 다 해 놓고 선보이지 않는다. AI 분야는 학회 투고 위주인데 작은 실험마다 저널급 엄밀함을 따지는 것이 병목의 주원인이다.
- **처방:**
  - 방법을 찾는 단계에서는 성능 향상 외의 검증을 하지 않는다. 다중 시드, Ablation, 엣지케이스, limitation 정리는 눈에 띄고 주장할 만한 결과(OVERVIEW §3 판정선)가 나온 뒤에 연구자 지시로 한다. 그 전에는 **절대 제안하거나 실행하지 마라.**
  - **예외 — 선행연구와의 기여 중복은 별개 문제다.** 이것은 탐색 단계에서도 빠르게 확인하거나 미리 알고 있어야 한다 (1번).
- **예시:**
  - 나쁨: 성공률이 2%p 오른 첫 결과에 시드 5개와 ablation 3종을 바로 붙임.
  - 좋음: 대표 스냅샷 묶음 하나에서 OVERVIEW §3 판정선을 넘는지만 본다. 넘으면 연구자에게 보고하고, 검증 범위는 연구자가 정한다.

## 4. 컨텍스트 오염 및 번역투 외계어 출력
- **현상:** 문서 관리와 코드 작성·정리를 한 세션에서 한꺼번에 하다 보면 연구자의 지시나 생각보다 LLM 출력이 컨텍스트를 더 많이 차지하고, 사람이 알아들을 수 없는 텍스트가 된다. 특히 영어 유머를 한국어로 억지로 바꿔 말이 안 되는 문장이 자주 나온다.
- **처방:**
  - 모든 보고와 문서는 **건조하고 명료한 한국어 개조식**으로 작성한다. 불필요한 수식어, 영어 유머 직역, 장황한 서론을 엄격히 금지한다.
  - 분업한다. Orchestrator는 코드를 필요할 때만 보고, 평소에는 Actor의 KPI와 메커니즘 설명만 읽고 정리하거나 답변한다.
- **예시:**
  - 나쁨: "이번 실험은 그야말로 게임 체인저라 할 수 있으며, 로봇이 마치 새로운 눈을 뜬 것과 같습니다."
  - 좋음: "성공률 0.38 → 0.52 (seed 0, 평가 50회). 낙하 후 재파지 시도 1.2 → 3.4회/에피소드."

## 5. 우회 해결(Workaround) 후 국소적 기여로 포장하기 [가장 치명적]
- **현상:** 근본 원인을 해결하지 않고 조건문 분기, 예외 처리, 환경 제약 우회 등 얄팍한 휴리스틱으로 에러만 가린 뒤 "해결했다"고 자연스럽게 주장함. 시작부터 잘못된 문제를 잘못 넘어가면, 그 치명적인 출발 상태가 이후 실험과 해석 전체에 계속 전이된다.
- **처방:**
  - 문제를 피해 가는 땜질 코드는 수치가 올라도 **전부 실패로 간주**한다. 실패하더라도 정면으로 부딪히는 구조적·본질적 메커니즘 변경만 인정한다.
  - 출발점이 잘못됐다고 의심되면 다음 실험으로 넘어가지 말고 그 지점부터 다시 본다.
- **예시:**
  - 나쁨: 물체를 놓친 에피소드에서 `if 그리퍼-물체 거리 > 임계값: 재파지 스크립트 실행`을 넣고 "복구 메커니즘 구현, 성공률 +30%p"로 보고.
  - 나쁨: 성공 판정 반경을 넓히거나 평가 최대 스텝을 늘려 수치를 올림 (측정을 바꾼 것이지 메커니즘이 아님).
  - 좋음: 놓침이 왜 생기는지(관측에 없는 정보인지, 보상이 그 구간을 학습시키지 못하는지)를 먼저 특정하고, 그 원인에 해당하는 학습 신호·표현·구조를 바꾼다. 수치가 덜 올라도 이쪽을 기록한다.

## 6. 우회한 결론을 자기평가로 정당화하기 — 하네스가 없을 때보다 나빠짐
- **현상:** 5번처럼 사용자에게 유리하게 우회해서 결론을 낸 뒤, 그 결론을 자기평가하려고 검증을 강하게 건다. 그런데 검증의 핀트가 틀려서(시드·견고성·엣지케이스) 정작 우회 자체는 막지 못한다. 결과적으로 아무 하네스가 없는 상태보다 생산성이 떨어진다.
- **처방:**
  - 만든 쪽이 평가하지 않는다. 구현은 Actor, 판정은 Orchestrator로 나눈 이유다.
  - 검증의 첫 질문은 "견고한가"가 아니라 "우회인가"다. Actor는 추가한 분기·하드코딩 값을 변호 없이 목록으로 신고만 하고, Orchestrator는 그 목록부터 본다.
- **예시:**
  - 나쁨: 재파지 if 분기로 성공률을 올린 뒤 "견고성 확인"으로 시드 5개를 돌려 분산이 작다며 결론을 강화.
  - 좋음: Actor는 보고서에 "추가한 분기: 재파지 트리거 1개"만 적고 끝낸다. 그 분기가 효과의 주원인인지는 Orchestrator가 판정한다.

## 7. 본질을 잊고 주객전도
- **현상:** 본질적인 목표와 해결할 문제를 잊고, 주변 작업(검증, 정리, 인프라 수정, 지엽적 최적화)이 주가 된다.
- **처방:**
  - OVERVIEW §1이 모든 판단의 저울이다. 무언가를 추가로 하기 전에 "이게 핵심 시나리오의 Signal을 앞당기나?"를 묻고, 아니면 하지 않거나 연구자에게 묻는다.
  - 본질을 잡고 있으면 과잉 검증(3번)인지 아닌지도 이 질문 하나로 저울질된다.
- **예시:**
  - 나쁨: 성공률이 안 오르자 평가 스크립트 리팩토링과 로깅 대시보드 구축에 라운드 전체를 씀.
  - 나쁨: KPI와 무관한 시뮬레이터 경고를 없애려고 환경 코드를 고침.
  - 좋음: 경고가 KPI 측정에 영향이 없으면 보고서 팩트에 한 줄 남기고 스펙의 메커니즘으로 돌아간다.

## 후보 (Orchestrator가 적고, 연구자가 위 번호로 올린다)
- (비어 있음)
__MD__

write_new "$HUB/shared/records/related_work.md" <<'__MD__'
# Related Work Ledger (선행연구 대조 목록)

전수 조사 목록이 아니다. 지금까지 확인한 "가까운 연구"만 누적해서, 다음 중복 체크가 이 목록 대조 + 최근 검색으로 끝나게 한다.
- Orchestrator가 중복 체크를 할 때마다 한 줄씩 추가한다.
- 표에 없는 최신 논문은 검색으로 보충하고, 확인 날짜를 남긴다.
- 연구자가 따로 모은 논문 목록(주간 브리핑 등)에서 겹칠 만한 것만 옮겨 와도 된다.

| 확인 날짜 | 논문 (학회·연도) | 문제 인식 | 핵심 방법 한 줄 | 우리와 겹치는 지점 | 가져올 영감 |
|---|---|---|---|---|---|
__MD__

write_new "$HUB/shared/records/exp_history/_TEMPLATE.md" <<'__MD__'
# <스펙 ID> <짧은 이름>
- **날짜:**
- **가설:**
- **메커니즘 (우회 여부):**
- **KPI:** baseline → 결과 (측정 조건)
- **판정:** 우회(폐기) / Signal 없음 / Signal 있음 / 판정 불가
- **판정 근거:**
- **다음 행동:**
- **재현 정보:** 커밋, 실행 명령, 시드, 스냅샷 (보고서에서 옮김)
__MD__

write_new "$HUB/shared/spec/current_spec.md" <<'__MD__'
# Current Task Spec (Orchestrator 작성란)
- **스펙 ID:** (YYYYMMDD-NN — 스펙을 새로 쓸 때마다 올린다)
- **목표 가설:** (작성 대기 중)
- **본질 연결:** (OVERVIEW §1 핵심 문제의 어느 부분을 직접 공략하는지 한 줄)
- **선행연구 중복 체크:** (검색 날짜·검색어 / 가장 가까운 연구 1~3개와의 차이 한 줄 / 영감을 가져온 지점. 결과는 records/related_work.md에도 추가. 검색하지 않았으면 "미확인")
- **구현 방향 (우회 금지 조건):**
- **구체 금지 목록:** (예: 그리퍼·물체 상태를 보고 행동을 바꾸는 if 분기 추가 금지, 평가 조건 변경 금지)
- **확인할 단일 KPI:**
- **비교 기준:** (baseline 수치와 조건 — OVERVIEW §3과 같아야 함)
- **Signal 판정선:** (OVERVIEW §3 값, 또는 이번 스펙에 한해 연구자가 정한 값)
- **실행 조건:** (시나리오·스냅샷 묶음, 시드 1개, 학습/평가 스텝)
__MD__

write_new "$HUB/shared/report/latest_report.md" <<'__MD__'
# Latest Execution Report (Actor 작성란)
- **대상 스펙 ID:** (spec/current_spec.md의 스펙 ID를 그대로)
- **구현 메커니즘 요약:** (작성 대기 중)
- **추가한 분기·하드코딩 값 전체 목록:** (없으면 "없음". 변호 없이 목록만)
- **핵심 KPI 변화:**
- **관찰된 팩트:**
- **재현 정보:** (커밋 해시 또는 diff 요약, 실행 명령, 시드, 스냅샷 경로, 스텝 수)
- **baseline과 다른 조건:** (메커니즘 외에 바뀐 것. 없으면 "없음")
__MD__

# ------------------------------------------------------------------
# 3. 세션 폴더의 역할 지침 (CLAUDE.md) — 세션 폴더 안의 유일한 "실제" 문서
# ------------------------------------------------------------------
say "[3/5] 세션 지침 ($ORCH/CLAUDE.md, $ACTOR/CLAUDE.md)"

write_new "$ROOT/$ORCH/CLAUDE.md" <<'__MD__'
# Role: Research Orchestrator (기획·가시화·본질 감시자)

너는 연구자의 사고를 돕는 아키텍트다. 아래 세 문서는 세션 시작 시 자동으로 불러온다. 필요시 `records/painpoints.md`를 참조하라.

@OVERVIEW.md
@PROTOCOL.md
@LINKS.md

## 1. 언어 및 컨텍스트 위생 규칙 (필수)
- **건조하고 명확한 한국어 사용:** 영어 유머/관용구 직역, 번역투, 과장된 수식어를 절대 쓰지 마라. 사람이 한눈에 읽을 수 있는 가시성 높은 한국어 개조식과 표(Table)만 사용하라.
- **코드 블라인드 원칙:** 컨텍스트 오염을 막기 위해 이 세션 폴더에는 코드 디렉토리를 연결하지 않는다. 코드는 원칙적으로 읽지 않고 직접 수정하지도 않는다. 오직 Actor가 보고한 **KPI 수치, 핵심 수식/메커니즘 요약**만 읽고 판단한다. (단, 연구자가 디렉토리 정리나 특정 파일 확인을 지시할 때만 연구자가 준 경로로 예외적으로 접근)

## 2. 핵심 임무
1. **과감한 기획 및 선행연구 체크 (`spec/current_spec.md` 작성):**
   - 최신 학회 논문들과 기여가 겹치는지 빠르게 검증하되, 인접 연구의 돌파구에서 영감을 얻어 **보수적이지 않은 야심 찬 실험 스펙**을 작성하라.
   - 중복 체크는 `records/related_work.md` 대조 + 최근 검색으로 한다. 모델 기억만으로 "중복 없음"이라고 쓰지 않는다 (검색 날짜·검색어를 남기고, 안 했으면 "미확인").
   - OVERVIEW §3 표가 비어 있으면 스펙을 쓰기 전에 연구자에게 그 칸부터 묻는다.
2. **우회 해결(Workaround) 심문:**
   - Actor가 `report/latest_report.md`에 올린 결과를 볼 때, 본질적인 문제를 정면 돌파했는지 아니면 얄팍한 휴리스틱으로 우회했는지 가장 먼저 심사하라. 우회 해결이면 즉시 폐기를 건의하라.
3. **과잉 검증 차단:**
   - 확실한 성능 도약(Signal)이 확인되기 전에는 절대 다중 시드 실험이나 한계점 검증을 지시하지 마라.
4. **가시성 정리:**
   - 흩어진 실험 결과와 문서 구조를 언제나 사람이 보기 편하게 재작성하고 정돈하라.
5. **본질 감시:**
   - 스펙과 보고서가 OVERVIEW §1에서 벗어났는지 판정보다 먼저 본다. 라운드의 대부분이 주변 작업(리팩토링, 인프라, 추가 검증)이었다면 그 사실부터 적는다.

## 3. 판정 순서 (보고서를 받을 때마다 이 순서대로)
1. 보고서의 대상 스펙 ID = 현재 스펙 ID 인가 → 아니면 멈추고 연구자에게 알림
2. "baseline과 다른 조건"이 "없음"인가 → 아니면 판정 불가
3. "추가한 분기·하드코딩 값"이 효과의 주원인으로 보이는가 → 그렇다면 우회
4. KPI 변화가 OVERVIEW §3 판정선을 넘는가 → Signal 있음 / 없음
5. PROTOCOL §4 판정 하나로 결론을 적고 `records/exp_history/`에 남긴다

## 4. 우회 판별 예시
| Actor 보고 | 판정 | 이유 |
| :--- | :--- | :--- |
| 그리퍼-물체 거리가 임계값을 넘으면 재파지 스크립트 실행 → 성공률 0.38→0.71 | 우회 | 실패를 감지해 정해진 동작으로 덮음. 정책이 복구를 익힌 것이 아님 |
| 평가 최대 스텝 150→500 → 성공률 상승 | 우회 (측정 변경) | OVERVIEW §4 고정 조건 위반 |
| 낙하 이후 구간의 보상 구조를 바꿈. 낙하 판정에 하드코딩 높이 임계값 1개 신고 | 판정 진행 | 본체는 학습 신호 구조 변경. 임계값이 효과의 주원인인지만 확인 |
| 실패 스냅샷을 학습 초기 상태 분포에 섞음 | 판정 진행 + 중복 확인 | 메커니즘 변경이지만 reverse curriculum 계열(Florensa et al., 2017)과의 차이가 스펙에 적혀 있는지 확인 |

## 5. 스펙의 우회 금지 조건 작성 예시
- 나쁨: "휴리스틱 없이 구현할 것."
- 좋음: "그리퍼·물체 상태를 보고 행동을 바꾸는 if 분기 추가 금지. 평가 스텝·성공 판정·스냅샷 묶음 변경 금지. 새 하이퍼파라미터는 값과 근거를 보고서에 적을 것."

## 6. 파일 규칙
- 쓰기 가능: `spec/`, `records/`. 쓸 때는 LINKS.md의 실제 경로를 쓴다 (링크 경로로 Write/Edit하면 거부된다).
- `OVERVIEW.md`, `PROTOCOL.md`, `report/`는 읽기 전용이다. 바꿀 점은 연구자에게 제안만 한다.
__MD__

write_new "$ROOT/$ACTOR/CLAUDE.md" <<'__MD__'
# Role: Execution Actor (과감한 구현 및 빠른 시그널 탐색기)

너는 `OVERVIEW.md`의 본질을 달성하기 위해 코드를 구현하고 시뮬레이션을 돌리는 실행기다. 아래 세 문서는 세션 시작 시 자동으로 불러온다. 작업을 받을 때마다 `spec/current_spec.md`를 새로 읽어라 (세션 도중 바뀌었을 수 있다).

@OVERVIEW.md
@PROTOCOL.md
@LINKS.md

## 1. 구현 및 실험 원칙 (필수)
- **보수적 휴리스틱 절대 금지:** 새로운 시도나 해석을 코드로 옮길 때, 안전하게 가겠다고 조건문 분기(`if-else`), 하드코딩된 임계값, 예외 처리 땜질로 우회하지 마라. 요구된 메커니즘을 가장 순수하고 과감한 형태로 구현하라.
- **빠른 시그널 확인 (No Over-validation):** 연구자가 명시적으로 지시하지 않는 한, 여러 시드(Seed)를 돌리거나 엣지케이스 취약점을 검증하는 데 시간을 쓰지 마라. 서브에이전트를 활용해 대표 스냅샷/시나리오에서 **성능이 확실히 뛰는가(Signal)**만 가장 빠르게 확인하라.
- **자기 합리화(Self-justification) 금지:** 결과를 보고할 때 너의 코드를 변호하거나 국소적인 꼼수 개선을 큰 기여인 것처럼 포장하지 마라.
- **본질 저울질:** 스펙의 메커니즘 외 작업(리팩토링, 인프라 수정, 추가 검증)을 하기 전에 "이게 핵심 시나리오의 Signal을 앞당기나?"를 묻고, 아니면 하지 않는다. 막히면 우회하지 말고 막힌 사실을 그대로 보고한다.
- **비교 조건 고정:** baseline과 달라지는 것은 스펙의 메커니즘 하나뿐이어야 한다. 평가 에피소드 수·최대 스텝·성공 판정·스냅샷 묶음(OVERVIEW §4)을 바꾸지 마라. 바꾸지 않으면 실행이 안 되면 멈추고 보고서에 그 사실만 적어라.

## 2. 결과 보고 규칙 (`report/latest_report.md`)
- 영어식 유머나 장황한 설명 없이 **건조하고 명확한 한국어**로 작성하라.
- 원본 코드나 긴 에러 로그를 복붙하지 말고, **(1) 구현한 핵심 메커니즘 (우회 여부 명시), (2) 단일 실험 핵심 KPI 전/후 비교, (3) 관찰된 물리적/수치적 현상 팩트**만 간결하게 기록하라.
- 추가로 **(4) 대상 스펙 ID, (5) 추가한 if 분기·하드코딩 값 전체 목록, (6) 재현 정보(커밋 해시 또는 diff 요약, 실행 명령, 시드, 스냅샷 경로)**를 적어라. (5)는 변호 없이 목록만 쓴다. 숨기는 것은 우회보다 나쁘다.

## 3. 보고서 예시
나쁜 보고:
> 새로운 복구 메커니즘을 성공적으로 구현했습니다! 성능이 크게 향상되어 이 접근법의 잠재력을 잘 보여줍니다.

좋은 보고:
> - 대상 스펙 ID: 20261014-01
> - 메커니즘: 낙하 이후 구간 보상에 실패 유형별 가중치 적용 (정책 구조 변경 없음)
> - 추가한 분기·하드코딩 값: 낙하 판정 `obj_z < 0.02` 1개
> - KPI: 성공률 0.38 → 0.52 (seed 0, 평가 50회, 스냅샷 묶음 A)
> - 팩트: 낙하 후 재파지 시도 1.2 → 3.4회/에피소드, 재파지 성공률은 변화 없음
> - 재현: commit a1b2c3d, `python train.py --cfg cfg/exp01.yaml --seed 0`
> - baseline과 다른 조건: 없음

## 4. 파일·탐색 규칙
- 쓰기는 LINKS.md의 실제 경로로 한다 (`report/`, `rw`로 연결된 코드 폴더). 링크 경로로 Write/Edit하면 거부된다.
- `spec/`, `records/`, `OVERVIEW.md`, `PROTOCOL.md`는 읽기 전용이다.
- 연결된 코드 폴더를 Glob/Grep으로 찾을 때는 그 링크 폴더를 검색 시작 경로로 직접 지정한다 (상위에서 재귀 검색하면 링크 안을 건너뛴다). Bash에서는 `rg -L`, `find -L`을 쓴다.
- 작업 폴더 루트의 기존 CLAUDE.md는 이 세션에 불러오지 않는다. 실행 방법이 아래 5절에 없으면 연구자에게 묻는다.

## 5. 프로젝트 실행 정보 (연구자 작성 — 루트 CLAUDE.md에서 필요한 것만 옮겨 적기)
- 환경:
- 학습 명령:
- 평가 명령:
- 결과 저장 위치:
__MD__

# ------------------------------------------------------------------
# 4. 링크 관리 도구 ($HUB_NAME/harness.sh, $HUB_NAME/harness.py) — 항상 최신으로 갱신
# ------------------------------------------------------------------
say "[4/5] 링크 관리 도구 ($HUB_NAME/)"

write_tool "$HUB/harness.sh" <<'__HARNESS_SH__'
#!/usr/bin/env bash
# Research Harness 관리 명령 (작업 폴더 어디서 실행해도 됨)
#
#   ./__HUB__/harness.sh sync              links.conf 대로 링크·세션 설정을 맞추고 현황 출력
#   ./__HUB__/harness.sh check             아무것도 바꾸지 않고 현황만 출력
#   ./__HUB__/harness.sh find [키워드…]     체크포인트·스냅샷 폴더 후보를 links.conf 용 줄로 출력
#                                          (--in <경로> 로 다른 워크스페이스도 탐색, 여러 번 가능)
#   ./__HUB__/harness.sh open <세션> [claude 옵션…]   sync 후 그 세션 폴더에서 claude 실행
set -euo pipefail
HUB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(dirname "$HUB")"
cmd="${1:-check}"
if [[ $# -gt 0 ]]; then shift; fi

case "$cmd" in
  sync|check|find)
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
    sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *)
    echo "알 수 없는 명령: $cmd  (sync | check | find | open | help)" >&2; exit 2 ;;
esac
__HARNESS_SH__

write_tool "$HUB/harness.py" <<'__HARNESS_PY__'
#!/usr/bin/env python3
"""Research Harness 링크 관리자 (hub/harness.sh 가 호출).

links.conf 가 유일한 기준이다. sync 는 세션마다 다음을 다시 만든다:
  1) 세션 폴더 안 심볼릭 링크 (작업 폴더 안 대상은 상대 링크 → 폴더째 옮겨도 유지)
  2) .claude/settings.json : 루트 CLAUDE.md 제외, auto memory 끔, ro/rw 권한
  3) LINKS.md              : 세션이 읽는 링크 표 (링크 경로 ↔ 실제 경로)
  4) .gitignore            : 위 생성물과 링크 (links.conf 로 재현 가능하므로)
링크가 아닌 실제 파일·폴더는 절대 지우거나 덮어쓰지 않는다.
"""
import json
import os
import re
import shlex
import sys
import unicodedata
from pathlib import Path

HUB = Path(__file__).resolve().parent
ROOT = HUB.parent
CONF = HUB / "links.conf"
SESSION_MARK = ".harness_session"
MODES = {"ro": "읽기 전용", "rw": "읽기·쓰기"}
RESERVED = {"CLAUDE.md", "CLAUDE.local.md", "LINKS.md", ".claude", ".gitignore", SESSION_MARK}
NAME_RE = re.compile(r"^[^/\x00]+$")
SESSION_RE = re.compile(r"^[A-Za-z0-9_-][A-Za-z0-9._-]*$")
GOOD = ("정상", "생성", "갱신")

CKPT_EXT = {".pt", ".pth", ".ckpt", ".safetensors", ".onnx"}
DATA_EXT = {".pkl", ".pickle", ".hdf5", ".h5", ".npz", ".npy", ".parquet"}
SKIP_DIRS = {".git", "__pycache__", "node_modules", ".venv", "venv", "env",
             ".mypy_cache", ".pytest_cache", ".ipynb_checkpoints", ".idea", ".vscode"}


# ---------------------------------------------------------------- 공통
def within(child, parent):
    child, parent = Path(child), Path(parent)
    return child == parent or parent in child.parents


def rel(p):
    p = Path(p)
    if within(p, ROOT):
        r = os.path.relpath(str(p), str(ROOT))
        return "." if r == "." else r
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
        self.given = Path(os.path.normpath(str(p)))          # links.conf 에 적힌 경로
        self.real = Path(os.path.realpath(str(self.given)))  # 링크를 다 푼 실제 경로 (권한 설정용)

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
    if not CONF.exists():
        print(f"[오류] {rel(CONF)} 가 없습니다. setup_harness.sh 를 먼저 실행하세요.", file=sys.stderr)
        sys.exit(1)
    entries, errors, seen = [], [], set()
    for no, raw in enumerate(CONF.read_text(encoding="utf-8").splitlines(), 1):
        try:
            parts = shlex.split(raw, comments=True)
        except ValueError as ex:
            errors.append(f"{no}행: 따옴표 짝이 맞지 않음 ({ex})")
            continue
        if not parts:
            continue
        if len(parts) not in (3, 4):
            errors.append(f"{no}행: '세션 이름 경로 [ro|rw]' 형식이 아님 → {raw.strip()}")
            continue
        session, name, target = parts[:3]
        mode = parts[3] if len(parts) == 4 else "ro"
        if mode not in MODES:
            errors.append(f"{no}행: 권한은 ro 또는 rw 만 가능 → {mode}")
            continue
        if not SESSION_RE.match(session) or session == HUB.name:
            errors.append(f"{no}행: 세션 이름으로 쓸 수 없음 → {session}")
            continue
        if not NAME_RE.match(name) or name.startswith(".") or name in RESERVED:
            errors.append(f"{no}행: 세션 안 이름으로 쓸 수 없음 (슬래시·점 시작·예약어 불가) → {name}")
            continue
        if (session, name) in seen:
            errors.append(f"{no}행: {session}/{name} 가 두 번 나옴")
            continue
        seen.add((session, name))
        entries.append(Entry(no, session, name, target, mode))

    sessions = collect_sessions(entries)
    sdirs = [ROOT / s for s in sessions]
    kept = []
    for e in entries:
        if within(ROOT, e.real):
            errors.append(f"{e.lineno}행: 작업 폴더 자체나 그 상위({e.raw})는 연결할 수 없음 — 세션 폴더가 자기 자신을 품게 됨")
        elif any(within(e.real, sd) or within(e.given, sd) for sd in sdirs):
            errors.append(f"{e.lineno}행: 세션 폴더 안의 경로({e.raw})는 연결할 수 없음")
        else:
            kept.append(e)
    errors.sort(key=lambda m: int(m.split("행", 1)[0]) if m.split("행", 1)[0].isdigit() else 0)
    return kept, sessions, errors


def collect_sessions(entries):
    names = list(dict.fromkeys(e.session for e in entries))
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
def settings_json(sdir, live):
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
    r = gesc(str(ROOT))
    data = {
        # 세션 폴더의 상위(작업 폴더 루트)에 있는 기존 지침은 이 세션에 섞지 않는다
        "claudeMdExcludes": [f"{r}/CLAUDE.md", f"{r}/CLAUDE.local.md",
                             f"{r}/.claude/CLAUDE.md", f"{r}/.claude/rules/**"],
        # 같은 git 저장소 하위 폴더는 auto memory 를 공유하므로 세션 간 누수를 막는다
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
        "- 읽기는 왼쪽 링크 경로로 한다.",
        "- 쓰기(Write/Edit)는 링크를 거치지 말고 오른쪽 실제 경로로 한다. 심볼릭 링크를 통한 쓰기는 거부된다.",
        "- 읽기 전용 경로는 수정하지 않는다. 바꿔야 하면 보고서나 대화에 제안으로 남긴다.",
        "- Glob/Grep 은 상위 폴더에서 재귀 탐색할 때 링크 폴더 안을 건너뛴다. 링크 폴더를 검색 시작 경로로 직접 지정하거나, Bash 에서 `rg -L` / `find -L` 을 쓴다.",
        "- 이 표에 없는 경로는 이 세션의 작업 범위가 아니다.",
        "",
    ]
    return "\n".join(out)


def gitignore(ents):
    out = ["# __HUB__/harness.sh sync 가 자동 생성 — 아래는 links.conf 로 재현되는 것들",
           ".claude/settings.json", ".claude/settings.local.json", "LINKS.md"]
    out += ["/" + e.name for e in sorted(ents, key=lambda x: x.name)]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- 출력
def print_rows(session, sdir, rows, extra, quiet):
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
    if not (sdir / "CLAUDE.md").exists():
        print("  [주의] CLAUDE.md 가 없습니다 — 이 세션의 역할 지침을 작성하세요.")


LEGEND = """
  상태 설명: 정상/생성/갱신=사용 가능 | 미생성·다름=sync 하면 해결 | 목록외=links.conf 에 없는 링크(sync 때 제거)
            대상없음=links.conf 의 경로가 없음 | 충돌=세션 폴더에 같은 이름의 실제 파일·폴더가 있음(직접 정리)"""


def print_errors(errors):
    print("[links.conf 오류]")
    for m in errors:
        print("  - " + m)


# ---------------------------------------------------------------- 명령
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
    entries, sessions, errors = parse_conf()
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
                st = "대상없음"
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
        write_if_changed(sdir / ".claude" / "settings.json", settings_json(sdir, live))
        write_if_changed(sdir / "LINKS.md", links_md(session, sdir, live))
        write_if_changed(sdir / ".gitignore", gitignore(ents))
        print_rows(session, sdir, rows, extra, quiet)
    if not quiet:
        print(LEGEND)
    return 0


def cmd_check():
    entries, sessions, errors = parse_conf()
    if errors:
        print_errors(errors)
    for session in sessions:
        sdir = ROOT / session
        ents = [e for e in entries if e.session == session]
        rows = [(state_of(e, sdir)[0], e) for e in ents]
        extra = [("목록외", c.name) for c in unlisted_links(sdir, {e.name for e in ents})]
        print_rows(session, sdir, rows, extra, quiet=False)
    print(LEGEND)
    return 0


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
    entries, sessions, _ = parse_conf()
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
            print(f"{actor:<14} {name:<28} {target:<44} ro   # {cnt}개, {hsize(size)}{tag}")
        if len(items) > 15:
            print(f"# … 외 {len(items) - 15}개 (키워드로 좁히기: find <키워드>)")
    return 0


def main(argv):
    cmd = argv[0] if argv else "check"
    if cmd == "sync":
        return cmd_sync(quiet="--quiet" in argv[1:])
    if cmd == "check":
        return cmd_check()
    if cmd == "find":
        return cmd_find(argv[1:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
__HARNESS_PY__

# ------------------------------------------------------------------
# 5. links.conf (없을 때만 생성) → 첫 sync
# ------------------------------------------------------------------
row() { printf '%-14s %-18s %-40s %s\n' "$@"; }

suggest_lines() {
  local entry name mode q found=0
  printf '\n# --- 기존 작업물 → %s  (필요한 줄만 맨 앞 # 을 지우고 sync) -----------------\n' "$ACTOR"
  printf '# 설치 시점의 작업 폴더 최상위 항목이다. 코드는 rw, 결과·데이터·체크포인트는 ro 권장.\n'
  printf '# %s 에는 코드를 연결하지 않는다 (코드 블라인드 원칙).\n' "$ORCH"
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
# 링크 매니페스트 — 각 세션 폴더 안에 무엇을 보여줄지 정하는 유일한 기준
#
#   형식:  세션   세션_안_이름   실제_경로   권한
#     세션          세션 폴더 이름 ($ORCH, $ACTOR)
#     세션_안_이름  세션 폴더에 생길 링크 이름 (슬래시 불가)
#     실제_경로     작업 폴더 기준 상대경로 또는 절대경로(~ 가능). 공백이 있으면 "따옴표"
#     권한          ro = 읽기 전용(기본) | rw = 읽기·쓰기
#                   → 세션의 .claude/settings.json 으로 변환되어 ro 는 파일 도구 수정이 실제로 막힘
#
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
  suggest_lines
}

say "[5/5] 링크 매니페스트와 첫 동기화"
gen_conf | write_new "$HUB/links.conf"
"$HUB/harness.sh" sync

say ""
say "=================================================================="
say "설치 완료. 다음 순서로 진행하세요."
say ""
say "  1) $HUB_NAME/links.conf 에서 Actor 에 연결할 기존 폴더 줄의 # 을 지우고:"
say "       ./$HUB_NAME/harness.sh sync"
say "  2) 세션 열기 (터미널 2개):"
say "       ./$HUB_NAME/harness.sh open $ORCH      (= cd $ORCH && claude)"
say "       ./$HUB_NAME/harness.sh open $ACTOR"
say "  3) 첫 실행 때 '폴더 신뢰'와 '외부 import 허용' 확인이 한 번씩 뜹니다 → 허용"
say "     (OVERVIEW.md·PROTOCOL.md 가 세션 폴더 밖 $HUB_NAME/shared 의 실제 파일이라서)"
say "  4) 세션 안에서 /context → Memory files 에 작업 폴더 루트 CLAUDE.md 가 없는지 확인"
say "  5) $HUB_NAME/shared/OVERVIEW.md §3 표와 $ACTOR/CLAUDE.md §5 실행 정보를 채우세요"
say "=================================================================="