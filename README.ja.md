# NimdaGame

言語：[English](README.md) | [简体中文](README.zh-CN.md) | 日本語

NimdaGame は、軽量な RPG 系プロジェクト向けの再利用可能な Godot ベースのゲームフレームワークです。

- ターン制 RPG
- シンプルなリアルタイム RPG とサバイバー系アクションゲーム
- タクティクスゲーム
- タワーディフェンスゲーム
- インクリメンタルゲームまたは放置ゲーム

このリポジトリは、単一のゲームではなく再利用を前提に構成されています。共有ランタイムコード、共有アセット、データツール、ビルドツールは安定したパスに配置します。各ゲームジャンルは、それぞれ独立したパッケージディレクトリを持ちます。

ディレクトリ規約は [docs/repository_layout.md](docs/repository_layout.md) を参照してください。
レイヤー境界は [docs/architecture.md](docs/architecture.md) を参照してください。
ランタイムプラグイン仕様は [docs/plugin_system.md](docs/plugin_system.md) を参照してください。

## レイヤーモデル

- Godot はアプリフロー、シーン、UI 表示、入力、アニメーション、オーディオ、デバッグパネル、エディタ向けワークフローを担当します。
- 純粋な C++ core は、戦闘ルール、ユニット、スキル、バフ、グリッド、経済、乱数、セーブなどの決定論的なゲームプレイシミュレーションを担当します。
- Python ツールは、ソースデータの検証、ランタイム JSON の生成、オフラインシミュレーションやバランスレポートを担当します。
- ランタイムプラグインは GDScript、C++ GDExtension クラス、または外部スクリプトで実装でき、統一された hook 契約で接続します。

## リポジトリ構成

```text
game/app/            Godot の起動シーンとグローバルなアプリフロー
game/common/         複数ジャンルで共有する Godot ランタイムコード
game/shared_assets/  共有アート、オーディオ、フォント、アイコンなどの再利用可能アセット
game/genres/         ジャンルごとの Godot パッケージ
game/plugins/        ランタイムプラグインの manifest と実装
core/common/         共有 C++ ゲームプレイ基盤
core/modules/        再利用可能なゲームプレイモジュール
core/genres/         ジャンルごとの C++ ゲームプレイ編成
bindings/            Godot GDExtension ブリッジと任意の CLI アダプタ
data/common/         共有ソースデータ
data/genres/         ジャンルごとのソースデータ
data/schemas/        設定データと manifest 用の JSON Schema
tools/               Python による検証、生成、シミュレーション、リリースツール
docs/                アーキテクチャとワークフローのドキュメント
release/             リリースターゲット設定、チェックリスト、リリースノートテンプレート
```

## 現在の Godot エントリ

Godot プロジェクトは次のシーンから開始します。

```text
game/app/scenes/main.tscn
```

このシーンは軽量なフレームワーク shell です。ゲームプレイ demo と UI 生成実験は削除済みで、現在のリポジトリはまず再利用可能な構造を固める段階です。

## 初期ワークフロー

1. 共有データは `data/common/` に、ジャンル固有データは `data/genres/<genre>/` に記述します。
2. `tools/` 配下の Python ツールで検証し、ランタイム JSON を生成します。
3. Godot は `game/data/generated/` から生成済み JSON を読み込みます。
4. Godot バインディング層を通して C++ ゲームプレイシミュレーションを呼び出します。
5. `game/genres/<genre>/` 配下の Godot シーンで結果を表示します。

## リリースパイプライン

```powershell
python tools/mygame_tools/release_pipeline.py plan
python tools/mygame_tools/release_pipeline.py check
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/release_pipeline.py notes --version 0.1.0
```

実際のエクスポートには、ローカルの Godot export presets が必要です。詳細は [docs/release_pipeline.md](docs/release_pipeline.md) を参照してください。

## 現在の状態

このリポジトリには、再利用可能なプロジェクト構造、プラグインレジストリ、データツールのスタブ、C++ core scaffold、Godot GDExtension scaffold、リリースツールが含まれています。次の実装マイルストーンでは、汎用 demo ディレクトリではなく、いずれかのジャンルパッケージ内に 1 本の垂直スライスを追加するべきです。
