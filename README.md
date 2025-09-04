# 🏙️ GA City - 遺伝的アルゴリズムによる都市育成ゲーム

![Julia](https://img.shields.io/badge/-Julia-9558B2?style=for-the-badge&logo=julia&logoColor=white)

遺伝的アルゴリズムを使って最適な都市レイアウトを進化させるJuliaプログラムです。

## 🎮 概要

GA Cityは、10×10のグリッド上で理想的な都市を自動生成するシミュレーションゲームです。遺伝的アルゴリズム（GA）を用いて、住宅、職場、サービス施設、公園のバランスが取れた最適な都市配置を探索します。

## ✨ 特徴

- **遺伝的アルゴリズムによる最適化**: Evolutionary.jlパッケージを使用した進化的最適化
- **5種類の施設タイプ**: 
  - `.` 公園（緑地）
  - `=` 道路
  - `H` 住宅
  - `W` 職場（オフィス）
  - `S` サービス施設（商店など）
- **都市評価システム**: 
  - 住宅と職場の距離（通勤時間）
  - 住宅とサービス施設の距離（利便性）
  - 公園の比率（環境の良さ）

## 📋 必要環境

- Julia 1.6以上
- 必要パッケージ:
  - Random
  - Statistics
  - Evolutionary

## 🚀 インストール

```bash
# Juliaパッケージマネージャーで必要なパッケージをインストール
julia -e 'using Pkg; Pkg.add(["Random", "Statistics", "Evolutionary"])'
```

## 💻 使い方

### 基本的な実行

```bash
julia ga_city.jl
```

実行すると対話型メニューが表示され、以下の設定が可能です：

1. **プリセット選択**
   - バランス型（デフォルト）
   - 職住近接重視
   - 緑化重視  
   - サービス重視
   - カスタム設定

2. **進化パラメータ**
   - 個体数（デフォルト: 80）
   - 世代数（デフォルト: 100）
   - 進行ログ表示

3. **遺伝的演算子**
   - 選択: susinv | tournament
   - 交叉: DC | uniformbin
   - 変異: PLM | gaussian

### Juliaの対話環境から実行

```julia
include("ga_city.jl")
main()
```

### プログラム的なカスタマイズ

```julia
include("ga_city.jl")

# GameConfigを直接編集
CFG.w_commute = -1.5      # 通勤距離の重要度を上げる
CFG.w_park = 1.2           # 公園の重要度を上げる
CFG.generations = 200      # 世代数を増やす

# 進化を実行
best_x, best_f = run_ga()

# 最適な都市を表示
println("Best fitness: ", round(best_f, digits=3))
print_city(best_x)
```

## 🏗️ システムの仕組み

### 適応度関数

都市の「良さ」は以下の要素で評価されます：

1. **通勤距離**: 住宅から職場への平均マンハッタン距離（短いほど高評価）
2. **利便性**: 住宅からサービス施設への平均距離（短いほど高評価）
3. **環境**: 公園の比率（多いほど高評価）

各要素の重みは`GameConfig`構造体で調整可能：
- `w_commute`: 通勤距離の重み（負値、デフォルト: -1.0）
- `w_service`: サービス距離の重み（負値、デフォルト: -0.6）
- `w_park`: 公園比率の重み（正値、デフォルト: 0.8）

### 遺伝的アルゴリズムの設定

- **選択**: Stochastic Universal Sampling with Inversion (susinv)
- **交叉**: Discrete Crossover (DC)
- **変異**: Polynomial Mutation (PLM)
- **制約**: 各セルは0〜4の値を取る（BoxConstraints）

## 📊 出力例

```
=== Genetic City (Evolutionary.jl optimize + GA) ===
Best fitness: -15.2

Best city layout:
.H.WS.H.W.
HW.S.HWS.H
.SHWHSW.H.
WH.S.HW.SH
S.HW.S.HWS
.H.WSH.W.S
HWS.HW.SH.
.SHW.SHW..
WH.S.HWS.H
.HWS.H.W.S
```

## 🎮 プリセット設定

### バランス型（デフォルト）
- 通勤、サービス、公園のバランスが取れた都市
- 設定値: 通勤-1.0, サービス-0.6, 公園+0.8

### 職住近接重視
- 通勤時間を最小化する都市設計
- 設定値: 通勤-1.6, サービス-0.4, 公園+0.4

### 緑化重視
- 公園や緑地を多く配置した環境都市
- 設定値: 通勤-0.6, サービス-0.4, 公園+1.4

### サービス重視
- 商業施設へのアクセスを重視した都市
- 設定値: 通勤-0.8, サービス-1.4, 公園+0.4

## 🎯 今後の拡張アイデア

- グリッドサイズの変更機能
- 新しい施設タイプの追加（病院、学校など）
- 地形制約の追加（川、山など）
- インタラクティブな可視化
- 複数目的最適化の実装

## 📝 ライセンス

MITライセンス

## 👤 作者

tdual