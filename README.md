# ObjId Manager for BFPortal v1.0.3
# Developed by: hekaron

---

## English Version

### Overview

**ObjId Manager for BFPortal** is an editor addon for **Godot 4.4+**,  
specifically designed for the **Godot project environment included in the Battlefield Portal SDK**.  
It provides a visual interface to manage and export `@export var ObjId` values from Node3D objects.

This addon helps Battlefield Portal creators efficiently manage in-game object IDs,  
especially when developing complex scenes with multiple interactive elements.

---

### Features

- Display all Node3D `ObjId` values in a tree view  
- Highlight duplicate values  
- Auto-generate sequential IDs  
- **Undo / Redo** supported  
- TypeScript export dialog  
  - Convert selected nodes into TypeScript definitions  
  - Maintains export order based on check sequence  
  - Disabled (gray) items for excluded nodes  
  - “Uncheck All” / "Check All" button for quick reset and check all

---

### Installation

1. In the top menu bar of Godot, click **AssetLib**  
2. Click the **Import** button in the top-right of the main display area  
3. Select the provided ZIP file  
4. Once the import completes, click the **Plugins** button next to it  
5. In the list of installed addons, check **ObjId Manager for BFPortal** to enable it  
6. When a new **ObjId** tab appears in the right-hand dock, installation is complete

> 💡 If you suspect the addon is not working correctly,  
> try **disabling it once and re-enabling** it from the plugin list.  
> This usually resolves minor state sync issues.

---

### How to update

1. In the Godot Addons list, uncheck ObjId Manager to disable it.
2. Delete the ObjIdManager folder inside the addons directory.
3. In Godot’s menu bar, click Project → Reload Current Project. (You can also do this after importing the new version.)
4. Place the latest ZIP file in any location you prefer.
5. In the Addons window, click the Import button and select the new ZIP file to import it.
6. Finally, re-enable ObjId Manager in the Addons list.

---

### Usage

- Edit ObjIds directly in the dock — all edits are Undo/Redo-safe  
- Use the **Refresh** button to reload all Node3D objects in the scene  
- Open the **TypeScript Export** dialog to generate TypeScript code for selected nodes  

---

### Compatibility

- Godot 4.4.1 or newer  
- Fully tested within the Battlefield Portal SDK Godot environment  

---

### License

This addon is distributed under the **MIT License**.  
See the accompanying [LICENSE](./LICENSE) file for the full terms.
Copyright (c) 2025 hekaron

---

### Disclaimer

This addon is provided **as-is**, without any guarantees.  
The author is **not responsible for any data loss or project corruption** that may occur from its use.  
Always back up your project before installing or updating addons.

---

---

## 日本語版

### 概要

**ObjId Manager for BFPortal** は、**Godot 4.4+** および  
**Battlefield Portal SDK に同梱されている Godot プロジェクト環境** 向けに設計されたエディタ拡張アドオンです。  
Node3D の `@export var ObjId` を一覧・編集・エクスポートする機能を提供します。

Battlefield Portal のステージ制作やオブジェクト制御を行う制作者が、  
シーン内のオブジェクトIDを一括管理する用途を想定しています。

---

### 主な機能

- Node3D の ObjId 一覧表示（Tree形式）  
- 重複値のハイライト表示  
- 自動連番付与  
- **Undo / Redo 対応**
- TypeScript 形式へのエクスポートダイアログ  
  - チェック順に変換順を維持  
  - 除外カテゴリはグレー表示で非選択化  
  - 「すべてのチェックを外す」「すべてにチェックを付ける」ボタン搭載  

---

### インストール手順

1. Godot の画面上部にある **AssetLib** をクリック  
2. メインの表示エリア右上にある **インポート** ボタンをクリック  
3. 配布された ZIP ファイルを選択  
4. インポートが完了したら、インポートボタンの隣の **プラグイン** ボタンをクリック  
5. インストール済みプラグインのリスト内の  
   **「ObjId Manager for BFPortal」** にチェックを付けて有効化  
6. 右側のドックに **「ObjId」** タブが追加されたらインストール完了です  

> 💡 **アドオンの挙動がおかしい場合**  
> 一度プラグイン一覧で「ObjId Manager for BFPortal」を無効にしてから、  
> 再度有効にしてみてください。  
> 状態リセットで問題が解消する場合があります。

---

### アップデート手順

1. Godotのインストール済みアドオン一覧画面でObjIdManagerを無効化。
2. Godotプロジェクトファイル内のaddonsフォルダからObjIdManagerのフォルダを削除。
3. Godotのメニューバーのプロジェクトから **プロジェクトを再読み込み** を実行する (新しいバージョンのzipをインポートしてからでも良いです)
4. ZIPファイルを任意の場所に配置する。
5. アドオン一覧に戻ってインポートから先程のZIPファイルを選択してインポート。
6. 最後にインストール済みプラグイン一覧からアドオンを有効化する。

### 使い方

- ドック内で ObjId を直接編集可能（Undo/Redo 対応）  
- シーン構造を変更した場合は **更新ボタン** を押して一覧を再取得  
- **TypeScript 出力ボタン** から選択ノードを TypeScript 定義としてエクスポート可能  

---

### 動作環境

- Godot 4.4.1 以上  
- Battlefield Portal SDK の Godot 環境で動作確認済み  

---

### ライセンス

本アドオンは **MITライセンス** で公開されています。  
詳細は同梱の [LICENSE](./LICENSE) ファイルをご確認ください。
Copyright (c) 2025 hekaron

---

### 免責事項

本アドオンは **現状のまま (as-is)** 提供されます。  
使用によって発生した **プロジェクトの破損・データ損失などには一切責任を負いません。**  
導入や更新の前には、必ずプロジェクトのバックアップを取ってください。
