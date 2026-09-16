# Backend — Spring Boot

Kiến trúc **modular monolith**: một ứng dụng Spring Boot, một MySQL, chia package theo nghiệp vụ. Package gốc dự kiến `com.pcforge`; lớp Spring Boot chính sau này đặt trực tiếp trong package này để scan các module.

Mỗi module có bốn vùng:

```text
modules/<module>/
├── api/              # REST controller, request/response DTO, validation đầu vào
├── application/      # Use case, transaction, interface truy cập dữ liệu/tích hợp
├── domain/           # Mô hình, quy tắc, chính sách và trạng thái nghiệp vụ
└── infrastructure/   # Persistence JPA, repository adapter, HTTP client, scheduled job
```

`config/` dành cho cấu hình dùng chung của ứng dụng. `common/` chỉ chứa thành phần kỹ thuật thật sự dùng chung, không đưa mọi entity/service vào đây.

- Payment gateway adapter ở `modules/payment/infrastructure/`.
- AI provider adapter ở `modules/pcbuilder/infrastructure/`.
- Đơn vị vận chuyển ở `modules/shipping/infrastructure/`.
- Không gọi repository nội bộ của module khác; phối hợp qua application API hoặc event.
- Điều phối checkout ở application của order, dùng cart/promotion/inventory/payment qua ranh giới module.
- Mọi giá và quyết định tương thích cuối cùng do backend xác minh.

Chi tiết cấu trúc, quyền sở hữu dữ liệu và luồng phụ thuộc: [tài liệu kiến trúc](../docs/architecture/project-structure.md).

## Cấu hình

- `src/main/resources/application.yaml`: cấu hình chung.
- `application-dev.yaml`: URL MySQL cục bộ và origin React mặc định.
- `application-prod.yaml`: yêu cầu URL và origin môi trường triển khai.
- `.env.example`: danh sách biến mẫu cho IDE/shell. Spring Boot không tự nạp file `.env`.
- Migration SQL hiện có nằm trong `src/main/resources/db/migration/` để Flyway sử dụng sau khi thêm dependencies.

Định hướng build: Maven, Java 21 LTS và một phiên bản Spring Boot còn được hỗ trợ tại thời điểm khởi tạo. Hiện chưa có `pom.xml`, Maven wrapper, lớp Java hoặc dependencies ứng dụng vì giai đoạn này chỉ tạo cấu trúc.
