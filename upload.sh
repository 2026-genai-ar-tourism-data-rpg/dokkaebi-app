#!/bin/bash
set -a
source .env  # .env에서 APP_SPECIFIC_PASSWORD, ASC_* 읽고 자식 프로세스(python)에도 전달
set +a

cd /Users/chan/Documents/Dev/Work/dokkaebi/dokkaebi-app

echo "🔨 빌드 중..."
rm -f build/ios/ipa/*.ipa  # export 실패 시 이전 빌드 IPA를 잘못 재업로드하는 것 방지
flutter build ipa --release --dart-define-from-file=.env --export-options-plist=ios/ExportOptions.plist

IPA_PATH=$(ls build/ios/ipa/*.ipa 2>/dev/null | head -n 1)
if [ -n "$IPA_PATH" ]; then
  echo "📤 업로드 중... ($IPA_PATH)"
  xcrun altool --upload-app --type ios \
    -f "$IPA_PATH" \
    -u jchanhee000@gmail.com \
    -p "$APP_SPECIFIC_PASSWORD"

  if [ $? -eq 0 ]; then
    echo "✅ 업로드 완료!"
    echo "👥 TestFlight 그룹 배정 중..."
    .venv/bin/python3 assign_testflight_group.py
  else
    echo "❌ 업로드 실패"
  fi
else
  echo "❌ 빌드 실패"
fi
