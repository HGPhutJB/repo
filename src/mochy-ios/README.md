# Mochy iOS

> Bản chuyển Mochy Music sang iOS 12+ (Swift + UIKit). Dựa trên **Mochy Music** của realidkroo
> (https://github.com/realidkroo/mochy-music, GPL-3.0).

Trình nghe nhạc cho iPhone đời cũ: tìm bài từ YouTube Music, phát nền, điều khiển ở màn hình khoá.
Gói cài: `.deb` cho máy jailbreak (rootful, Chimera/Sileo) và `.ipa` chưa ký cho ESign / Sideloadly / AltStore.

- Bundle id: `com.puc.mochyios`
- Hệ điều hành tối thiểu: iOS 12.2 (iPhone 5s trở lên, kiến trúc arm64)
- Giấy phép: GPL-3.0 (xem `LICENSE`)

## Tiến độ

| Mốc | Nội dung | Trạng thái |
|-----|----------|------------|
| 0 | Khung app, tìm kiếm, phát một bài, phát nền, màn hình khoá, build tự động | đang thử |
| 1 | Hàng đợi, thư viện, playlist, tải về, giao diện kiểu Apple Music | chưa |
| 2 | Lời bài hát đồng bộ, equalizer | chưa |
| 3 | Import playlist, Last.fm, các tính năng còn lại | chưa |

## Cách build

Chỉ build được trên macOS có Xcode. Repo này build bằng GitHub Actions (`.github/workflows/mochy-ios.yml`):
mỗi lần có thay đổi trong `src/mochy-ios/` sẽ ra `.deb` (đưa thẳng vào `debs/` của nguồn Sileo) và `.ipa` (thư mục `ipa/`).
Chạy tay trên Mac: `./build.sh` (cần `brew install ldid dpkg`).

## Ghi công

Dự án này đứng trên vai nhiều người, danh sách đầy đủ nằm trong [`NOTICE`](NOTICE):

- Mochy Music (realidkroo), nguồn cảm hứng và là chỗ lấy luồng gọi YouTube Music, thông số client.
- ViviMusic (vivizzz007Z) và Metrolist (Mostafa Alagamy), nền mà Mochy Music xây lên.
- LRCLIB, SimpMusic, LyricsPlus, Better Lyrics API, Monochrome Music, AutoEq: các dịch vụ lời bài hát / âm thanh sẽ dùng ở mốc sau.

Mochy iOS là dự án không chính thức, không liên kết với YouTube, Google hay Apple, và không lưu trữ hay phân phối nhạc.
