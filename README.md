# Enhanced Flatpak Ubuntu

Bộ script hậu cài đặt dành cho cộng đồng Ubuntu GNOME, tập trung thay thế Snap
bằng Flatpak, thiết lập bộ gõ tiếng Việt và chuẩn bị một desktop gọn gàng hơn.

> [!WARNING]
> `install.sh` sẽ gỡ toàn bộ ứng dụng Snap, `snapd` và dữ liệu Snap cục bộ.
> Hãy đọc phần **Những thay đổi được thực hiện** và sao lưu dữ liệu quan trọng
> trước khi chạy. Đây không phải script chính thức của Ubuntu, Canonical hay
> Flathub.

## Mục lục

- [Tính năng](#tính-năng)
- [Yêu cầu](#yêu-cầu)
- [Cài đặt](#cài-đặt)
- [Những thay đổi được thực hiện](#những-thay-đổi-được-thực-hiện)
- [Khắc phục lỗi độ sáng](#khắc-phục-lỗi-độ-sáng)
- [Khôi phục và xử lý sự cố](#khôi-phục-và-xử-lý-sự-cố)
- [Đóng góp](#đóng-góp)

## Tính năng

- Cập nhật các gói APT hiện có.
- Gỡ Snap và pin `snapd` để hạn chế bị cài lại.
- Cài Flatpak và thêm kho Flathub.
- Cài GNOME Software cùng backend Flatpak và firmware.
- Cài Firefox và Thunderbird từ Flathub khi ứng dụng tồn tại.
- Cài Fcitx5, Unikey và cấu hình tự khởi động.
- Cài một số công cụ desktop phổ biến.
- Dọn gói thừa, cache, thùng rác và journal cũ.
- Có chế độ xem trước thay đổi bằng `--dry-run`.

## Yêu cầu

- Ubuntu sử dụng GNOME và trình quản lý gói APT.
- Tài khoản có quyền `sudo`.
- Kết nối Internet ổn định.
- Nên chạy trên bản cài mới hoặc sau khi đã sao lưu dữ liệu.

Script được thiết kế cho Ubuntu. Khi chạy trên distro khác, script sẽ cảnh báo
nhưng không thể bảo đảm tương thích.

## Cài đặt

Tải repository:

```bash
git clone https://github.com/ngoctanz/ehanced-flatpak-ubuntu.git
cd ehanced-flatpak-ubuntu
```

Nên xem trước các lệnh:

```bash
./install.sh --dry-run
```

Chạy cài đặt:

```bash
./install.sh
```

Tự động xác nhận mọi câu hỏi:

```bash
./install.sh --yes
```

Không chạy `sudo ./install.sh`. Script sẽ tự yêu cầu `sudo` cho từng thao tác
cần quyền quản trị.

Log được lưu tại:

```text
~/ubuntu-post-install-YYYYMMDD-HHMMSS.log
```

Sau khi hoàn tất, hãy reboot để áp dụng đầy đủ thay đổi desktop và bộ gõ.

## Những thay đổi được thực hiện

### APT và Snap

- Chạy `apt-get update` và `apt-get full-upgrade`.
- Gỡ các Snap đang cài, purge `snapd` và xóa dữ liệu tại:
  `/snap`, `/var/snap`, `/var/lib/snapd`, `/var/cache/snapd` và `~/snap`.
- Tạo `/etc/apt/preferences.d/nosnap.pref` với Pin-Priority `-10`.

### Flatpak và ứng dụng

- Cài Flatpak và thêm remote Flathub cho hệ thống.
- Cài GNOME Software cùng các plugin khả dụng.
- Thử cài các Flatpak sau; ứng dụng không tồn tại sẽ được bỏ qua:
  `org.mozilla.firefox` và `org.mozilla.thunderbird_esr`.

### Bộ gõ tiếng Việt

- Cài Fcitx5 và `fcitx5-unikey`.
- Gỡ riêng `ibus-unikey`, không gỡ IBus core của GNOME.
- Tạo launcher Fcitx5 trong `~/.config/autostart`.

Sau khi reboot, mở `fcitx5-configtool` và thêm Unikey nếu chưa xuất hiện.

### Dọn hệ thống

- Chạy `apt-get autoremove --purge`, `autoclean` và `clean`.
- Gỡ Flatpak runtime không còn được sử dụng.
- Xóa thumbnail cache, cache IBus, thùng rác người dùng.
- Chỉ giữ journal trong 7 ngày gần nhất.

Các nhóm chức năng có thể bật hoặc tắt bằng các biến `true`/`false` ở đầu
`install.sh`.

## Khắc phục lỗi độ sáng

Một số laptop không chọn đúng giao diện ACPI backlight sau khi cài Linux.
Chỉ áp dụng workaround này khi thanh điều chỉnh độ sáng không hoạt động.

### 1. Thử tạm thời

Tại menu GRUB:

1. Chọn Ubuntu và nhấn `e`.
2. Tìm dòng bắt đầu bằng `linux`.
3. Thêm `acpi_backlight=native` vào cuối dòng.
4. Nhấn `Ctrl+X` hoặc `F10` để boot.

Thay đổi tạm thời chỉ có hiệu lực cho lần boot đó. Nếu độ sáng hoạt động, áp
dụng lâu dài:

```bash
./fix-backlight.sh
sudo reboot
```

Script tạo file riêng
`/etc/default/grub.d/99-enhanced-gnome-backlight.cfg` rồi chạy `update-grub`.
Ubuntu dùng cơ chế này thay cho lệnh `grubby` thường gặp trên Fedora.

Nếu không hiệu quả, gỡ thay đổi:

```bash
./fix-backlight.sh --remove
sudo reboot
```

`acpi_backlight=native` không giải quyết mọi lỗi độ sáng. Nguyên nhân cũng có
thể đến từ driver GPU, firmware hoặc cách kernel hỗ trợ model laptop cụ thể.

## Khôi phục và xử lý sự cố

- Xem log mới nhất: `ls -t ~/ubuntu-post-install-*.log | head -1`.
- Cài lại Snap nếu cần: `sudo apt install snapd`. Trước đó hãy xóa hoặc chỉnh
  `/etc/apt/preferences.d/nosnap.pref`.
- Flatpak không hiển thị ngay trong GNOME Software: đăng xuất hoặc reboot.
- Fcitx5 chưa hoạt động: chạy `fcitx5-configtool`, kiểm tra Unikey rồi đăng
  nhập lại phiên GNOME.
- Script dừng giữa chừng: đọc lỗi trong log, xử lý nguyên nhân rồi chạy lại.
  Các bước chính được viết để có thể chạy lại an toàn.

## Đóng góp

Issue và pull request đều được chào đón. Khi báo lỗi, vui lòng cung cấp:

- phiên bản Ubuntu và GNOME;
- model máy và GPU nếu lỗi liên quan phần cứng;
- lệnh đã chạy;
- phần log liên quan, đã xóa thông tin nhạy cảm.

Hãy chạy kiểm tra cú pháp trước khi gửi pull request:

```bash
bash -n install.sh fix-backlight.sh
```

Repository hiện chưa công bố giấy phép mã nguồn. Việc xem và đóng góp không
đồng nghĩa với quyền phân phối lại cho đến khi maintainer chọn license.
