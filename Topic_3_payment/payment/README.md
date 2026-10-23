# Tích hợp thanh toán SePay (Flutter + Node.js)

Hướng dẫn cấu hình từ **số tài khoản ngân hàng trong code** → **SePay** → **Webhook** → **Cloudflare Tunnel**, để người khác có thể làm theo và chạy thanh toán thật.

---

## Luồng tổng quan

```text
[Flutter App]  --tạo đơn-->  [Backend localhost:3000]
      |                              ^
      | hiển thị QR VietQR           | Cloudflare Tunnel (HTTPS công khai)
      | (STK + mã đơn DH...)         |
      v                              |
[Khách quét QR / chuyển khoản] --> [Ngân hàng] --> [SePay] --webhook--> Backend
      |                                                      |
      |  polling mỗi 3 giây GET /api/orders/:code            |
      +------------------------------------------------------|
      khi status = paid --> SuccessScreen
```

**Quan trọng:** Tiền vào ngân hàng ≠ app tự dừng. App chỉ dừng khi **SePay gửi webhook** tới backend và backend đổi đơn sang `paid`.

---

## 1. Cấu hình số tài khoản ngân hàng trong code

Số TK trên SePay phải **trùng** với số dùng tạo QR.

### 1.1. Xem STK trên SePay

1. Đăng nhập [https://my.sepay.vn](https://my.sepay.vn)
2. Vào **Ngân hàng** (hoặc xem trên trang Tổng quan)
3. Ghi lại, ví dụ:
   - Ngân hàng: **ACB**
   - Số tài khoản: **31454997**

> Mã ngân hàng dùng trong VietQR là mã ngắn (ACB, MB, VCB, BIDV, …), không phải tên đầy đủ.

### 1.2. Ghi vào Backend `.env`

File: `backend_server/.env` (copy từ `.env.example` nếu chưa có):

```env
PORT=3000
SEPAY_API_KEY=sepay_api_key_test_123456
BANK_ACCOUNT=31454997
BANK_NAME=ACB
ORDER_EXPIRE_MINUTES=5
```

| Biến | Ý nghĩa |
|------|---------|
| `BANK_ACCOUNT` | Số tài khoản nhận tiền (trùng SePay) |
| `BANK_NAME` | Mã ngân hàng VietQR (ACB, MB, …) |
| `SEPAY_API_KEY` | Key xác thực webhook (phải trùng khi cấu hình SePay) |
| `ORDER_EXPIRE_MINUTES` | Hạn thanh toán đơn (phút) |

Backend trả `bankAccount` / `bankName` khi tạo đơn; Flutter dùng để tạo QR.

### 1.3. Bản giả lập Phần 1 (DartPad)

File `lib/part1_main.dart` cũng hardcode STK. Đổi cho khớp:

```dart
final String bankSTK = '31454997';
final String bankName = 'ACB';
```

### 1.4. Đổi STK của người khác

1. Sửa `BANK_ACCOUNT` + `BANK_NAME` trong `.env`
2. Sửa cùng giá trị trong `lib/part1_main.dart` (nếu dùng Part 1)
3. Restart backend: `npm start`
4. Hot restart Flutter

---

## 2. Cài Backend và chạy local

```bash
cd backend_server
npm install
cp .env.example .env   # Windows: copy .env.example .env
# Sửa .env cho đúng STK của bạn
npm start
```

Thấy log dạng:

```text
SePay Webhook Server is running on port: 3000
Bank Account: 31454997 (ACB)
```

API chính:

| Method | Path | Mô tả |
|--------|------|--------|
| POST | `/api/orders` | Tạo đơn `pending`, mã `DH` + 8 ký tự |
| GET | `/api/orders/:orderCode` | Lấy trạng thái đơn (Flutter polling) |
| POST | `/api/webhooks/sepay` | Nhận webhook từ SePay |
| GET | `/api/qr?...` | Proxy ảnh QR (tránh CORS trên Flutter Web) |

---

## 3. Cloudflare Tunnel (bắt buộc cho thanh toán thật)

SePay trên internet **không gọi được** `localhost`. Cần tunnel.

### 3.1. Cài `cloudflared`

- Windows (winget): `winget install Cloudflare.cloudflared`
- Hoặc tải: [cloudflared releases](https://github.com/cloudflare/cloudflared/releases)

### 3.2. Chạy tunnel (terminal riêng, giữ mở)

```bash
cloudflared tunnel --url http://localhost:3000
```

Output sẽ có URL dạng:

```text
https://xxxx-xxxx-xxxx.trycloudflare.com
```

**Ghi lại URL này.** Mỗi lần tắt/mở lại tunnel, URL thường **đổi** → phải cập nhật lại trên SePay.

### 3.3. Kiểm tra tunnel đã tới backend

Mở trình duyệt:

```text
https://<URL-TUNNEL-CỦA-BẠN>/api/orders/TEST
```

Nếu thấy JSON kiểu `{"error":"Không tìm thấy đơn hàng."}` → tunnel OK (404 là đúng vì mã TEST không tồn tại).

Nếu **502 Bad Gateway** → backend chưa chạy hoặc sai cổng.

---

## 4. Cấu hình SePay Webhook (quan trọng nhất)

Có **hai chỗ khác nhau** trên SePay — dễ nhầm:

| Menu | Dùng khi nào |
|------|----------------|
| **Cổng thanh toán → IPN** | Thanh toán qua cổng SePay Payment Gateway |
| **Tích hợp WebHooks** | Tiền vào tài khoản ngân hàng liên kết (VietQR / chuyển khoản) |

Bài này dùng **chuyển khoản QR vào STK** → cấu hình tại **Tích hợp WebHooks**.

### 4.1. Mở trang Webhooks

1. [https://my.sepay.vn](https://my.sepay.vn)
2. Menu **Tích hợp & Thông báo** → **Tích hợp WebHooks**
3. Hoặc mở thẳng: [https://my.sepay.vn/webhooks](https://my.sepay.vn/webhooks)

### 4.2. Thêm / Sửa webhook

Bấm **Thêm webhook** (hoặc **Sửa** webhook có sẵn):

**Tab Cơ bản**

| Trường | Giá trị |
|--------|---------|
| Tên | ví dụ: `xác thực thanh toán` |
| **URL nhận webhook** | `https://<URL-TUNNEL>/api/webhooks/sepay` |
| Loại giao dịch | **Tiền vào** |
| Định dạng | **JSON** |

Ví dụ URL đúng:

```text
https://legendary-susan-appreciation-vacuum.trycloudflare.com/api/webhooks/sepay
```

**Sai thường gặp:** URL tunnel cũ, hoặc path IPN cổng thanh toán (`/api/v1/finance/.../ipn`) — sẽ không vào backend bài này.

**Tab Bảo mật**

| Trường | Giá trị |
|--------|---------|
| Phương thức | **API Key** |
| API Key | trùng `SEPAY_API_KEY` trong `.env` (vd: `sepay_api_key_test_123456`) |

Server kiểm tra header:

```http
Authorization: Apikey sepay_api_key_test_123456
```

**Tab Tài khoản:** chọn tài khoản ngân hàng đã liên kết (hoặc tất cả).

Bấm **Cập nhật** / Lưu.

### 4.3. Kiểm tra webhook đang lỗi

Trên trang Webhooks, nếu thấy **Có lỗi / N lỗi** → SePay đã gửi nhưng URL/auth sai. Mở **Sửa**, sửa URL + API Key, lưu lại.

---

## 5. Chạy Flutter

```bash
# Từ thư mục gốc dự án (payment/)
flutter pub get
flutter run
```

Trên màn hình chính:

1. **Địa chỉ Backend Server URL**
   - Android Emulator: `http://10.0.2.2:3000`
   - Flutter Web / Windows: `http://localhost:3000`
   - (Không cần dán URL tunnel vào Flutter — tunnel chỉ cho **SePay gọi vào** backend)
2. Nhập số tiền → **TẠO ĐƠN & THANH TOÁN (ONLINE)**
3. Quét QR bằng app ngân hàng (nội dung CK chứa mã `DH........`)
4. Đợi vài giây: app polling 3s → khi `paid` → màn hình biên lai

---

## 6. Chính sách đối soát tiền (Backend)

| Trường hợp | Xử lý |
|------------|--------|
| Đủ tiền | `status = paid` |
| Thiếu tiền | giữ `pending`, ghi `notes` thiếu |
| Dư tiền | `paid` + `overpaid = true`, ghi `notes` dư |
| Sai nội dung (không có mã DH…) | bỏ qua, ghi log, vẫn trả `200 {"success":true}` |
| Webhook trùng `id` | idempotent, không xử lý lại |
| Sai API Key | `401` |

---

## 7. Test bằng curl (không cần chuyển tiền thật)

Tạo đơn từ app (lấy mã `DHxxxxxxxx`), rồi:

```powershell
# Đủ tiền
$body = @{ id='tx1'; transferType='in'; transferAmount=50000; content='DHXXXXXXXX thanh toan'; code='DHXXXXXXXX' } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:3000/api/webhooks/sepay -Method POST `
  -ContentType 'application/json' `
  -Headers @{ Authorization = 'Apikey sepay_api_key_test_123456' } `
  -Body $body
```

Các case khác: đổi `transferAmount` (thiếu/dư), đổi `Authorization` (sai key), gửi lại cùng `id` (trùng), bỏ mã DH trong `content` (sai nội dung).

---

## 8. Checklist khi “đã chuyển khoản mà web không dừng”

1. Backend còn chạy? (`npm start` trên cổng 3000)
2. Cloudflare tunnel còn mở? URL còn đúng?
3. SePay → **Tích hợp WebHooks** (không chỉ IPN cổng thanh toán)
4. URL webhook = `https://<tunnel-hiện-tại>/api/webhooks/sepay`
5. API Key trên SePay = `SEPAY_API_KEY` trong `.env`
6. Nội dung chuyển khoản có mã đơn `DH` + 8 ký tự?
7. Log backend có dòng `[Webhook] Nhận request...` không?
   - Không có log → SePay chưa gọi tới (sai URL / tunnel chết)
   - Có log 401 → sai API Key
   - Có log “không tìm thấy mã đơn” → sai nội dung CK

---

## 9. Cấu trúc thư mục

```text
payment/
├── backend_server/
│   ├── .env / .env.example
│   ├── package.json
│   └── server.js
├── lib/
│   ├── main.dart
│   ├── part1_main.dart      # Phần 1 offline / DartPad
│   ├── models/
│   ├── services/
│   └── screens/
├── pubspec.yaml
└── README.md
```

### Phần 1 (offline)

```bash
flutter run lib/part1_main.dart
# hoặc copy part1_main.dart sang https://dartpad.dev
```

Nút **Giả lập khách đã chuyển khoản** → sau 2s → biên lai (không cần SePay).

---

## 10. Tóm tắt lệnh thường dùng

```bash
# Terminal 1 — Backend
cd backend_server
npm start

# Terminal 2 — Tunnel (lấy URL HTTPS)
cloudflared tunnel --url http://localhost:3000

# Terminal 3 — Flutter
cd ..   # về thư mục payment/
flutter run
```

Sau mỗi lần tunnel đổi URL → vào SePay **Tích hợp WebHooks** → sửa URL → **Cập nhật**.
