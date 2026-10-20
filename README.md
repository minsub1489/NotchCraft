# NotchCraft

Your AI agents, a little living world. 독립 실행형 macOS AI 에이전트 워크스페이스.

순수 검정 노치에서 시작해, 잔디·목재·돌·작은 횃불로 만든 오리지널 복셀 섬으로 펼쳐집니다. 샴페인 골드 중심의 초기 제안 대신 노치에 자연스럽게 이어지는 검정과 차분한 자연색을 사용합니다. Minecraft 공식 에셋은 포함하지 않습니다.

## 실행

macOS 14 이상, Swift 6 도구 모음이 필요합니다. Apple Silicon에서 개발·검증했습니다.

```sh
./Scripts/build-app.sh
open build/NotchCraft.app
```

또는 `NotchCraft.xcodeproj`를 Xcode에서 열고 **NotchCraft** 스킴을 실행합니다. 프로젝트는 Apple Silicon 우선입니다. Intel은 별도 검증이 필요합니다. 외부 패키지 의존성은 없으며 Apple 프레임워크와 시스템 SQLite를 사용합니다.

1. 첫 실행에서 언어를 선택합니다.
2. 기존에 설치·로그인한 Codex CLI를 연결합니다. NotchCraft는 로그인 정보나 인증 파일을 직접 읽지 않습니다.
3. **작업 시작**에서 프로젝트 폴더와 작업 내용을 입력합니다. 이 단계에서 실제 모델 사용이 발생할 수 있습니다.
4. 주민이나 세션을 선택해 상태·출처·결과·사용량을 확인합니다. 결과 본문은 실행 중 메모리에만 표시합니다.
5. 상단 노치에 마우스를 올려 미리보기를 열거나 클릭해 사무실로 돌아옵니다. 노치가 없어도 화면 위 중앙 패널을 사용합니다. `⌘⇧O`로 사무실, `⌘N`으로 새 작업, `⌘,`로 설정을 엽니다.

**데모 체험**은 별도 원장과 가상 이벤트를 사용하며 화면에 항상 DEMO 표시가 나타납니다. 실제 사용량·비용으로 혼합되지 않습니다. 기본 실행은 실제 모드이며 자동으로 AI 작업을 시작하지 않습니다.

## 현재 범위

| 기능 | 상태 / 한계 |
| --- | --- |
| 노치 접기·호버 미리보기·별도 사무실 | 구현. 화면 안전 영역, 외장 화면 대체 모드, 화면/공간 변경 및 잠자기 복귀 처리 |
| 오리지널 2.5D 복셀 세계 | SpriteKit, 원본 절차적 에셋, 활동 구역 이동·작업 애니메이션·주민 선택·확대/이동 |
| Codex 공식 App Server | stdio 초기화, 세션 메타데이터, 새 작업, 실시간 이벤트, 작업 취소 |
| 외부 Codex 세션 | 최근 최대 50개 기록 조회. 다른 프로세스의 실행 상태·승인·취소는 제공하지 않음 |
| 토큰·계정 사용 한도 | 제공되는 실제 값과 출처·갱신 시각만 표시. API 청구 비용과 미확인 값은 `제공되지 않음` |
| 승인 | 이 앱이 시작한 세션의 명령/파일 변경 요청에 이번만 허용·거부. 세션 전체 자동 승인 없음 |
| 기록·설정·프로젝트 폴더 | 로컬 SQLite 메타데이터와 UserDefaults. 원문·명령 출력 저장 안 함 |
| 한국어 / English | 분리된 로컬라이제이션 리소스와 설정 전환 |
| 성능 옵션 | 기본 30 / 절전 15 FPS, 시스템 및 앱 동작 줄이기, 사무실 비표시 시 렌더링 정지 |
| Claude Code / Gemini / OpenCode | 설치 감지만 구현. 실시간 어댑터는 후속 단계이며 미연결로 표시 |
| 작업 일시중지·재개 | 보장되는 API가 없어 미지원. 취소는 일시중지가 아님 |
| 사용자 플러그인·스킨·고급 프로젝트 정책 | 후속 단계 |

이 앱의 승인 UI는 **Codex가 실제로 요청한 승인**에만 응답합니다. Codex의 샌드박스/실행 정책을 대체하는 범용 정책 엔진은 구현하지 않았습니다. 기본 새 작업은 읽기 전용이며, 프로젝트 쓰기는 사용자가 작업마다 명시적으로 선택합니다. 명령 승인 정책은 `untrusted`, 검토자는 `user`입니다. CLI의 기존 조직 정책을 우회하지 않습니다. 고위험 작업을 종류별로 강제 가로채는 별도 정책은 후속 단계입니다.

공식 프로토콜이 바뀌면 연결이 제한될 수 있습니다. 설치된 CLI 0.136.0이 생성한 스키마와 현재 문서를 함께 검토했습니다. `notLoaded` 세션이나 실행 중인 프로세스만으로 `작업 중`을 표시하지 않습니다. 서버 연결 해제 후 예전 세션을 자동 재개하지 않습니다.

## 검증

```sh
swift test --enable-code-coverage
# 실제 설치된 Codex의 읽기 전용 연결 검증: 스레드/모델 작업 생성 없음
NOTCHCRAFT_LIVE_TEST=1 swift test --filter installedCodexReadOnlySmoke
xcodebuild -project NotchCraft.xcodeproj -scheme NotchCraft \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
```

실제 계정이 없는 CI에서는 읽기 전용 라이브 테스트 1개를 명시적으로 건너뜁니다. 로컬 가짜 App Server 테스트는 일반 테스트에서 실제 자식 프로세스와 JSONL로 실행되며 AI 서비스를 사용하지 않습니다. 검증 결과와 미검증 항목은 [검증 기록](Docs/VERIFICATION.md)에 있습니다.

## 구조

- `Sources/NotchCraftCore`: 공통 이벤트, 상태 원장, 승인 대상 검증, JSONL 프레이밍, SQLite 기록, 노치 위치 계산
- `Sources/NotchCraft/Adapters`: 명시적 기능 계약, CLI 감지, private stdio RPC, Codex 어댑터
- `Sources/NotchCraft/World`: 렌더러와 분리된 구역 정의, 절차적 복셀 에셋, SpriteKit 월드
- `Sources/NotchCraft/App`: 관측 스토어, AppKit 창/노치 수명 주기, 로컬라이제이션
- `Sources/NotchCraft/Views`: 사무실, 실제 세션 상세, 에이전트, 기록, 사용량, 온보딩과 설정

`Scripts/generate-xcode-project.py`는 로컬 Swift 패키지의 코어를 사용하는 앱 프로젝트를 재생성합니다. Swift 소스를 추가한 뒤 실행하면 됩니다. [계획](Docs/PLAN.md), [연동 조사](Docs/INTEGRATIONS.md), [보안 경계](Docs/SECURITY.md)를 참고하세요.

## 배포

`./Scripts/package-release.sh`로 ZIP을 만듭니다. 기본 번들은 로컬 실행용 ad-hoc 서명입니다. 공개 배포에는 개발자의 Developer ID 및 notarization이 필요합니다. 배포 스크립트는 `DEVELOPER_ID_APPLICATION`, `NOTARY_KEYCHAIN_PROFILE`을 지원하며 인증 정보는 소스에 저장하지 않습니다. 상표/제품명 확인과 실제 하드웨어 호환성 검증은 공개 배포 전에 별도로 수행해야 합니다.

코드·절차적 에셋은 [MIT](LICENSE)입니다. 독립 프로젝트이며 Mojang/Microsoft와 제휴하거나 승인을 받은 제품이 아닙니다.
