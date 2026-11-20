# nowplaying-ios

<p align="center">
  <img src="App/Assets.xcassets/AppIcon.appiconset/IMG_1647.png" width="120" alt="App icon">
</p>

<p align="center">
  Share the track you are listening to as a <code>#NowPlaying</code> post, from Spotify or Apple Music.<br>
  Spotify や Apple Music で再生中の曲を <code>#NowPlaying</code> で投稿するためのアプリです。
</p>

<p align="center">
  <a href="#日本語">日本語</a> · <a href="#english">English</a>
</p>

## Screenshots

**Light mode / ライトモード**

<img width="49%" alt="Screenshot (light mode)" src="https://github.com/user-attachments/assets/1a39f128-9fd5-4a5c-a92b-f509a40c97fd" />
<img width="49%" alt="Screenshot (light mode)" src="https://github.com/user-attachments/assets/27ef47a9-22f8-49b5-b7f7-7159a1c868da" />

**Dark mode / ダークモード**

<img width="49%" alt="Screenshot (dark mode)" src="https://github.com/user-attachments/assets/04e4e85a-36e8-4649-9951-24b4b11a4417" />
<img width="49%" alt="Screenshot (dark mode)" src="https://github.com/user-attachments/assets/b5594f6e-5abe-430a-bd30-f0dcaa4e2af0" />

---

## 日本語

### できること

- Spotify（Web API）/ Apple Music（MediaPlayer）/ Last.fm から、再生中の曲を取得します
- 取得元を「auto」にすると、この端末で実際に再生しているものを優先します
- ジャケット画像と曲の URL は iTunes Search API で探します。先頭の結果をそのまま使うのではなく、曲名・アルバム名・アーティスト名が一致するものを優先します
- ジャケット画像を長押しすると、候補（iTunes / MusicBrainz / YouTube Music / 再生中のサービス）から選び直したり、間違いを GitHub の Issue として報告したりできます。候補を探す順番（優先順位）は設定で並び替えられます
- 投稿文は `{track}` / `{artist}` / `{album}` / `{url}` の置き換えに対応した書式で自由に組み立てられ、プリセットとして切り替えることもできます
- 投稿文はその場で編集でき、X の文字数の目安、取得元や再生状態のバッジ、取得履歴も表示されます
- 共有シートのほか、X（アプリ / API）/ Bluesky / Mastodon / Misskey へ直接投稿できます（詳しくは「投稿先」へ）
- Last.fm 連携（任意）：取得元として使うほか、取得時に Now Playing を送り、投稿時にスクロブルします
- ホーム画面ウィジェット（小 / 中）、コントロールセンター用コントロール（iOS 18 以上）、App Shortcuts（ショートカット / 背面タップ / Siri）に対応しています
- UI は英語 / 日本語に対応しています

### 動作環境

- iOS 17 以上
- Spotify を使う場合は、ご自身の Spotify 開発者アプリ（無料）と refresh token が必要です（「Spotify の設定」参照）
- 署名なしの `.ipa` で配布しています。SideStore や AltStore などでインストールしてください

### インストール

1. [Releases](../../releases) から `NowPlaying.ipa` をダウンロードします
2. SideStore / AltStore でインストールします
3. アプリを開き、設定画面で認証情報を入力します（Spotify を使う場合は Spotify の分も）

### Spotify の設定

1. <https://developer.spotify.com/dashboard> でアプリを作成します
2. アプリの設定で、リダイレクト URI に `http://127.0.0.1:8888/callback` を追加します
3. **Users and Access** に、自分の Spotify アカウントを追加します（開発モードのため）
4. 次の URL をブラウザで開き（`YOUR_CLIENT_ID` を置き換え）、ログインして同意します

   ```
   https://accounts.spotify.com/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=http%3A%2F%2F127.0.0.1%3A8888%2Fcallback&scope=user-read-currently-playing%20user-read-playback-state
   ```

5. `http://127.0.0.1:8888/callback?code=...` にリダイレクトされます（ページ自体は表示されませんが、それで正常です）。URL の `code` の値を控えます
6. コードを refresh token に交換します

   ```sh
   curl -X POST https://accounts.spotify.com/api/token \
     -d grant_type=authorization_code \
     -d code=THE_CODE \
     -d redirect_uri=http://127.0.0.1:8888/callback \
     -d client_id=YOUR_CLIENT_ID \
     -d client_secret=YOUR_CLIENT_SECRET
   ```

7. 返ってきた `refresh_token` と、Client ID、Client Secret をアプリの設定画面に入力します

### 設定項目

| 項目 | 選択肢 | 初期値 |
| --- | --- | --- |
| 取得元 | Auto（この端末を優先）/ Spotify / Apple Music / Last.fm | Auto |
| URL | 付けない / 空格区切り / 改行 | 付けない |
| ジャケット画像 | オン / オフ、通常 / 高画質（1200px） | オン、通常 |
| 書式 | `{track}` `{artist}` `{album}` `{url}` を使ったテンプレート | `#NowPlaying {track} - {artist} ({album})` |

書式に `{url}` が含まれている場合は、URL の設定は無視されます。

### 投稿先

iOS の共有シートに加えて、次のサービスへ直接投稿できます（認証情報は設定画面で入力、すべて任意です）。

- **X（アプリ）**：X アプリの投稿画面に本文を引き渡します（画像は付きません）
- **X（API）**：X API 経由で本文と画像を直接投稿します。<https://developer.x.com> でアプリを作成し、権限を **Read and Write** に変更したうえでアクセストークンを発行し、API Key / API Secret / Access Token / Access Token Secret を入力してください
- **Bluesky**：ハンドルとアプリパスワード（Bluesky の設定 → プライバシーとセキュリティ → アプリパスワード）を使います。「サーバー」欄でカスタム PDS にも対応します
- **Mastodon**：インスタンスのホスト名とアクセストークン（設定 → 開発 → 新規アプリ、スコープは `write:statuses` と `write:media`）を使います
- **Misskey**：インスタンスのホスト名と API トークン（設定 → API）を使います

### ソースからビルド

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成します。

```sh
brew install xcodegen
xcodegen generate
xcodebuild build -scheme NowPlaying -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO
```

`v*` のタグを push すると GitHub Actions でビルドが走り、`NowPlaying.ipa` が GitHub Release に添付されます。

### 参考

機能面では geckour 氏の NowPlaying4Droid（Android）を参考にしました。同プロジェクトは GPLv3 ですが、コードは流用しておらず、本アプリは独立した実装です。

### ライセンス

MIT

---

## English

### Features

- Fetches the currently playing track from **Spotify** (Web API), **Apple Music** (MediaPlayer), or **Last.fm**
- **Auto** source: prefers what is actually playing on this device
- Album artwork and track URL are resolved through the iTunes Search API, preferring an exact track + album + artist match instead of blindly taking the first result
- Long-press the artwork to pick a different candidate (iTunes, MusicBrainz, YouTube Music, or the source service's own artwork), or to report a wrong pick as a prefilled GitHub issue. The priority order between sources is configurable in Settings
- Custom post format with `{track}` / `{artist}` / `{album}` / `{url}` placeholders, plus switchable format presets
- Editable post text with an approximate X character count, source / playing-state badges, and a fetch history
- Direct posting to X (app or API), Bluesky, Mastodon, and Misskey — see “Posting destinations”
- Optional Last.fm integration: use it as a fetch source, send Now Playing on fetch, and scrobble when you post
- Home Screen widget (small / medium) with a refresh button, a Control Center control (iOS 18+), and App Shortcuts (Shortcuts / Back Tap / Siri)
- English / Japanese UI

### Requirements

- iOS 17+
- For Spotify: your own Spotify Developer app (free) and a refresh token — see “Spotify setup”
- The app is distributed as an unsigned `.ipa`; install it with SideStore, AltStore, or a similar tool

### Install

1. Download `NowPlaying.ipa` from [Releases](../../releases).
2. Install it with SideStore / AltStore.
3. Open the app, go to Settings, and fill in your credentials (including Spotify, if you use it).

### Spotify setup

1. Create an app at <https://developer.spotify.com/dashboard>.
2. In the app settings, add the redirect URI: `http://127.0.0.1:8888/callback`
3. Add your Spotify account under **Users and Access** (development mode).
4. Open the following URL in a browser (replace `YOUR_CLIENT_ID`), sign in, and agree:

   ```
   https://accounts.spotify.com/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=http%3A%2F%2F127.0.0.1%3A8888%2Fcallback&scope=user-read-currently-playing%20user-read-playback-state
   ```

5. The browser redirects to `http://127.0.0.1:8888/callback?code=...` (the page itself will not load — that is expected). Copy the `code` value.
6. Exchange the code for a refresh token:

   ```sh
   curl -X POST https://accounts.spotify.com/api/token \
     -d grant_type=authorization_code \
     -d code=THE_CODE \
     -d redirect_uri=http://127.0.0.1:8888/callback \
     -d client_id=YOUR_CLIENT_ID \
     -d client_secret=YOUR_CLIENT_SECRET
   ```

7. Paste the returned `refresh_token`, the Client ID, and the Client Secret into the app's Settings.

### Settings

| Key | Values | Default |
| --- | --- | --- |
| Source | Auto (this device first) / Spotify / Apple Music / Last.fm | Auto |
| URL | Off / Space-separated / New line | Off |
| Artwork | On / Off, Standard / High (1200px) | On, Standard |
| Format | Template with `{track}` `{artist}` `{album}` `{url}` | `#NowPlaying {track} - {artist} ({album})` |

If the format contains `{url}`, the URL setting is ignored.

### Posting destinations

Besides the iOS share sheet, the app can post directly (credentials are entered in Settings; all optional):

- **X (app)**: opens the X app's compose screen with the text (no image attachment).
- **X (API)**: posts text and artwork directly through the X API. Create an app at <https://developer.x.com>, set its permissions to **Read and Write**, and generate an access token for your account *after* that change. Fill in API Key / API Secret / Access Token / Access Token Secret.
- **Bluesky**: handle + an app password (Bluesky Settings → Privacy and Security → App Passwords). Custom PDS hosts are supported via the Server field.
- **Mastodon**: instance host + an access token (Preferences → Development → New application, scopes `write:statuses` and `write:media`).
- **Misskey**: instance host + an API token (Settings → API).

### Build from source

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
xcodebuild build -scheme NowPlaying -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO
```

Pushing a tag like `v*` builds the app on GitHub Actions and attaches `NowPlaying.ipa` to the GitHub Release.

### References

The feature set was inspired by geckour's NowPlaying4Droid (Android). That project is GPLv3; no code from it is used here — this app is an independent implementation.

### License

MIT
