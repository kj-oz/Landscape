Landscape (工事中)
======================
Landscapeは、現在地から見える山や建物の名称、情報をカメラのプレビュー画像上に表示することが出来るiOS端末用のアプリケーションです。

このソースからビルドされるアプリケーションは、Apple社のAppStoreで **風景ナビ** という名称で無料で配信　予定　です。  
　[https://itunes.apple.com/jp/app/XXX][AppStore]

画面イメージや使い方は、以下のページをご覧下さい。  
　[http://XXX.blogspot.jp][Blogger]

### アプリケーションの特徴

* 900強の山岳と、40弱の高層建造物、都道府県庁所在地が登録されています。
* 画面の画角及び見える見えないの判定のしきい値を自分で調整することができます。
* 山岳や建物の見えるかどうかの判定には、国土地理院長の承認 (承認番号 平29情使、 第82号) を得て同院発行の基盤地図情報を元に作成した地盤面標高データを使用し、地球の丸み、光の屈折（上空と地上付近の大気の密度差によって光が若干下向きに進む）を考慮しています。

### ソースコードの特徴

* swift V3 で作成されています。
* コメントは全て日本語です。
* 地盤面標高データは含んでおりませんが、国土地理院のサイトからダウンロードしたデータを本アプリで使用してしている形式に変換するためのスクリプト(dembin.js)を公開しますので、これを利用してご自分で作成してください。（地盤面標高データはなくても動作しますが、中間の地域の標高が全て0とみなされます。）


### 開発環境

* 2017/05/07現在、Mac 0S X 10.12.4、Xcode 8.3.2

### 使用ライブラリ

* 特に無し

動作環境
-----
iOS 10.0以上

ライセンス
-----
 [MIT License][MIT]. の元で公開します。  

-----
Copyright &copy; 2017 Kj Oz  

[AppStore]: https://itunes.apple.com/jp/app/XXX
[Blogger]: http://XXX.blogspot.jp
[MIT]: http://www.opensource.org/licenses/mit-license.php
