# 원스토어 Android 출시 확인

## 패키지 및 서명

- applicationId / namespace / MainActivity 패키지: `com.soomtrip.app`
- MainActivity 경로: `android/app/src/main/kotlin/com/soomtrip/app/MainActivity.kt`
- `android/key.properties.example`을 `android/key.properties`로 복사하고 실제 출시 키스토어 경로, alias, 비밀번호를 로컬에서 입력한다. 이 파일과 키스토어는 Git에 올리지 않는다.
- 기존 배포가 있다면 기존 서명 키를 사용한다. 키를 임의로 새로 만들지 않는다.
- 릴리스는 지정한 키로 서명한다. 서명 설정이 없으면 빌드가 실패하며 디버그 키로 대체하지 않는다.

## 카카오 Developers (콘솔에서 확인 필요)

1. `.env`의 `KAKAO_NATIVE_APP_KEY`가 속한 앱의 Android 플랫폼에 `com.soomtrip.app`을 등록한다.
2. 실제 배포 APK의 서명 인증서에 해당하는 키 해시를 등록한다. 디버그 키와 출시 키의 해시는 다르다.
3. AndroidManifest의 콜백 scheme이 `kakao` + 위 네이티브 앱 키이고 host가 `oauth`인지 확인한다.

키스토어에서 카카오 키 해시를 계산하는 예시 (비밀번호는 keytool 프롬프트에 입력):

```sh
keytool -exportcert -alias YOUR_ALIAS -keystore /absolute/path/to/release-keystore.jks -file /tmp/soomtrip-release-cert.der
openssl dgst -sha1 -binary /tmp/soomtrip-release-cert.der | openssl base64
```

첫 명령이 성공한 경우에만 두 번째 명령을 실행한다. 해시는 인증서 SHA-1 바이트의 Base64이며, 콜론으로 구분된 SHA-1 문자열과 다르다. 스토어가 다시 서명한다면 실제 설치 APK의 인증서를 기준으로 등록한다.

## 재빌드 및 확인

서명 설정을 채운 뒤 프로젝트 루트에서 각 명령의 성공을 확인하며 실행한다.

```sh
flutter clean
flutter pub get
flutter build apk --release
```

새 결과물: `build/app/outputs/flutter-apk/app-release.apk`. 첨부된 원스토어 상품 유형은 Mobile APK Only이므로 이 APK를 검증한다.

Android SDK build-tools의 도구로 확인:

```sh
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

패키지가 `com.soomtrip.app`이고 의도한 출시 인증서로 서명되었는지 확인한다. 실제 기기에 새 APK를 설치하고 카카오톡 설치/미설치 상태에서 동의 후 앱 진입까지 테스트한다.

## 로그인 실패 원인 구분

화면의 '로그인에 실패했습니다'는 SDK 인증, 백엔드 `/auth/kakao`, 다음 화면 준비 중 오류에 공통으로 표시된다. 반려 화면만으로 키 해시 문제라고 단정하지 않는다. 재현 시 SDK 오류 코드와 서버의 HTTP 상태 및 응답 형식을 확인한다. 액세스 토큰이나 비밀번호를 로그에 남기지 않는다.

2026-09-15 로컬 점검: Android 소스와 기존 release APK의 패키지는 이미 `com.soomtrip.app`이다. 기존 APK 인증서는 `CN=Android Debug`였으며 정식 키 설정 파일은 없었다. `.env` 네이티브 앱 키와 Android 콜백 scheme은 일치했다. 카카오 콘솔 등록 상태 및 실제 제출 APK와의 동일성은 확인하지 못했다.

전체 검색에서 남은 `com.example`은 Linux application ID, macOS bundle/test ID 및 저작권, Windows 회사명/저작권이다. 이 값들은 Android APK에 사용되지 않으며 각 데스크톱 플랫폼 출시 시 별도로 정리한다.

참고: [Flutter Android 배포](https://docs.flutter.dev/deployment/android), [카카오 Flutter 설정](https://developers.kakao.com/docs/ko/flutter/getting-started).
