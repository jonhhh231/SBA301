# Kiến trúc và quy ước cấu trúc PCForge

## 1. Lựa chọn kiến trúc

**Monorepo + Spring Boot modular monolith + React feature-first + MySQL.**

Phù hợp dự án SBA301: một backend triển khai và một database giúp transaction đơn hàng/kho/khuyến mãi nhất quán. Package theo nghiệp vụ giúp chia công việc theo thành viên và giữ khả năng mở rộng. Chưa cần microservices, message broker hay tách nhiều Maven module.

Repo gốc là `SBA301/` có remote GitHub; `Project/` là thư mục bao ngoài. Tất cả lệnh Git của dự án thực hiện trong repo `SBA301`.

## 2. Backend

```text
backend/
├── .env.example
├── README.md
└── src/
    ├── main/
    │   ├── java/com/pcforge/
    │   │   ├── config/
    │   │   ├── common/
    │   │   │   ├── exception/
    │   │   │   ├── security/
    │   │   │   ├── persistence/
    │   │   │   ├── event/
    │   │   │   ├── idempotency/
    │   │   │   └── audit/
    │   │   └── modules/
    │   │       ├── identity/
    │   │       ├── customer/
    │   │       ├── catalog/
    │   │       ├── compatibility/
    │   │       ├── pcbuilder/
    │   │       ├── promotion/
    │   │       ├── inventory/
    │   │       ├── cart/
    │   │       ├── order/
    │   │       ├── payment/
    │   │       ├── shipping/
    │   │       ├── warranty/
    │   │       ├── engagement/
    │   │       ├── content/
    │   │       ├── notification/
    │   │       └── reporting/
    │   └── resources/
    │       ├── application.yaml
    │       ├── application-dev.yaml
    │       ├── application-prod.yaml
    │       └── db/migration/
    │           ├── V1__schema.sql
    │           └── V2__reference_data.sql
    └── test/
        ├── java/com/pcforge/
        │   ├── architecture/
        │   ├── integration/
        │   └── modules/
        └── resources/fixtures/
```

**Mỗi module đã có bốn thư mục:** `api/`, `application/`, `domain/`, `infrastructure/`.

| Vùng | Trách nhiệm khi viết code |
| --- | --- |
| `api` | Controller, request/response DTO, mapping API, validation hình thức |
| `application` | Use case, transaction, interface truy cập domain/data/provider |
| `domain` | Mô hình nghiệp vụ, policy, state machine, quy tắc tính toán |
| `infrastructure` | JPA entity/repository adapter, gateway client, implementation các interface, job |

Hướng phụ thuộc: API gọi application; application sử dụng domain và interface do application/domain sở hữu; infrastructure triển khai các interface đó. Domain không phụ thuộc HTTP controller hay SDK nhà cung cấp. Không bắt buộc tách thêm model khi chỉ làm DTO đơn giản; quyết định lúc triển khai theo độ phức tạp.

### Ranh giới dữ liệu

- **Identity** sở hữu users/auth/roles/permissions; **customer** sở hữu địa chỉ và nhóm khách hàng.
- **Catalog** sở hữu product/SKU/thuộc tính; **compatibility** sở hữu typed specs và quy tắc tương thích; **pcbuilder** sở hữu cấu hình, AI run và benchmark.
- **Inventory** sở hữu stock, reservation, serial physical unit, mua hàng và điều chuyển. **Warranty** sở hữu quyền bảo hành/phiếu, không tự sửa tồn ngoài inventory API.
- **Promotion** sở hữu chương trình, coupon, hạn mức và redemption. **Order** sở hữu snapshot ưu đãi/phân bổ của giao dịch đã chốt, yêu cầu promotion tính và giữ quyền lợi qua application API.
- **Cart** sở hữu giỏ và báo giá checkout. **Shipping** sở hữu phương thức/báo giá vận chuyển. **Order** điều phối đặt hàng, dịch vụ mua cùng và đổi trả.
- **Payment** sở hữu tiền thu/hoàn và webhook; **warranty** có thể yêu cầu payment thu tiền báo giá sửa chữa.
- **Engagement** sở hữu review/wishlist; **content** sở hữu CMS/banner; **notification** sở hữu template và delivery; **reporting** sở hữu analytics và query báo cáo.
- **Common** quản lý hạ tầng outbox, idempotency và audit dùng chung. Không để common trở thành nơi chứa mọi business service.

Cross-module phối hợp qua API application hoặc event. Giao dịch cần nguyên tử (đặt đơn, giữ hàng, giữ voucher) vẫn có thể dùng cùng transaction trong modular monolith. HTTP tới AI/cổng thanh toán không nằm trong transaction giữ khóa DB dài.

## 3. Frontend

```text
frontend/
├── .env.example
├── README.md
├── public/images/
├── src/
│   ├── app/
│   │   ├── routes/
│   │   ├── providers/
│   │   ├── layouts/
│   │   └── styles/
│   ├── pages/
│   │   ├── storefront/
│   │   ├── account/
│   │   ├── admin/
│   │   ├── warehouse/
│   │   └── technician/
│   ├── features/
│   │   ├── auth/
│   │   ├── customers/
│   │   ├── catalog/
│   │   ├── pc-builder/
│   │   ├── promotions/
│   │   ├── inventory/
│   │   ├── cart/
│   │   ├── checkout/
│   │   ├── orders/
│   │   ├── payments/
│   │   ├── shipping/
│   │   ├── warranty/
│   │   ├── reviews/
│   │   ├── wishlist/
│   │   ├── content/
│   │   ├── notifications/
│   │   └── reports/
│   ├── shared/
│   │   ├── api/
│   │   ├── ui/
│   │   ├── hooks/
│   │   ├── lib/
│   │   ├── types/
│   │   └── constants/
│   └── assets/
│       ├── images/
│       ├── icons/
│       └── fonts/
└── tests/
    ├── integration/
    ├── e2e/
    └── fixtures/
```

`pages` ghép UI và flow; `features` chứa nghiệp vụ/UI tái sử dụng của từng tính năng; `shared` chứa thành phần nền không biết về domain cụ thể. Khi có code, tạo `api/components/hooks/types` bên trong feature đúng nhu cầu, tránh thêm lớp rỗng hàng loạt.

`pc-builder` dùng kết quả compatibility từ server; màn hình quản trị quy tắc có thể dùng cùng feature. Workspace kho/kỹ thuật tái sử dụng features inventory/warranty, không tách thành các ứng dụng độc lập.

`public` dành cho file truy cập nguyên URL; `assets` dành cho file import qua bundler. Không đưa ảnh upload của khách vào Git.

## 4. SQL và tài liệu

- **Flyway:** chỉ dùng `backend/src/main/resources/db/migration/` làm nguồn migration.
- **database/bootstrap:** tạo database cho MySQL cài trực tiếp.
- **database/examples:** câu lệnh minh họa cần chạy có chủ đích.
- **database/exports:** bản `.txt` tổng hợp đã có.
- **database/tests:** giữ công cụ kiểm tra và smoke test từ Git; chỉ cập nhật đường dẫn khi sắp xếp.
- **docs/database.md:** giữ tài liệu database chi tiết từ README trước đây.
- **docs/api:** hợp đồng REST/OpenAPI khi bắt đầu đặc tả.
- **docs/ux-ui:** sitemap, user flow và thiết kế giao diện.
- **docs/business:** SRS, quy tắc ngân sách/khuyến mãi/bảo hành.
- **docs/architecture/decisions:** ghi lại quyết định kiến trúc khi có thay đổi quan trọng.

## 5. Quy ước cấu hình và khởi tạo

- YAML cho Spring Boot và Docker Compose; không có `application.properties`.
- Maven sẽ dùng `pom.xml`; React/Vite sẽ dùng `package.json` và config TypeScript khi khởi tạo ứng dụng, không thay manifest của các công cụ đó bằng YAML.
- Java package dùng chữ thường (`pcbuilder`); thư mục feature frontend dùng kebab-case (`pc-builder`).
- Cấu hình nhạy cảm qua biến môi trường; `.env.example` được commit, `.env` thì không.
- Không mặc định profile production/development trong base YAML; chọn `SPRING_PROFILES_ACTIVE` tại môi trường chạy.
- Gốc API backend `/api`; đường dẫn nghiệp vụ có thể version hóa `/v1/...` khi đặc tả controller.
- Source và cấu hình UTF-8, LF; Java indent 4, YAML/TS/JSON indent 2.
- `.gitkeep` giúp Git lưu thư mục trống; xóa placeholder khi thư mục có file thật.

## 6. Phạm vi scaffold hiện tại

Đã có thư mục, tài liệu, YAML, mẫu biến môi trường và database assets được sắp xếp lại. Không thêm Java/React implementation, dependency ứng dụng hoặc test giả. Cần khởi tạo Maven/Spring Boot và Vite/React ở bước viết ứng dụng để có thể build/run backend/frontend.
