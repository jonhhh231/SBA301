# PCForge — Tài liệu cơ sở dữ liệu

PCForge là hệ thống bán linh kiện và phụ kiện máy tính, hỗ trợ **AI Build PC**, khuyến mãi động, quản lý kho và bảo hành theo số serial (SN).

Tài liệu này được tổng hợp từ bộ nguồn `C:\Users\dat\pcforge-database` cho repository **SBA301**. Repository bao gồm toàn bộ SQL, ví dụ khuyến mãi và công cụ kiểm tra.

## 1. Tổng quan

| Thành phần | Thiết kế |
| --- | --- |
| Database | MySQL >= 8.0.16; khuyến nghị MySQL 8.4 LTS |
| Backend dự kiến | Spring Boot, Spring Security, JPA/Hibernate, Flyway |
| Frontend dự kiến | React, giao tiếp với backend qua REST API |
| Quy mô schema | 145 bảng, 267 khóa ngoại, 6 view |
| Storage engine | InnoDB |
| Charset / collation | `utf8mb4` / `utf8mb4_0900_ai_ci` |
| Thời gian | `DATETIME(6)` theo UTC |
| Tiền tệ | `DECIMAL(19,2)`; Java dùng `BigDecimal` |

Schema cung cấp cấu trúc lưu trữ và các ràng buộc nền. Các chức năng AI, tính khuyến mãi, xử lý thanh toán và điều phối nghiệp vụ cần được triển khai tại backend.

## 2. Các nhóm chức năng

| Nhóm | Nội dung |
| --- | --- |
| Tài khoản và phân quyền | Người dùng, định danh đăng nhập, token, phiên đăng nhập, vai trò, quyền, địa chỉ và nhóm khách hàng |
| Danh mục và sản phẩm | Thương hiệu, danh mục phân cấp, sản phẩm, SKU, hình ảnh, thuộc tính lọc, lịch sử giá và sản phẩm liên quan |
| Thông số và tương thích | CPU, mainboard, RAM, GPU, ổ lưu trữ, nguồn, case, tản nhiệt, quạt; socket, khe cắm, đầu nguồn và quy tắc tương thích |
| Nhập hàng và tồn kho | Nhà cung cấp, đơn mua, phiếu nhập, kho, vị trí kho, tồn khả dụng, serial và điều chuyển |
| AI Build PC | Hồ sơ nhu cầu, nguồn benchmark, yêu cầu build, lịch sử chạy AI, cấu hình, revision, kết quả kiểm tra và linh kiện thay thế |
| Khuyến mãi | Phiên bản chương trình, cây điều kiện, hành động, đối tượng áp dụng, coupon, bộ đếm và quy tắc loại trừ |
| Giỏ hàng và đơn hàng | Giỏ hàng, báo giá có hạn, dịch vụ, đơn hàng, snapshot địa chỉ/giá và phân bổ giảm giá |
| Giao hàng và trả hàng | Vận chuyển, kiện hàng, các dòng giao, serial được giao và yêu cầu trả hàng |
| Bảo hành và sửa chữa | Quyền bảo hành theo SN, phiếu bảo hành, công việc sửa chữa, linh kiện sửa, báo giá và đổi mới |
| Thanh toán | Thanh toán đơn hàng/dịch vụ, giao dịch, webhook, hoàn tiền và đối soát |
| Nội dung và phân tích | Đánh giá, danh sách yêu thích, CMS, thông báo và dữ liệu phân tích |
| Báo cáo | Sáu view phục vụ tra cứu tồn kho, đánh giá, đơn hàng, dòng tiền, bán chạy và chuyển đổi |

### Vai trò có trong dữ liệu nền

- `CUSTOMER`: khách hàng; quyền truy cập dựa trên quyền sở hữu dữ liệu.
- `ADMIN`: quản trị viên.
- `SALES`: nhân viên bán hàng.
- `WAREHOUSE`: nhân viên kho.
- `TECHNICIAN`: kỹ thuật viên.
- `MARKETING`: nhân viên marketing.

Dữ liệu nền có các nhóm khách `RETAIL`, `VIP`, `BUSINESS`, thương hiệu, danh mục, thuộc tính lọc, socket, quy tắc tương thích, hồ sơ nhu cầu và đơn vị vận chuyển. Không tạo sẵn tài khoản Admin hoặc mật khẩu mặc định; tạo tài khoản qua Spring Security và hash mật khẩu bằng BCrypt hoặc Argon2.

## 3. Quan hệ nghiệp vụ chính

Sơ đồ dưới đây mô tả luồng nghiệp vụ rút gọn, không thay thế ERD đầy đủ:

```text
products → product_variants → cpu_specs / ram_specs / ...
                           → inventory_balances
                           → serial_units

build_requests → ai_runs → build_recommendations
pc_builds → pc_build_revisions → pc_build_items

promotions → promotion_versions → promotion_condition_groups
                               → promotion_conditions
                               → promotion_actions / promotion_targets / coupons

carts → cart_items
      → checkout_quotes → checkout_quote_items
                       → orders → order_items → order_item_serials
                                → order_promotions → discount_allocations
                                → shipments → shipment_items
                                → payments → payment_transactions → refunds

serial_units → warranty_entitlements
             → warranty_claim_items ← warranty_claims
                        → repair_jobs → repair_parts
                        → warranty_replacements
warranty_claims → repair_estimates → payments
```

### Phân biệt Product, SKU và SN

- **Product**: nội dung sản phẩm.
- **SKU / product variant**: biến thể cụ thể được định giá và quản lý tồn kho.
- **SN / serial unit**: một đơn vị hàng hóa vật lý, dùng để theo dõi giao hàng và bảo hành.
- Một SKU RAM 2 × 16 GB được tính là một bộ, với `modules_per_kit = 2`.

## 4. Bộ file nguồn

```text
SBA301/
├── README.md                       # Tài liệu tổng hợp
├── bootstrap.sql                   # Tạo database pcforge
├── V1__schema.sql                  # Bảng, khóa, CHECK, index và view
├── V2__reference_data.sql          # Dữ liệu tham chiếu
├── PCForge_MySQL_Full.txt           # SQL tổng hợp
├── examples/
│   └── promotion_examples.sql      # Ba khuyến mãi mẫu ở trạng thái DRAFT
└── tests/
    ├── package.json
    ├── validate-schema.cjs         # Kiểm tra tĩnh
    └── smoke.sql                   # Kiểm tra trên MySQL
```

Tải hoặc xem trực tiếp: [bootstrap](bootstrap.sql), [schema V1](V1__schema.sql), [dữ liệu nền V2](V2__reference_data.sql), [SQL tổng hợp](PCForge_MySQL_Full.txt), [ví dụ khuyến mãi](examples/promotion_examples.sql) và [smoke test](tests/smoke.sql).

Trong `PCForge_MySQL_Full.txt`, phần 1–3 chứa bootstrap, schema và dữ liệu nền; phần 4–5 là SQL tùy chọn nằm trong chú thích. Ví dụ khuyến mãi cần được điền ID thật trước khi sử dụng.

## 5. Khởi tạo MySQL

Clone repository rồi mở terminal tại thư mục dự án:

```bash
git clone https://github.com/jonhhh231/SBA301.git
cd SBA301
```

Mở MySQL client:

```bash
mysql --default-character-set=utf8mb4 -u root -p
```

Chạy theo thứ tự trong MySQL console:

```sql
SOURCE bootstrap.sql;
USE pcforge;
SOURCE V1__schema.sql;
SOURCE V2__reference_data.sql;

SHOW TABLES;

SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = 'pcforge'
  AND table_type = 'BASE TABLE';

SELECT * FROM categories ORDER BY parent_id, sort_order;
SELECT * FROM v_sellable_inventory;
```

Với MySQL Workbench: chạy `bootstrap.sql`, chọn schema `pcforge` làm mặc định, rồi chạy V1 và V2.

V1/V2 là migration chạy **một lần trên database trống**. MySQL DDL tự commit; nếu V1 lỗi giữa chừng, cần sửa nguyên nhân rồi tạo lại database thử nghiệm trống. `CREATE DATABASE IF NOT EXISTS` không thay đổi charset/collation của database đã tồn tại.

## 6. Tích hợp Spring Boot

### Dependencies Maven

Dùng dependency management phù hợp với phiên bản Spring Boot của dự án:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-mysql</artifactId>
</dependency>
```

### Migration bằng Flyway

Đây là phương án thay cho import V1/V2 thủ công. Chạy bootstrap trước và đặt hai migration vào:

```text
src/main/resources/db/migration/V1__schema.sql
src/main/resources/db/migration/V2__reference_data.sql
```

Cấu hình `application.yml`:

```yaml
spring:
  datasource:
    url: ${DB_URL:jdbc:mysql://localhost:3306/pcforge?connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true}
    username: ${DB_USER}
    password: ${DB_PASSWORD}
    hikari:
      connection-init-sql: "SET time_zone = '+00:00'"
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        jdbc:
          time_zone: UTC
  flyway:
    enabled: true
    locations: classpath:db/migration
```

Không import V1/V2 thủ công rồi để Flyway chạy lại trên cùng schema. Việc baseline database có sẵn cần có kế hoạch riêng.

### Mapping dữ liệu

| MySQL | Java / JPA |
| --- | --- |
| `BIGINT AUTO_INCREMENT` | `Long`, `@GeneratedValue(strategy = IDENTITY)` |
| `DECIMAL(19,2)` | `BigDecimal`, `@Column(precision = 19, scale = 2)` |
| `DATETIME(6)` | `LocalDateTime` theo UTC |
| `DATE` | `LocalDate` |
| Trạng thái `VARCHAR` | Enum và `@Enumerated(EnumType.STRING)`; cấu hình `@JdbcTypeCode(SqlTypes.VARCHAR)` khi cần với Hibernate 6 |
| `JSON` | DTO / `JsonNode`, Hibernate 6 `@JdbcTypeCode(SqlTypes.JSON)` |
| `BINARY(32)` | `byte[]` chứa SHA-256 hoặc HMAC digest |
| Cột `version` | `@Version Long version` |
| Generated column | `@Column(insertable = false, updatable = false)` |

API nên trả ID `BIGINT` dưới dạng chuỗi để tránh mất chính xác trong JavaScript. Tiền truyền bằng chuỗi decimal hoặc integer VND theo hợp đồng API. React gọi REST API và hiển thị giá/kết quả tương thích do backend xác định.

## 7. Quy tắc nghiệp vụ quan trọng

### Thông số và AI Build PC

- Các bảng thông số chuyên biệt là nguồn chuẩn cho kiểm tra tương thích; dữ liệu filter phải được cập nhật nhất quán trong cùng transaction.
- Thông số `NULL` nghĩa là chưa biết; bộ kiểm tra trả `UNKNOWN`, không tự coi là `PASS`.
- CPU/mainboard phải kiểm tra socket và danh sách hỗ trợ BIOS. Không so sánh phiên bản BIOS theo thứ tự từ điển.
- Kiểm tra nguồn dựa trên tải, đầu cắm, khuyến nghị hãng và dự phòng; không chỉ cộng TDP.
- Revision đã phát hành là bất biến; khóa build khi cấp `revision_no`.
- Build item phân biệt `PURCHASED` (mua mới), `EXISTING` (đồ khách có), `INCLUDED` (đồ đi kèm).
- Không khẳng định FPS thực tế khi chưa có dữ liệu benchmark. Giá, tồn và ưu đãi phải được kiểm tra lại lúc checkout.

### Tiền, thuế và quà tặng

Giá trong schema đã bao gồm thuế; `tax_amount` là phần thuế nằm trong giá.

```text
subtotal        = SUM(order_items.quantity × unit_price)
discount_amount = SUM(order_items.discount_amount)
grand_total     = subtotal - discount_amount
                  + shipping_fee - shipping_discount + service_amount
```

- `service_amount` là tổng giá dịch vụ đã gồm thuế.
- Quà tặng dùng `is_gift = 1`, `unit_price = 0`, vẫn xuất kho và lưu giá vốn.
- VND làm tròn `HALF_UP` về 0 chữ số thập phân theo quy tắc đã chốt; phân bổ phần dư để tổng dòng khớp tổng đơn.
- Hoàn tiền dựa trên số đã trả sau phân bổ giảm giá, không dựa trên giá hiện tại.
- Service phải đối chiếu tổng tiền trong transaction vì `CHECK` không cộng được dữ liệu từ bảng con.

### Khuyến mãi động

- Khi publish, mỗi version cần đúng một nhóm điều kiện gốc, không có chu trình, JSON hợp lệ và selector đúng version.
- `EXCLUSIVE`: chọn lợi ích hợp lệ tốt nhất; `STACKABLE`: tính theo thứ tự xác định; `BEST_OF_GROUP`: chọn ưu đãi tốt nhất trong nhóm.
- Hạn mức/ngân sách trong version áp dụng theo version; giới hạn toàn chương trình cần bộ đếm cấp promotion.
- Khóa counter/coupon bằng `SELECT ... FOR UPDATE` trước khi kiểm tra hạn mức và giữ lượt.
- Tính cả reservation chưa hết hạn và redemption còn hiệu lực khi kiểm tra giới hạn.
- Có job giải phóng reservation hết hạn; hoàn/hủy đơn xử lý trả lượt theo policy snapshot.
- Cấu hình JSON là DSL được validate, không phải mã SQL/JavaScript thực thi tùy ý. Ví dụ SQL cần PromotionEngine tại backend để có hiệu lực nghiệp vụ.

### Checkout và giữ hàng

Trong một `@Transactional`:

1. Claim idempotency key; cùng key nhưng khác request hash phải báo xung đột.
2. Khóa cart/quote, kiểm tra thời hạn, quyền sở hữu, tiền tệ, giá và tương thích.
3. Khóa tồn kho theo thứ tự ID cố định, chỉ chọn hàng `SELLABLE` tại kho hoạt động.
4. Giữ hàng bằng cập nhật có điều kiện, yêu cầu đúng một dòng được cập nhật:

```sql
UPDATE inventory_balances
SET reserved = reserved + :quantity,
    version = version + 1
WHERE id = :balanceId
  AND stock_condition = 'SELLABLE'
  AND on_hand - reserved >= :quantity;
```

5. Ghi reservation hàng và ưu đãi; tạo order cùng snapshot.
6. Đánh dấu quote `CONSUMED`, cart `CONVERTED`, ghi outbox và commit.

Không giữ transaction trong lúc gọi HTTP đến cổng thanh toán. Job hết hạn và callback phải khóa reservation để tránh giải phóng hai lần. Thanh toán đến muộn cần kiểm tra cấp lại hàng hoặc hoàn tiền.

### Kho, giao hàng và bảo hành

- Giữ tồn và phân bổ SN phải cùng SKU, kho và tình trạng; tổng SN phải khớp lượng giao với hàng quản lý serial.
- `uk_active_serial_allocation` ngăn một SN được cấp đồng thời cho hai dòng. Đóng phân bổ cũ bằng `released_at` khi nhận/kiểm tra trả hàng hoặc đổi mới.
- Xuất hàng đồng thời giảm `on_hand`/`reserved`, cập nhật reservation và ghi lịch sử trong cùng transaction.
- Hàng chuyển kho chỉ tăng tồn kho đích khi nhận; dùng `operation_key` chống ghi nhận lặp.
- SN trên quyền bảo hành, dòng giao và phiếu bảo hành phải nhất quán.
- Đổi mới phải khóa SN cũ/mới, xuất kho và cấp quyền bảo hành kế thừa; không gắn quyền bảo hành SN mới vào phân bổ bán SN cũ.
- Sửa chữa có phí cần báo giá đã được khách chấp thuận; tra cứu chi tiết bảo hành cần kiểm tra quyền sở hữu/OTP.

### Thanh toán, trạng thái và dữ liệu chéo

- Xác minh chữ ký webhook, merchant, tiền tệ, số tiền và trạng thái với nhà cung cấp; không tin redirect từ trình duyệt.
- Chỉ `SALE`, `CAPTURE`, `COD_COLLECT` thành công được tính tiền đã thu; `AUTHORIZE` chưa phải thu tiền.
- Refund phải tham chiếu giao dịch thu tiền thành công của cùng payment; tổng refund đang chờ và thành công không vượt tiền đã thu.
- COD cần bằng chứng thu tiền/đối soát. Không lưu PAN/CVV hoặc secret của cổng thanh toán trong metadata.
- Khóa ngoại chỉ đảm bảo bản ghi tồn tại. Service vẫn phải kiểm tra đúng khách hàng, đơn hàng, SKU, version khuyến mãi và tổng số lượng giữa các bảng.
- Chuyển trạng thái cần state machine, kiểm tra quyền, lịch sử và locking phù hợp; giữ bất biến các snapshot đã phát hành.

## 8. View báo cáo

| View | Mục đích |
| --- | --- |
| `v_sellable_inventory` | Tồn có thể cấp tại kho hoạt động |
| `v_product_ratings` | Đánh giá sản phẩm đã duyệt |
| `v_daily_completed_orders` | Giá trị đơn hoàn thành theo ngày Việt Nam, chưa trừ trả hàng về sau |
| `v_daily_cash_flow` | Dòng tiền thu và hoàn thực tế |
| `v_best_selling_variants` | Số lượng và giá trị bán theo SKU trước hoàn hàng |
| `v_daily_session_conversion` | Tỷ lệ phiên có đơn đã xác nhận, nhóm theo ngày bắt đầu phiên |

Dòng tiền không đồng nhất với doanh thu kế toán. Doanh thu thuần và lợi nhuận sau hoàn hàng cần kết hợp refund, lượng hàng nhận lại và giá vốn; tránh join nhiều bảng con rồi cộng trực tiếp gây nhân bản số liệu.

## 9. Kiểm chứng và trạng thái triển khai

Theo tài liệu nguồn, bộ SQL đã được kiểm tra tĩnh bằng `node-sql-parser 5.4.0`:

- 210 câu lệnh parse thành công.
- Hai câu `SET NAMES utf8mb4` được nhận diện riêng vì parser không hỗ trợ cú pháp này.
- Đã kiểm tra thứ tự tạo bảng và sự tồn tại của các cột trong 267 khóa ngoại.

**Bộ SQL chưa được thực thi trực tiếp trên MySQL server tại môi trường tạo file.** Kết quả kiểm tra tĩnh không thay thế kiểm thử DDL, seed và transaction trên MySQL.

Chạy lại kiểm tra tĩnh từ thư mục `tests` của repository:

```bash
npm install --ignore-scripts
npm run check
```

Sau khi nạp V1/V2 vào database thử nghiệm, chạy smoke test trong MySQL:

```sql
SOURCE tests/smoke.sql;
```

Smoke test tạo procedure tạm, chạy fixture trong transaction, `ROLLBACK` và xóa procedure; cần quyền `CREATE ROUTINE`/`EXECUTE`, báo `SQLSTATE 45000` khi lỗi. Chỉ chạy trên database thử nghiệm.

Các tình huống hai checkout mua SKU cuối cùng, callback đồng thời và voucher cuối cùng cần integration test Spring Boot + MySQL/Testcontainers khi có backend.
