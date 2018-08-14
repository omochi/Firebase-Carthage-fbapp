# これは何

FirebaseのプロジェクトをCarthage(+手動ビルド構築)で構築したサンプルです。

# 動かし方

1. git submoduleをチェックアウトする。
2. carthage buildをしてFirebaseのライブラリをDLする。
    (fbappcoreのビルドに入ったらCtrl-Cで中断して良いです)
3. GoogleService-Info.plist を取り替える。

# ビルド構成

- fbappcore (https://github.com/omochi/Firebase-Carthage-fbappcore)
  
  アプリから依存しているライブラリのリポジトリ。
  CartfileによるCarthageパッケージ化がされている。
  FirebaseAnaliticsとFirebaseFirestoreへの依存が記述されている。
  
- fbapp (https://github.com/omochi/Firebase-Carthage-fbapp)

  アプリのプロジェクトのリポジトリ。
  作業用のxcworkspaceと、プロジェクトが入っている。
  プロジェクトの中には2つのターゲットが入っている。
  
  - fbapplib
  
    アプリプロジェクト内部のパッケージ。
    fbappcoreに依存している。
  
  - fbapp
  
    アプリ本体。
    fbappcore と fbapplib に依存している。
    
# ソースコード構成

fbappcoreにモデル(`struct Item`)が定義されていて、
static funcで`Query`を返したりしている。

fbapplibにはxib付きのViewControllerが入っていて、上記のモデルを読み書きする。

fbappはAppDelegateで上記のVCを表示している。

# 構築方法

fbappcoreは、プロジェクトとフレームワークを通常通りに作る。
Cartfileを書く。このとき、Firebase関係のパッケージは、全て同じバージョンを `==` で指定する。
詳細はこちら (https://github.com/firebase/firebase-ios-sdk/blob/master/Carthage.md) 。
Cartfileを書いてから `$ carthage build` すると `Carthage/Build/iOS` に Firebase のライブラリがダウンロードされるので、
これをまとめてXcodeのfbappcoreターゲットのLinked Frameworks and Librariesにドラッグアンドドロップする。
ダウンロードされたライブラリが見つかるように、Framework Search Pathsを設定する。(`$(SRCROOT)/../Carthage/Build/iOS`)
Other Linker Flagsに`-ObjC`を設定する。
Enable Bitcodeを`NO`に設定する。
`gRPC.framework/gRPCCertificates.bundle`をバンドルとして追加する。
ビルドすると出てくるエラーをヒントに、システムの`StoreKit.framework`と`libsqlite3.tbd`をLinked Frameworks and Librariesに追加する。
fbappcoreでimportしているパッケージは、どうやら自動でexportされているっぽい。

fbappはリポジトリをまたいだ依存があるのでxcworkspaceで作業する。
はじめに `$ carthage update --no-build --use-submodules` を行って、fbappcoreを取得する。
続けて、 `$ carthage build` を行う。すると、Firebaseのライブラリが落ちてくる。
そのままfbappcoreのコンパイルが始まるがこれはCtrl+Cで中断して良い。

fbapplibは通常通りに作る。Linked Frameworks and Librariesに、同一ワークスペース内別プロジェクトのfbappcore.frameworkを指定する。
実装においては適宜 `import fbappcore` や `import FirebaseFirestore` を記述する。
fbappcoreでimportしているFirebase系のパッケージはこのままで利用可能。
Enable Bitcodeを`NO`に設定する。
間接exportされていないパッケージを使うためには、Framework Search Pathsを設定する。

fbappを通常通りに作る。
Linked Frameworks and LibrariesとEmbedded Binariesにfbapplib.frameworkとfbappcore.frameworkを指定する。
正しく設定できていれば、fbappcore.frameworkについては、LocationがRelative to Build Productsになっていて、
Build PhasesのEmbed Frameworksに設定が作られている。
Enable Bitcodeを`NO`に設定する。
間接exportされていないパッケージを使うためには、Framework Search Pathsを設定する。

# 美味しいところ

Xcodeがうまくやってくれるらしく、Firebaseのstatic libraryはfbappcoreに結合して、
fbapplibやfbappでは組み込みを気にする必要がない。
この例では3ターゲットが組み合わさっているが、2ターゲット構成でも同様だろう。

Framework Search Pathsで `Carthage/Build/iOS` を指定するところだが、
Carthageが依存先パッケージ(fbappcore)ではCarthageディレクトリをルートパッケージ(fbapp)のCarthageディレクトリへの
シンボリックリンクとして構築してくれるので、
実際には単体開発時と依存から取得された時で実相対パスは異なっているが、
fbappcoreから見ると常に同じ相対パスに依存物が展開されていてうまくいく。

fbappcoreはサブモジュールとして展開されているので、
fbappで作業していてfbappcoreを修正した場合、
`Carthage/Checkouts/fbappcore` に入ってコミット、プッシュできる。

Carthageが依存解決してくれるので、fbappcoreに書いてあるFirebaseAnalyticsなどの依存が、
fbappのCartfile.resolvedに展開される。
Firebase関係のバージョンを記述するのはfbappcoreの一箇所なので、組み合わせミスが生じにくい。
(static libraryなのでバイナリは使用されていないが、framework search pathsから
定義を見にいくケースで参照される)

# 気づいたこと

Firebaseのcarthage向けバイナリはすべてstatic libraryになっている。
Cocoapods向けの場合は、依存しているBoringSSLやgRPCはすべてdynamicで、
Firebase系だけがstaticだがそれと異なる。

なぜかBitcodeがついていない。

# 厳しいところ

`gRPCCertificates.bundle` は fbappcore のリソースにする必要があった。
これがもし fbapp のリソースだと、gRPCがクラッシュしてしまう。
このクラッシュについての情報があった (https://github.com/grpc/grpc/issues/14503) 。

これはgRPCが内部でリソースバンドルを検索する際、
プロセスのメインバンドルではなく、自身の所属するバンドルを見ているためだろう。
ドキュメントには書いてなかったのでハマった。

FirebaseのライブラリがなぜかBitcodeを設定していないため、
fbappcore, fbapplib, fbappすべてのターゲットで、
Bitcodeを明示的に無効にする必要がある。
Cocoapods向けの構成では有効になっているので謎だ。
これについてはBitcodeがついたものを配布するようにお願いすれば解決する気がする。
issueをたてた。 (https://github.com/firebase/firebase-ios-sdk/issues/1689)

バイナリをダウンロードするために `$ carthage build` を実行する必要があるが、
それによって不要なfbappcoreのコンパイルも開始してしまう。
これはCarthageの問題で、
修正作業を進めているコントリビュータが居る (https://github.com/Carthage/Carthage/pull/2532) 。
これが解決すれば、 `$ carthage update --no-build --use-submodules` だけで良くなり、
無駄な処理も走らなくなるはずだ。
