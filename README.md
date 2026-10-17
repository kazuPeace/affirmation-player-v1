# アファメーションプレーヤV1

> Branch `codex/voicevox-enabled` builds an ARM64 Android APK with VOICEVOX CORE 0.16.4, VOICEVOX ONNX Runtime 1.17.3, Open JTalk dictionary, and the 0/13/19/21 VVM models. The CI workflow downloads pinned official release assets at build time; they are not committed to this repository. The TTS-only build remains on `codex/buildable-tts-only`.

音楽プレーヤー風 UI でアファメーションを選択・編集・再生できる Flutter アプリです。  
VOICEVOX ローカル音声生成、通常 TTS、BGM 重畳、バックグラウンド再生、通知操作、ロック画面操作、ヘッドホン抜去時停止をまとめて扱える構成にしています。

## 実装概要

- ライブラリ画面
  - 検索、並び替え、お気に入り、複製、削除
  - 曲一覧風カード UI
  - 下部固定 CONFIG パネル
- CONFIG
  - YOU / 通常トグル
  - 通常時のみ有効な一人称入力
  - VOICEVOX + 端末 TTS ナレーター選択
  - BGM 選択
  - BGM 音量、ボイス音量、文間隔、開始ディレイ
  - プリセット保存 / 読込
  - 再生中セッションへの即時反映
- 編集画面
  - 複数文編集
  - 各文の一人称 / 後続文
  - 並び替え、削除、単文試聴、全文プレビュー
  - 新規 / 既存編集
- 再生画面
  - プレーヤー風レイアウト
  - 再生 / 一時停止 / 前へ / 次へ
  - ループ / シャッフル
  - スリープタイマー
  - 文進捗表示と簡易シーク
  - 再生キューから文ジャンプ
- 音声
  - BGM を先に再生し、設定ディレイ後に音声を重畳
  - 1文ごとに音声生成
  - 2文先まで先読み生成
  - キャッシュディレクトリ再利用
  - VOICEVOX 失敗時は TTS フォールバック
- 永続化
  - アファメーション一覧は JSON 保存
  - 最終 CONFIG / プリセットは `shared_preferences`

## ディレクトリ

```text
lib/
  app/              アプリ起動・DI・Theme
  core/             定数
  data/             Repository
  features/         library / editor / player / settings
  models/           永続化・再生用モデル
  services/
    audio/          再生制御・AudioHandler
    speech/         VOICEVOX / TTS / キャッシュ
assets/
  bgm/              同梱 BGM
  voicevox/         Android ローカル VOICEVOX ランタイム資産
```

## セットアップ

### 1. 前提

- Flutter SDK
- Android Studio / Android SDK
- iOS を動かす場合は Xcode
- 参照元 `../voicevox_local` が存在すること

### 2. 依存取得

```bash
flutter pub get
```

### 3. VOICEVOX ランタイム資産の配置

この公開リポジトリには、GitHub の容量制限を避けるため `VOICEVOX Core` の巨大バイナリと辞書資産を含めていません。  
ローカルでビルドする前に、参照元の `../voicevox_local` から同期してください。

```bash
mkdir -p assets android/app/src/main
cp -R ../voicevox_local/assets/voicevox assets/
mkdir -p android/app/src/main/jniLibs
cp -R ../voicevox_local/android/app/src/main/jniLibs/* android/app/src/main/jniLibs/
```

### 4. Android 実行

```bash
flutter run -d android
```

### 5. iOS 実行

```bash
flutter run -d ios
```

## VOICEVOX について

- Android は `../voicevox_local` を元にした MethodChannel + Kotlin + JNI 実装を統合しています
- VOICEVOX Core / Open JTalk 辞書 / VVM は公開リポジトリには含めず、ローカルセットアップ時に `../voicevox_local` から同期する想定です
- iOS ではローカル VOICEVOX 実装を入れていないため、通常 TTS を主経路として利用してください

## BGM について

- `assets/bgm/*.wav` はこのプロジェクト内で生成したループ用アンビエント音源です
- 追加したい場合は `assets/bgm/` へファイルを置き、`lib/core/constants.dart` の `AppBgmCatalog` に追記してください

## 検証

この環境で確認できたもの:

- `flutter analyze`
- `flutter build apk --debug`

この環境で未確認のもの:

- `flutter build ios --simulator --no-codesign`
  - 実行環境に `xcodebuild` が無く、iOS ビルド検証はできていません

## 保存場所

- アファメーション: アプリ Documents 配下の `affirmations.json`
- 音声キャッシュ: アプリ Documents 配下の `audio_cache/`
- 設定 / プリセット: `shared_preferences`

## 主な改善余地

- iOS 向けローカル VOICEVOX 実装
- 通知からの文単位ジャンプ
- 波形 / ビジュアライザの強化
- BGM フェードイン / フェードアウト
