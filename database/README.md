# Database assets

```text
bootstrap/   # Tạo database khi không dùng Docker image tự khởi tạo
examples/    # SQL minh họa khuyến mãi, cần điền ID thật
exports/     # Bản SQL tổng hợp .txt đã có, dùng tham khảo/import thủ công
tests/       # Parser validation và smoke test MySQL hiện có
```

**Nguồn migration chuẩn:** [`../backend/src/main/resources/db/migration/`](../backend/src/main/resources/db/migration/). Chỉ giữ một bộ migration để tránh lệch dữ liệu giữa backend và database assets.

Ví dụ, smoke test và bản export không nằm trong Flyway location và không tự chạy khi backend khởi động. Bản `.txt` là snapshot của bộ SQL trước khi sắp xếp repo; các tên file trong tiêu đề của bản export mô tả nguồn lúc xuất, không phải đường dẫn repo hiện tại.

Khi đã triển khai database, thêm migration V3, V4... cho thay đổi mới; không sửa V1/V2 đã áp dụng. Tài liệu schema và transaction: [docs/database.md](../docs/database.md).

**Sơ đồ ERD draw.io:** mở [`exports/PCForge_ERD.drawio`](exports/PCForge_ERD.drawio) trong diagrams.net. Hướng dẫn và script tạo lại: [`exports/DRAWIO_README.md`](exports/DRAWIO_README.md).
