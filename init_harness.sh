#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "🚀 Research Harness 워크스페이스 초기화를 시작합니다..."
echo "=================================================================="

# 1. 디렉토리 구조 생성
mkdir -p .orchestrator .actor records/exp_history work src assets/snapshots assets/checkpoints scripts
echo "[1/4] 디렉토리 구조 생성 완료 (.orchestrator, .actor, records, work, src, assets, scripts)"

# ------------------------------------------------------------------
# 2. 마크다운 문서 생성 (OVERVIEW, PROTOCOL, INDEX, painpoints)
# ------------------------------------------------------------------

cat << 'EOF' > OVERVIEW.md
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
EOF

cat << 'EOF' > PROTOCOL.md
# Orchestrator - Actor Interaction Protocol

본 워크스페이스는 연구자(User)의 직접 통제하에 운영되며, 두 에이전트 세션(Orchestrator, Actor)은 컨텍스트 오염을 막기 위해 서로 다른 층위의 파일만 다룬다.

## 1. 컨텍스트 위생 및 온디맨드(On-Demand) 열람 규칙
- **상시 열람:** 두 세션 모두 시작 시 `OVERVIEW.md`와 자신의 전용 `CLAUDE.md`만 읽는다.
- **필요시 열람 (`records/`):** 과거 기록이 담긴 `records/` 폴더는 평소에 전부 읽지 않는다. 새로운 계획을 세우거나 반복되는 문제에 막혔을 때만 `records/INDEX.md`를 확인하고 필요한 문서(`painpoints.md` 등)만 발췌하여 읽는다.

## 2. 역할 및 권한 경계
| 구분 | Orchestrator (기획·가시화·본질 감시) | Actor (과감한 구현·단일 실험·팩트 보고) |
| :--- | :--- | :--- |
| **주 작업 공간** | `work/current_spec.md`, `records/*` | `src/*`, `work/latest_report.md` |
| **코드(`src/*`) 접근** | **원칙적 블라인드** (구조 정리/명시적 지시 시에만 열람, 직접 수정 금지) | **전권 보유** (초안 작성, 구현, 서브에이전트 실험) |
| **검증 및 평가** | KPI와 메커니즘 설명만 보고 **'우회(꼼수) 여부'와 '선행연구 중복'** 심사 | **자기 합리화(Self-eval) 금지**, 단일 시나리오 결과 수치만 건조하게 덤프 |

## 3. 수동 핸드오프(Handoff) 워크플로우
1. **[연구자 -> Orchestrator]:** 아이디어 제시 및 스펙 작성 지시
   - Orchestrator는 선행연구 중복 체크 및 우회 금지 조건을 담아 `work/current_spec.md` 작성.
2. **[연구자 -> Actor]:** 구현 및 빠른 시그널 검증 지시
   - Actor는 `work/current_spec.md`를 읽고 `src/`에 과감하게 구현 후, 다중 시드 없이 핵심 스냅샷에서 빠르게 시그널만 확인하여 `work/latest_report.md`에 수치와 메커니즘 요약만 기록.
3. **[연구자 -> Orchestrator]:** 결과 정리 및 본질 부합 검토 지시
   - Orchestrator는 `work/latest_report.md`를 읽고 꼼수 해결 여부를 판별한 뒤, 가시성 있게 문서를 재작성하고 중요 이력을 `records/exp_history/`에 아카이빙.
EOF

cat << 'EOF' > records/INDEX.md
# On-Demand Records Index (기록 목차)

평소에는 이 파일의 목록만 참조하고, 작업 중 아래 상황에 해당할 때만 실제 문서를 열어 컨텍스트에 로드하라.

1. **`records/painpoints.md`**
   - **열람 시점:** 새로운 실험 스펙을 설계할 때(Orchestrator), 혹은 구현 방향이 보수적인 휴리스틱으로 흐르거나 과잉 검증을 하려 할 때(Actor).
   - **내용:** 지난 3개월간의 핵심 시행착오 7가지 및 절대 금기 패턴(Anti-Patterns).
2. **`records/exp_history/`**
   - **열람 시점:** 이전에 시도했던 아키텍처나 실패했던 파라미터 조합을 다시 확인해야 할 때.
EOF

cat << 'EOF' > records/painpoints.md
# 3-Month Painpoints & Anti-Patterns (절대 금기 사항)

이 문서는 지난 3개월간 연구 생산성을 갉아먹은 최악의 패턴들이다. 아래 패턴이 감지되면 즉시 작업을 중단하고 교정하라.

## 1. 우회 해결(Workaround) 후 국소적 기여로 포장하기 [가장 치명적]
- **현상:** 근본 원인을 해결하지 않고 조건문 분기, 예외 처리, 환경 제약 우회 등 얄팍한 휴리스틱으로 에러만 가린 뒤 "해결했다"고 주장함. 시작부터 잘못된 전제를 깔고 들어가 이후 실험 전체를 오염시킴.
- **처방:** 문제를 피해 가는 땜질 코드는 수치가 올라도 **전부 실패로 간주**한다. 실패하더라도 정면으로 부딪히는 구조적·본질적 메커니즘 변경만 인정한다.

## 2. 잘못된 핀트의 과잉 검증 (학회 논문에 저널급 엄밀성 들이대기)
- **현상:** 방법론의 포텐셜(성능 도약)도 확인하기 전에 다중 시드(Multi-seed)로 돌리고 취약점을 파고들며 혼자 한계점(Limitation)을 걱정함. 특히 우회해서 얻은 얄팍한 결과를 정당화하려고 이상한 지점에서 검증을 강하게 걸어 병목을 만듦.
- **처방:** 탐색 단계에서는 직관적으로 확인 가능한 단일 실험이면 충분하다. 눈에 띄는 성능 향상이 나오기 전까지는 다중 시드, Ablation, 엣지케이스 검증을 **절대 제안하거나 실행하지 마라.**

## 3. 보수적 시도와 선행연구 중복 불감증
- **현상:** 새로운 해석과 없는 방법을 만들어야 하는데 지극히 보수적이고 안전한 시도만 함. 반면 최근 학회 논문들과 기여(Contribution)가 겹치는지는 둔감함.
- **처방:**
  - **사전 중복 체크 & 영감 흡수:** 기획 단계에서 최신 연구와 방법론이 단순 중복되는지 빠르게 확인하되, 비슷한 문제의식을 가진 연구에서 돌파구 영감을 적극 가져와 비틀어라.
  - **야심 찬 시도 우선:** 검증되지 않았다는 이유로 과감한 아이디어를 반려하거나 휴리스틱으로 깎아내리지 마라.

## 4. 컨텍스트 오염 및 번역투 외계어 출력
- **현상:** 코드 작성과 문서 관리를 한 세션에서 처리하다 보니 LLM 출력이 컨텍스트를 잠식하고, 영어권 유머나 비유를 억지로 한국어로 직역해 알아들을 수 없는 문장을 생성함.
- **처방:** 모든 보고와 문서는 **건조하고 명료한 한국어 개조식**으로 작성한다. 불필요한 수식어, 영어 유머 직역, 장황한 서론을 엄격히 금지한다.
EOF

echo "[2/4] 공통 마크다운 및 온디맨드 기록 문서 생성 완료 (OVERVIEW.md, PROTOCOL.md, records/*)"

# ------------------------------------------------------------------
# 3. 각 세션별 CLAUDE.md 및 작업 템플릿 생성
# ------------------------------------------------------------------

cat << 'EOF' > .orchestrator/CLAUDE.md
# Role: Research Orchestrator (기획·가시화·본질 감시자)

너는 연구자의 사고를 돕는 아키텍트다. 루트의 `OVERVIEW.md`와 `PROTOCOL.md`를 먼저 읽고, 필요시 `records/painpoints.md`를 참조하라.

## 1. 언어 및 컨텍스트 위생 규칙 (필수)
- **건조하고 명확한 한국어 사용:** 영어 유머/관용구 직역, 번역투, 과장된 수식어를 절대 쓰지 마라. 사람이 한눈에 읽을 수 있는 가시성 높은 한국어 개조식과 표(Table)만 사용하라.
- **코드 블라인드 원칙:** 컨텍스트 오염을 막기 위해 `src/` 내부 코드는 원칙적으로 읽지 않고 직접 수정하지도 않는다. 오직 Actor가 보고한 **KPI 수치, 핵심 수식/메커니즘 요약**만 읽고 판단한다. (단, 연구자가 디렉토리 정리나 특정 파일 확인을 지시할 때만 예외적으로 접근)

## 2. 핵심 임무
1. **과감한 기획 및 선행연구 체크 (`work/current_spec.md` 작성):**
   - 최신 학회 논문들과 기여가 겹치는지 빠르게 검증하되, 인접 연구의 돌파구에서 영감을 얻어 **보수적이지 않은 야심 찬 실험 스펙**을 작성하라.
2. **우회 해결(Workaround) 심문:**
   - Actor가 `work/latest_report.md`에 올린 결과를 볼 때, 본질적인 문제를 정면 돌파했는지 아니면 얄팍한 휴리스틱으로 우회했는지 가장 먼저 심사하라. 우회 해결이면 즉시 폐기를 건의하라.
3. **과잉 검증 차단:**
   - 확실한 성능 도약(Signal)이 확인되기 전에는 절대 다중 시드 실험이나 한계점 검증을 지시하지 마라.
4. **가시성 정리:**
   - 흩어진 실험 결과와 문서 구조를 언제나 사람이 보기 편하게 재작성하고 정돈하라.
EOF

cat << 'EOF' > .actor/CLAUDE.md
# Role: Execution Actor (과감한 구현 및 빠른 시그널 탐색기)

너는 `OVERVIEW.md`의 본질을 달성하기 위해 코드를 구현하고 시뮬레이션을 돌리는 실행기다. 작업 전 `PROTOCOL.md`와 `work/current_spec.md`를 확인하라.

## 1. 구현 및 실험 원칙 (필수)
- **보수적 휴리스틱 절대 금지:** 새로운 시도나 해석을 코드로 옮길 때, 안전하게 가겠다고 조건문 분기(`if-else`), 하드코딩된 임계값, 예외 처리 땜질로 우회하지 마라. 요구된 메커니즘을 가장 순수하고 과감한 형태로 구현하라.
- **빠른 시그널 확인 (No Over-validation):** 연구자가 명시적으로 지시하지 않는 한, 여러 시드(Seed)를 돌리거나 엣지케이스 취약점을 검증하는 데 시간을 쓰지 마라. 서브에이전트를 활용해 대표 스냅샷/시나리오에서 **성능이 확실히 뛰는가(Signal)**만 가장 빠르게 확인하라.
- **자기 합리화(Self-justification) 금지:** 결과를 보고할 때 너의 코드를 변호하거나 국소적인 꼼수 개선을 큰 기여인 것처럼 포장하지 마라.

## 2. 결과 보고 규칙 (`work/latest_report.md`)
- 영어식 유머나 장황한 설명 없이 **건조하고 명확한 한국어**로 작성하라.
- 원본 코드나 긴 에러 로그를 복붙하지 말고, **(1) 구현한 핵심 메커니즘 (우회 여부 명시), (2) 단일 실험 핵심 KPI 전/후 비교, (3) 관찰된 물리적/수치적 현상 팩트**만 간결하게 기록하라.
EOF

cat << 'EOF' > work/current_spec.md
# Current Task Spec (Orchestrator 작성란)
- **목표 가설:** (작성 대기 중)
- **구현 방향 (우회 금지 조건):** 
- **확인할 단일 KPI:** 
EOF

cat << 'EOF' > work/latest_report.md
# Latest Execution Report (Actor 작성란)
- **구현 메커니즘 요약:** (작성 대기 중)
- **핵심 KPI 변화:** 
- **관찰된 팩트:** 
EOF

echo "[3/4] 세션별 지침(.orchestrator/CLAUDE.md, .actor/CLAUDE.md) 및 작업대(work/*) 생성 완료"

# ------------------------------------------------------------------
# 4. 강건한 심볼릭 링크 스크립트 생성 (scripts/link_assets.sh)
#    실행은 .sh로 간편하게 하되, 내부에서 Python 퍼지 매칭을 수행하여
#    OS 호환성(Linux/Mac)과 이름 변경 대응력을 모두 확보함.
# ------------------------------------------------------------------

cat << 'EOF' > scripts/link_assets.sh
#!/usr/bin/env bash
set -euo pipefail

# 사용법: ./scripts/link_assets.sh [탐색할_외부_워크스페이스_경로...]
# 인자가 없으면 기본적으로 상위 폴더(..)를 탐색합니다.

python3 - "$@" << 'PYEOF'
import os
import sys
import argparse
from pathlib import Path
from difflib import SequenceMatcher

# 하네스 폴더 구조에 맞춘 기본 타겟 및 검색 키워드
DEFAULT_RULES = {
    "assets/snapshots": ["snapshot", "pkl", "hdf5", "drop", "fail", "state", "recov"],
    "assets/checkpoints": ["ckpt", "pt", "pth", "safetensors", "weight", "model", "pi0"],
    "records": ["painpoint", "postmortem", "retro", "issue", "note"],
}

IGNORE_DIRS = {
    ".git", "__pycache__", "node_modules", ".venv", "venv", "env",
    "wandb", "outputs", "artifacts", ".actor", ".orchestrator", "work", "records"
}

def calc_score(path: Path, keywords: list[str]) -> float:
    name_low = path.name.lower()
    parent_low = path.parent.name.lower()
    tokens = set(path.stem.lower().replace("-", "_").replace(".", "_").split("_"))
    
    max_s, matched = 0.0, 0
    for kw in keywords:
        kw = kw.lower()
        s = 0.0
        if kw == path.stem.lower() or kw == path.suffix.lower().lstrip("."):
            s = 1.0
        elif kw in name_low:
            s = 0.85
        elif kw in parent_low:
            s = 0.65
        else:
            for t in tokens:
                if len(t) >= 2:
                    r = SequenceMatcher(None, kw, t).ratio()
                    if r > 0.75:
                        s = max(s, r * 0.8)
        if s > 0.5:
            matched += 1
        max_s = max(max_s, s)
    bonus = min(0.2, (matched - 1) * 0.1) if matched > 1 else 0.0
    return min(1.0, max_s + bonus)

def scan(roots: list[Path], keywords: list[str], threshold: float, cur_repo: Path):
    cands = []
    for r in roots:
        r = r.expanduser().resolve()
        if not r.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(r):
            cdir = Path(dirpath).resolve()
            if cdir == cur_repo or cur_repo in cdir.parents:
                dirnames[:] = []
                continue
            dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS and not d.startswith(".")]
            
            for f in filenames:
                if f.startswith("."): continue
                fp = cdir / f
                if fp.is_symlink(): continue
                sc = calc_score(fp, keywords)
                if sc >= threshold:
                    cands.append((sc, fp))
    cands.sort(key=lambda x: (x[0], x[1].stat().st_mtime), reverse=True)
    return cands

def link_items(cands, dest_dir: Path, auto_yes: bool):
    if not cands:
        print("  -> 조건에 맞는 파일이 없습니다.")
        return
    dest_dir.mkdir(parents=True, exist_ok=True)
    top = cands[:12]
    print(f"\n[타겟: {dest_dir.relative_to(Path.cwd())}] 상위 매칭 후보:")
    for idx, (sc, p) in enumerate(top, 1):
        print(f"  {idx:2d}) (점수:{sc:.2f}) {p}")
    
    selected = top
    if not auto_yes:
        ans = input("\n링크할 번호 입력 (a: 전체 / 1,3: 일부 / Enter: 건너뛰기): ").strip().lower()
        if not ans or ans == 'n':
            return
        elif ans not in ('a', 'y'):
            try:
                idxs = [int(x.strip()) - 1 for x in ans.split(",")]
                selected = [top[i] for i in idxs if 0 <= i < len(top)]
            except ValueError:
                print("  -> 잘못된 입력입니다. 건너뜁니다.")
                return

    for _, src in selected:
        link_p = dest_dir / src.name
        if link_p.exists() or link_p.is_symlink():
            if link_p.resolve() == src.resolve():
                print(f"  [SKIP] 이미 연결됨: {link_p.name}")
                continue
            link_p = dest_dir / f"{src.parent.name}_{src.name}"
        link_p.symlink_to(src)
        print(f"  [LINKED] {link_p.name} -> {src}")

def main():
    parser = argparse.ArgumentParser(description="키워드 퍼지 매칭 기반 심볼릭 링크 생성기")
    parser.add_argument("sources", nargs="*", default=[".."], help="탐색할 워크스페이스 경로 (기본: ..)")
    parser.add_argument("-k", "--keywords", nargs="+", help="특정 키워드로 즉시 검색")
    parser.add_argument("-d", "--dest", default="assets", help="-k 사용 시 저장할 타겟 폴더")
    parser.add_argument("-t", "--threshold", type=float, default=0.65, help="유사도 임계값 (기본: 0.65)")
    parser.add_argument("-y", "--yes", action="store_true", help="묻지 않고 상위 매칭 파일 전체 링크")
    args = parser.parse_args()

    cur_repo = Path.cwd().resolve()
    roots = [Path(p) for p in args.sources]
    print(f"=== 외부 워크스페이스 에셋 탐색 (기준: {[str(r.resolve()) for r in roots if r.exists()]}) ===")

    if args.keywords:
        cands = scan(roots, args.keywords, args.threshold, cur_repo)
        link_items(cands, cur_repo / args.dest, args.yes)
    else:
        for dest_rel, kws in DEFAULT_RULES.items():
            print(f"\n>>> [{dest_rel}] 검색 중 (키워드: {kws})")
            cands = scan(roots, kws, args.threshold, cur_repo)
            link_items(cands, cur_repo / dest_rel, args.yes)

if __name__ == "__main__":
    main()
PYEOF
EOF

chmod +x scripts/link_assets.sh
echo "[4/4] 심볼릭 링크 유틸리티 생성 및 실행 권한 부여 완료 (scripts/link_assets.sh)"

echo "=================================================================="
echo "✅ 하네스 세팅이 완료되었습니다!"
echo ""
echo "📌 다음 단계 안내:"
echo "  1) 기존 작업 폴더에서 에셋 가져오기:"
echo "     ./scripts/link_assets.sh ~/기존_워크스페이스_경로"
echo "     (특정 키워드 지정 시: ./scripts/link_assets.sh ~/경로 -k libero drop -d assets/snapshots)"
echo ""
echo "  2) 두 개의 터미널 세션을 열고 각각 지침 로드하기:"
echo "     - [Session 1 - Orchestrator]: .orchestrator/CLAUDE.md 기반으로 시작"
echo "     - [Session 2 - Actor]       : .actor/CLAUDE.md 기반으로 시작"
echo "=================================================================="
