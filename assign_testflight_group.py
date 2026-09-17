#!/usr/bin/env python3
"""이번에 업로드한 빌드(pubspec.yaml의 버전 번호로 식별)를 TestFlight 내부 테스트 그룹에 자동 배정한다.

xcrun altool로 업로드한 빌드는 App Store Connect의 "자동 배포"(Xcode 빌드 전용)
대상에서 제외되어 매번 수동으로 그룹에 추가해야 한다. 이 스크립트가 그 수동
작업을 App Store Connect API 호출로 대체한다.

필요 환경변수(.env에 설정, upload.sh가 source 후 export):
    ASC_KEY_ID       App Store Connect API Key ID
    ASC_ISSUER_ID    App Store Connect API Issuer ID
    ASC_KEY_PATH     .p8 개인키 파일의 절대경로 (리포 밖 보관 권장)

설치:
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

실행:
    python3 assign_testflight_group.py
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Any

import jwt
import requests

API_BASE_URL = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.dokkaebi.dokkaebiApp"
TESTFLIGHT_GROUP_NAME = "도깨비"
JWT_EXPIRATION_SECONDS = 19 * 60  # Apple 최대 20분 제한 + 1분 여유
BUILD_POLL_INTERVAL_SECONDS = 15
BUILD_POLL_TIMEOUT_SECONDS = 10 * 60
BUILD_LIST_PAGE_SIZE = 10  # 업로드 직후 목록에 아직 안 보일 수 있어 여유있게 조회
PUBSPEC_PATH = Path(__file__).parent / "pubspec.yaml"

# 앱이 표준 HTTPS 외 자체 암호화를 쓰지 않아 기존 빌드(1~7)도 전부 false로
# 답변되어 있음. 이 답변이 없으면(null) 빌드가 어떤 테스트 그룹에도 노출되지
# 않는다 — Apple이 "그룹에 배정 불가"로 잘못 표시하는 실제 원인.
USES_NON_EXEMPT_ENCRYPTION = False


class AppStoreConnectApiError(Exception):
    """App Store Connect API가 예상과 다른 응답을 반환했을 때."""


class BuildProcessingTimeoutError(Exception):
    """빌드 처리(PROCESSING)가 제한 시간 내 끝나지 않았을 때."""


def _read_required_env(name: str) -> str:
    """.env에서 upload.sh가 export한 필수 환경변수를 읽는다. 없으면 즉시 종료."""
    value = os.environ.get(name)
    if not value:
        print(f"오류: 환경변수 {name}이(가) 설정되지 않았습니다. .env를 확인하세요.", file=sys.stderr)
        sys.exit(1)
    return value


def read_expected_build_number() -> str:
    """pubspec.yaml의 'version: X.Y.Z+N'에서 빌드 번호(N)를 읽는다.

    "최신 업로드 빌드"를 무조건 가져오면, 방금 올린 빌드가 아직 API 목록에
    반영되기 전이라 이전 빌드(이미 심사 제출되어 그룹 배정이 막혀 있을 수
    있는)를 잘못 집을 수 있다. 이번 실행이 실제로 의도한 빌드인지 버전
    번호로 확인한다.
    """
    text = PUBSPEC_PATH.read_text()
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("version:"):
            version_value = stripped.split(":", 1)[1].strip()
            if "+" not in version_value:
                raise AppStoreConnectApiError(f"pubspec.yaml의 version에 빌드 번호(+N)가 없습니다: {version_value}")
            return version_value.split("+", 1)[1]
    raise AppStoreConnectApiError(f"{PUBSPEC_PATH}에서 version 줄을 찾지 못했습니다.")


def generate_jwt(key_id: str, issuer_id: str, private_key_path: str) -> str:
    """App Store Connect API 인증용 ES256 JWT를 발급한다."""
    private_key = Path(private_key_path).read_text()
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + JWT_EXPIRATION_SECONDS,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def _request(method: str, path: str, token: str, **kwargs: Any) -> dict[str, Any]:
    """App Store Connect API에 인증된 요청을 보내고 JSON 응답을 반환한다."""
    response = requests.request(
        method,
        f"{API_BASE_URL}{path}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
        **kwargs,
    )
    if not response.ok:
        raise AppStoreConnectApiError(f"{method} {path} 실패 ({response.status_code}): {response.text}")
    return response.json() if response.content else {}


def find_app_id(bundle_id: str, token: str) -> str:
    """번들 ID로 App Store Connect 앱의 내부 ID를 조회한다."""
    data = _request("GET", "/apps", token, params={"filter[bundleId]": bundle_id})
    apps = data.get("data", [])
    if not apps:
        raise AppStoreConnectApiError(f"번들 ID {bundle_id}에 해당하는 앱을 찾지 못했습니다.")
    return apps[0]["id"]


def wait_for_build(app_id: str, expected_version: str, token: str) -> str:
    """이번에 업로드한 빌드 번호(expected_version)가 목록에 나타나 처리 완료될 때까지 기다린다.

    "최신 업로드"만 보고 가져오면 방금 올린 빌드가 아직 API에 반영되기 전
    이전 빌드(예: 이미 심사 제출되어 그룹 배정이 막힌 빌드)를 잘못 집을 수
    있어, 빌드 번호를 명시적으로 대조한다.
    """
    deadline = time.monotonic() + BUILD_POLL_TIMEOUT_SECONDS
    while True:
        data = _request(
            "GET",
            "/builds",
            token,
            params={"filter[app]": app_id, "sort": "-uploadedDate", "limit": BUILD_LIST_PAGE_SIZE},
        )
        builds = data.get("data", [])
        match = next((b for b in builds if b["attributes"].get("version") == expected_version), None)

        if match is not None:
            state = match["attributes"]["processingState"]
            if state == "VALID":
                print(f"빌드 {expected_version} 처리 완료.")
                return match["id"]
            if state in ("FAILED", "INVALID"):
                raise AppStoreConnectApiError(f"빌드 {expected_version} 처리 실패: {state}")
            print(f"빌드 {expected_version} 처리 중({state})... {BUILD_POLL_INTERVAL_SECONDS}초 후 재확인.")
        else:
            print(f"빌드 {expected_version}이(가) 아직 목록에 없음... {BUILD_POLL_INTERVAL_SECONDS}초 후 재확인.")

        if time.monotonic() >= deadline:
            raise BuildProcessingTimeoutError(
                f"빌드 {expected_version} 처리 대기 시간({BUILD_POLL_TIMEOUT_SECONDS}초) 초과."
            )
        time.sleep(BUILD_POLL_INTERVAL_SECONDS)


def find_beta_group(app_id: str, group_name: str, token: str) -> tuple[str, bool]:
    """앱의 TestFlight 베타 그룹을 이름으로 조회한다. (그룹 id, 내부 그룹 여부)를 반환."""
    data = _request(
        "GET",
        "/betaGroups",
        token,
        params={"filter[app]": app_id, "filter[name]": group_name},
    )
    groups = data.get("data", [])
    if not groups:
        raise AppStoreConnectApiError(f"베타 그룹 '{group_name}'을(를) 찾지 못했습니다.")
    group = groups[0]
    return group["id"], bool(group["attributes"].get("isInternalGroup"))


def ensure_export_compliance(build_id: str, token: str) -> None:
    """암호화 수출 규정 질문(usesNonExemptEncryption)이 비어 있으면 답변한다.

    이 답변이 없으면 빌드가 내부/외부 그룹 어디에도 노출되지 않고, 내부
    그룹에 배정을 시도하면 Apple이 "Cannot add internal group to a build"라는
    오해하기 쉬운 에러로 표시한다.
    """
    data = _request("GET", f"/builds/{build_id}", token)
    if data["data"]["attributes"].get("usesNonExemptEncryption") is not None:
        return
    _request(
        "PATCH",
        f"/builds/{build_id}",
        token,
        json={
            "data": {
                "type": "builds",
                "id": build_id,
                "attributes": {"usesNonExemptEncryption": USES_NON_EXEMPT_ENCRYPTION},
            }
        },
    )
    print(f"암호화 수출 규정 답변: usesNonExemptEncryption={USES_NON_EXEMPT_ENCRYPTION}")


def add_build_to_group(build_id: str, group_id: str, is_internal: bool, token: str) -> None:
    """빌드를 지정한 베타 그룹에 배정한다.

    내부 그룹은 수출 규정 답변만 되면 자동으로 모든 내부 테스터에게
    노출되며, 이 관계 엔드포인트 자체를 지원하지 않는다(호출 시 항상
    422 "Cannot add internal group to a build"). 외부 그룹만 명시적
    배정이 필요하고 가능하다.
    """
    if is_internal:
        return
    _request(
        "POST",
        f"/builds/{build_id}/relationships/betaGroups",
        token,
        json={"data": [{"type": "betaGroups", "id": group_id}]},
    )


def main() -> None:
    key_id = _read_required_env("ASC_KEY_ID")
    issuer_id = _read_required_env("ASC_ISSUER_ID")
    key_path = _read_required_env("ASC_KEY_PATH")

    expected_version = read_expected_build_number()
    token = generate_jwt(key_id, issuer_id, key_path)
    app_id = find_app_id(BUNDLE_ID, token)
    build_id = wait_for_build(app_id, expected_version, token)
    ensure_export_compliance(build_id, token)
    group_id, is_internal = find_beta_group(app_id, TESTFLIGHT_GROUP_NAME, token)
    add_build_to_group(build_id, group_id, is_internal, token)

    if is_internal:
        print(f"내부 그룹 '{TESTFLIGHT_GROUP_NAME}'은 수출 규정 답변만으로 자동 노출됨 — 배정 완료.")
    else:
        print(f"빌드를 '{TESTFLIGHT_GROUP_NAME}' 그룹에 배정 완료.")


if __name__ == "__main__":
    try:
        main()
    except (AppStoreConnectApiError, BuildProcessingTimeoutError) as error:
        print(f"오류: {error}", file=sys.stderr)
        sys.exit(1)
