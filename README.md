# 가림막

macOS에서 화면 일부를 단색으로 가리는 앱입니다. 단색 면을 끌어 옮기고, 가장자리나 모서리를 끌어 크기를 바꿉니다. 창은 여러 디스플레이에 걸쳐 놓을 수 있습니다. 오른쪽 위 점으로 설정을 열고, 왼쪽의 짧은 막대로 불투명도를 조절합니다. 두 마우스 버튼 모두 사용할 수 있습니다.

설정의 **현재 화면 채우기**는 해당 디스플레이의 메뉴 막대까지 가립니다. 채운 가림막을 끌거나 **원래 크기로 복원**을 누르면 이전 크기로 돌아갑니다.

## 빌드

macOS 13 이상과 현재 설치된 Xcode Command Line Tools 또는 Xcode가 필요합니다.

```sh
mkdir -p dist
./build.sh "$PWD/dist/가림막.app"
open "$PWD/dist/가림막.app"
```

빌드 결과는 로컬에서 서명합니다. Dock 아이콘 메뉴에서 **옵션 → Dock에 유지**를 선택할 수 있습니다. 창 위치와 색상 등은 macOS 앱 환경설정에 저장됩니다.

## 검사

```sh
check_dir=$(mktemp -d)
swiftc ShadeGeometry.swift tests/GeometryChecks.swift -o "$check_dir/geometry-checks"
"$check_dir/geometry-checks"
```

CI는 임의로 정한 디스플레이 좌표를 사용해 화면 간 분할, 크기 조절, 이전 크기 복원을 확인합니다. 앱 창 확인은 macOS에서 수행합니다.
