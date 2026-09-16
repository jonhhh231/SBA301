# Hạ tầng phát triển — MySQL

`compose.yaml` chỉ khởi tạo MySQL 8.4. Backend/frontend sẽ chạy từ IDE/Vite khi có mã ứng dụng.

1. Tạo `infra/.env` từ `infra/.env.example` và điền `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`.
2. Từ thư mục gốc repository, chạy:

```bash
docker compose --env-file infra/.env -f infra/compose.yaml config --quiet
docker compose --env-file infra/.env -f infra/compose.yaml up -d mysql
docker compose --env-file infra/.env -f infra/compose.yaml ps
```

3. Cấu hình backend bằng biến môi trường tương ứng: `DB_HOST=127.0.0.1`, `DB_PORT` bằng `MYSQL_PORT`, cùng `DB_NAME`, `DB_USER`, `DB_PASSWORD` và `SPRING_PROFILES_ACTIVE=dev`.

Docker image tạo database/user khi volume trống. Charset, collation và timezone đã cấu hình. Không mount V1/V2 vào entrypoint MySQL: Flyway sẽ quản lý migration khi backend được triển khai. Nếu import SQL thủ công để nghiên cứu, không chạy lại các migration đó qua Flyway trên cùng schema.

Dữ liệu được lưu bằng named volume `mysql-data`. Lệnh `docker compose --env-file infra/.env -f infra/compose.yaml down` dừng dịch vụ và giữ volume. Thay `.env` sau khi volume có dữ liệu không tự đổi mật khẩu/user đã tạo.
