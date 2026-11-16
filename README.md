# MovieSaw Admin — app quản trị (Flutter)

App Android/iOS để quản trị MovieSaw. App chạy trên **admin_dashboard** (Django,
`Thiennhan20/admin_dashboard`) và dùng lại toàn bộ tài khoản admin, phân quyền RBAC,
2FA TOTP, rate limit và audit log có sẵn ở đó.

## Chạy

```bash
flutter pub get
flutter run
flutter build apk          # build/app/outputs/flutter-apk/app-release.apk
```

Lần đầu mở app, nhập địa chỉ server admin (ví dụ `https://admin.example.com`;
nếu chạy Django trên máy và dùng emulator thì nhập `http://10.0.2.2:8000`), sau đó nhập
username và mật khẩu admin, rồi mã 2FA nếu tài khoản đã bật.
Có thể điền sẵn địa chỉ server: `flutter run --dart-define=ADMIN_ORIGIN=https://admin.example.com`.

## Yêu cầu phía server (admin_dashboard)

Repo admin_dashboard có thêm các phần sau:
- model `AdminApiToken` + migration `0005`. Token chỉ lưu dạng hash SHA-256, mặc định hết hạn sau 30 ngày
  (đổi bằng `ADMIN_API_TOKEN_DAYS`).
- middleware `AdminTokenAuthMiddleware`: xác thực `Authorization: Bearer adm_…` cho `/dashboard/api/*`.
  Request dùng token bỏ qua kiểm tra CSRF. Request dùng cookie session vẫn bị kiểm tra CSRF như cũ.
- `users_management/mobile_api.py`: các API JSON `/dashboard/api/m/...`
  (login, me, users, comments, reports, broadcast, settings, servers, admins, audit-logs, error-logs, collections, tokens).
- test: `users_management/test_mobile_api.py`.

Khi deploy: `python manage.py migrate`. Super Admin **bắt buộc bật 2FA trên web**
mới đăng nhập được app.

## Tính năng

| Mục | Nội dung |
|---|---|
| Tổng quan | Số liệu MongoDB, người dùng xác minh/bị cấm, biểu đồ hoạt động 7 ngày, trạng thái API/Mongo/Game server, người dùng mới, bình luận mới, nội dung xem nhiều |
| Người dùng | Tìm theo tên/email/username/ID, lọc theo bị cấm/xác minh/Google/Email, sắp xếp; chi tiết 360° (phiên, bình luận, đang xem, bạn bè); sửa, xác minh email, cấm (có thời hạn), gỡ cấm, thu hồi phiên, xoá cascade |
| Kiểm duyệt | Hàng đợi báo cáo (chờ/đang xem/đã xử lý/bỏ qua): ẩn/xoá/khôi phục bình luận, cấm tác giả; bình luận: tìm, lọc, ẩn/hiện/xoá, chọn nhiều để thao tác hàng loạt |
| Thông báo | Gửi tới tất cả hoặc người dùng cụ thể, kèm Expo push |
| Hệ thống | Server phát phim (ping, quét/chọn domain VidSrc, tự động chọn), cache Upstash (xem/xoá/flush), cấu hình nền tảng (bảo trì, đăng ký...), duyệt mọi collection MongoDB (JSON, xoá) |
| Quản trị | Danh sách admin, tạo admin, đổi vai trò, khoá tài khoản, đăng xuất phiên app (chỉ Super Admin); audit log; error log; quản lý phiên app của chính mình |

Menu và nút thao tác chỉ hiện khi admin có quyền tương ứng. Server luôn kiểm tra lại quyền.

## Patch phía server (admin_dashboard)

App gọi các API `/dashboard/api/m/...` mà repo `Thiennhan20/admin_dashboard` chưa có. Toàn bộ thay đổi
nằm trong [`server_patch/admin_dashboard-mobile-api.patch`](server_patch/admin_dashboard-mobile-api.patch).
Áp dụng bằng lệnh:

```bash
cd admin_dashboard
git apply path/to/admin_app/server_patch/admin_dashboard-mobile-api.patch
python manage.py migrate
python manage.py test users_management
```
