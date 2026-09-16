# PCForge — SBA301

Website thương mại điện tử bán linh kiện/phụ kiện máy tính, **AI Build PC**, khuyến mãi theo quy tắc và bảo hành theo **Serial Number**.

**Stack:** Spring Boot + MySQL 8.4 LTS + React (định hướng TypeScript/Vite).

**Trạng thái:** khung thư mục, cấu hình YAML và tài sản database đã có. Backend/frontend chưa có mã ứng dụng hoặc build manifest, nên chưa chạy được Maven/Vite. MySQL có cấu hình Docker Compose riêng.

## Cấu trúc chính

```text
SBA301/
├── backend/                    # Spring Boot modular monolith
│   └── src/
│       ├── main/
│       │   ├── java/com/pcforge/
│       │   │   ├── config/
│       │   │   ├── common/
│       │   │   └── modules/    # Mỗi nghiệp vụ: api/application/domain/infrastructure
│       │   └── resources/
│       │       ├── application.yaml
│       │       ├── application-dev.yaml
│       │       ├── application-prod.yaml
│       │       └── db/migration/
│       └── test/
├── frontend/                   # React, feature-first
│   ├── public/
│   ├── src/
│   │   ├── app/               # Router, providers, layouts
│   │   ├── pages/             # Storefront, account, admin, kho, kỹ thuật
│   │   ├── features/          # Tính năng nghiệp vụ
│   │   ├── shared/            # UI, API client, hooks, types, utilities
│   │   └── assets/
│   └── tests/
├── database/                   # Bootstrap, ví dụ, bản xuất SQL, công cụ kiểm tra
├── infra/                      # compose.yaml và .env.example cho MySQL
└── docs/                       # Kiến trúc, database, API, UX/UI, nghiệp vụ
```

Git lưu các thư mục chưa có nội dung bằng `.gitkeep`. Cấu trúc đầy đủ và quy tắc đặt file: **[docs/architecture/project-structure.md](docs/architecture/project-structure.md)**.

## Module nghiệp vụ

| Backend module | Phạm vi |
| --- | --- |
| `identity` | Đăng nhập, OAuth, phiên, vai trò và quyền |
| `customer` | Hồ sơ, địa chỉ, nhóm khách hàng |
| `catalog` | Sản phẩm, SKU, thương hiệu, danh mục, thuộc tính |
| `compatibility` | Thông số kỹ thuật, quy tắc và kiểm tra tương thích |
| `pcbuilder` | Ngân sách, nhu cầu, AI, cấu hình, revision, benchmark |
| `promotion` | Điều kiện AND/OR, combo, voucher, quà tặng, hạn mức |
| `inventory` | Nhập hàng, nhà cung cấp, kho, giữ tồn, SN, điều chuyển |
| `cart` | Giỏ hàng và báo giá checkout |
| `order` | Đặt hàng, snapshot, dịch vụ mua cùng, đổi trả |
| `payment` | VNPay/MoMo/thẻ/COD, webhook, hoàn tiền |
| `shipping` | Phí ship, đối tác, kiện hàng, vận đơn |
| `warranty` | Quyền bảo hành, phiếu, sửa chữa, báo giá, đổi SN |
| `engagement` | Đánh giá, bình chọn, yêu thích |
| `content` | Banner, trang nội dung, chính sách |
| `notification` | Thông báo, mẫu tin, các lần gửi |
| `reporting` | Analytics, phễu chuyển đổi và báo cáo |

## Database đã tích hợp

- Migration chuẩn duy nhất: [`backend/src/main/resources/db/migration/`](backend/src/main/resources/db/migration/).
- SQL bootstrap, ví dụ, bản `.txt` và kiểm thử: [`database/`](database/).
- Thiết kế **145 bảng, 267 khóa ngoại, 6 view**: [tài liệu database](docs/database.md).
- Bản `.txt` là bản xuất tham khảo đã có; khi phát triển, thêm migration Flyway mới thay vì sửa các version đã chạy.

## Cấu hình YAML và môi trường

- Backend: `application.yaml` dùng chung; `application-dev.yaml` cho máy phát triển; `application-prod.yaml` cho môi trường triển khai.
- Chọn profile bằng `SPRING_PROFILES_ACTIVE`, không cố định profile dev trong file dùng chung.
- Các file `.env.example` mô tả biến cần thiết; bản `.env` cục bộ đã được ignore.
- **Spring Boot không tự đọc `.env`**: khai báo biến trong IDE, shell hoặc môi trường chạy.
- React/Vite sử dụng `frontend/.env` với biến `VITE_*`, không dùng YAML cho biến frontend. Các biến này là dữ liệu công khai gửi tới trình duyệt.
- Cấu hình `app.cors` mới là hợp đồng cấu hình; backend cần triển khai CORS khi bắt đầu viết ứng dụng.

Hướng dẫn khởi động MySQL: [infra/README.md](infra/README.md).

## Kiểm tra SQL hiện có

Tại `database/tests`:

```bash
npm install --ignore-scripts
npm run check
```

SQL smoke test và cách import thủ công nằm trong [docs/database.md](docs/database.md). Không import V1/V2 thủ công rồi để Flyway chạy lại trên cùng database.
