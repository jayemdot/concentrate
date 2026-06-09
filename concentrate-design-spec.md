# Concentrate — UI デザイン仕様 (for Claude Code)

メニューバー常駐の集中アプリ。動作は実装済みで、本書は **見た目の仕様** のみを扱う。
方針: **標準 macOS（HIG）に忠実なベース + システム indigo のアクセント + 集中中のカウントダウンリングを唯一の主役**。
対象: macOS 14+ / SwiftUI（`MenuBarExtra` + ポップオーバー）。ダークを基準に設計、ライトの値も併記。

参照モックアップ: `concentrate-mockup.html`（ブラウザで開いて見た目を確認）。

---

## 1. デザイントークン

### カラー（システムカラー優先 / 下記は実色の目安）

| 役割 | Dark | Light | SwiftUI |
|---|---|---|---|
| アクセント（focus） | `#5E5CE6` | `#5856D6` | `Color.indigo` を基本に |
| アクセント明 | `#7D7BFF` | `#7674E1` | グラデ上端 |
| アクセント暗 | `#4A48C4` | `#3F3DB0` | グラデ下端 |
| リング始点 | `#5E5CE6` | 同左 | グラデ |
| リング終点 | `#8B89FF` | `#9B99FF` | グラデ |
| ポップオーバー地 | 半透明ダーク材質 | 半透明ライト材質 | `.regularMaterial`（後述） |
| 区切り線 | `白 10%` | `黒 10%` | `Color.primary.opacity(...)` ではなく `Divider`/`.separator` |
| テキスト 1次 | `白 94%` | `黒 90%` | `.primary` |
| テキスト 2次 | `白 58%` | `黒 55%` | `.secondary` |
| テキスト 3次 | `白 34%` | `黒 35%` | `.tertiary` |
| 未選択フィル | `白 7%` | `黒 5%` | `.quaternary` 相当 |

> 原則として **システムカラー/マテリアルを使い、ハードコードは最小限に**。アクセントだけは
> 既定青ではなく indigo を明示指定する（これが本アプリの個性）。

### マテリアル（重要）
- ポップオーバー背景は **`.regularMaterial`**（ライト/ダーク自動対応・vibrancy）。
  独自の半透明色で塗らない。角丸はポップオーバー既定に従う（≒ 11–13pt）。
- パスコードダイアログも `.regularMaterial` ベース。

### タイポグラフィ（SF Pro）
| 用途 | フォント | サイズ/ウェイト |
|---|---|---|
| タイマー数字（主役） | **SF Pro Rounded** + `monospacedDigit()` | 46pt / semibold |
| メニューバー残り時間 | SF Pro Rounded + `monospacedDigit()` | 13pt / semibold |
| タイトル（Concentrate / 設定） | SF Pro Text | 14pt / semibold |
| セクションラベル | SF Pro Text | 11pt / semibold / 大文字・トラッキング |
| 本文・ヒント | SF Pro Text | 12–13pt / regular |
| フッター注記 | SF Pro Text | 11pt / `.tertiary` |

```swift
// タイマー数字
Text(remaining).font(.system(size: 46, weight: .semibold, design: .rounded)).monospacedDigit()
```

### スペーシング / 形状
- ポップオーバー内パディング: **16pt**
- 要素間: 縦 9–14pt、コントロール角丸 **8pt**
- セグメント・ボタン高さ: 約 36–40pt
- ポップオーバー幅: **288pt**（240–300 の範囲で可）

### SF Symbols
| 箇所 | Symbol 候補 |
|---|---|
| メニューバー / アプリ（待機） | `scope` または `circle.dotted` |
| 集中中アイコン | 進捗リング（自前描画）。代替: `circle.lefthalf.filled` |
| ロック | `lock.fill` |
| ブロック=オン | `checkmark.shield.fill` |
| 設定の歯車 | `gearshape` |
| 情報ヒント | `lock.fill`（鍵で「ロックされる」ことを示す） |

---

## 2. 画面仕様

### 2-1. ポップオーバー — 待機
- ヘッダー: 左にアプリバッジ（角丸 6pt の indigo グラデ + scope シンボル）+「Concentrate」、右に歯車。
- 「集中する時間」ラベル → **セグメント**: 25 / 45 / 60 / 90 分（`Picker(.segmented)` でも可、ただし数字は rounded + tabular）。選択は indigo グラデ塗り。
  - カスタム時間を足す場合: セグメント末尾に「カスタム…」、選択時に Stepper を展開。
- ヒント1行: 鍵アイコン +「開始するとアプリの切り替えとスペース移動をブロックします。」
- 主ボタン: **「集中を開始」** 全幅・indigo グラデ・白文字。
- フッター: 「時間経過、または ⌃⌥⌘P で解除」（3次テキスト + `kbd` 風）。

### 2-2. ポップオーバー — 集中中（signature）
- 上に「集中中」（indigo・semibold）。
- **カウントダウンリング**: 直径 ≒ 188pt、線幅 12pt、`round` linecap、indigo→periwinkle グラデ。
  - **残り時間** を弧で表現（減っていく）。track は白 8%。
  - 微かな glow（drop-shadow）+ 4 秒周期の breathing（`prefers-reduced-motion`/低電力時は停止）。
  - 中央に rounded tabular 数字 `mm:ss` と「残り」。
- リング下: 「<アプリ名> をロック中」（任意・取得できる場合）。
- 区切り線 → 「解除するには ⌃⌥⌘P」→「⌘⌥Esc（強制終了）は安全のため常に有効です」。

### 2-3. パスコード解除ダイアログ
- `⌃⌥⌘P` で最前面に表示（フローティングパネル）。背景は dim + 軽いブラー。
- 内容: 鍵バッジ →「ロックを解除」→「パスコードを入力してください」→ **桁ドット**（入力済みは indigo + glow）→「キャンセル / 解除」。
- 解除は破壊的でないので OK ボタンは indigo（赤にしない）。Esc でキャンセル。

### 2-4. 設定
- ポップオーバー内のリスト（または `Settings` シーン）。標準トグル中心。
- 行: 解除パスコード「変更…」/ **ブロック対象**（⌘Tab / キーボードのスペース移動 / スワイプのスペース移動＝引き戻し）/ ログイン時に起動。
- 末尾に「⌘⌥Esc は安全のため常に有効です」。

### 2-5. メニューバーアイコン
- 待機: scope シンボル（テンプレート画像、モノクロ）。
- 集中中: **進捗リング + 残り時間テキスト**（例 `◔ 23:41`、rounded tabular）。色は menu bar 既定に追従し、過度に着色しない。

---

## 3. モーション
- リング breathing: 4s ease-in-out（任意・控えめ）。
- 待機⇄集中の遷移: ポップオーバー内容の crossfade（0.2s）。
- すべて `prefers-reduced-motion` を尊重し、低電力モードでは glow/breathing を無効化。

## 4. アクセシビリティ / 品質ライン
- ライト/ダーク両対応（マテリアル使用で自動）。
- VoiceOver: リングに「残り 23 分」等のラベル。色だけに依存しない。
- キーボード操作: セグメント・ボタンにフォーカスリング。Esc でダイアログ閉じる。
- Dynamic Type をある程度尊重（タイマーは固定でも可）。

## 5. 実装の入口（SwiftUI）
- `MenuBarExtra("Concentrate", systemImage: "scope") { ... }` + `.menuBarExtraStyle(.window)` でポップオーバー風。
- 集中中はラベルを残り時間テキストへ差し替え（`MenuBarExtra` の label を状態で切替）。
- パスコードは独立した `NSPanel`（`.floating`, `.nonactivatingPanel`）か SwiftUI の Window。
- 色は `Color.indigo` 基調、マテリアルは `.regularMaterial`。ハードコード色は最小限に。
