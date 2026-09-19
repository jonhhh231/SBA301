# Rà soát Core20: có thể rút gọn tiếp không?

**Chờ người dùng duyệt. Chưa sửa SQL hoặc vẽ sơ đồ mới.**

## Nguồn đúng

Đã đọc toàn bộ `database/exports/PCForge_Core20_Database.txt` (805 dòng), gồm 20 bảng, 4 view và các hợp đồng backend. Bản này là SQL độc lập cho `pcforge_core20`, khác migration V1 của schema 145 bảng. `DRAWIO_README.md` vẫn mô tả sơ đồ 145 bảng nên không dùng làm mô tả Core20.

Đề xuất 50 bảng trước đó lấy sai mốc và đã được rút lại. Nhận xét trước đó về thiếu bảo hành cho phụ kiện không serial chỉ áp dụng schema 145 bảng: **Core20 đã giải quyết bằng `purchased_units.asset_code` và serial tùy chọn**.

## Khuyến nghị: 20 → 18 bảng

### 1. Bỏ bảng carts, liên kết cart_items trực tiếp với users

Hiện `carts.user_id` là UNIQUE, mỗi tài khoản chỉ có một giỏ hiện tại. Bảng carts chỉ chứa id, user_id và thời gian, không có guest cart, nhiều giỏ, trạng thái hoặc voucher riêng.

- Thay `cart_items.cart_id` bằng `user_id`, FK tới users.
- Thay UNIQUE(cart_id, product_id) bằng UNIQUE(user_id, product_id).
- Không có dòng cart_items nghĩa là giỏ rỗng; thêm updated_at trên từng dòng nếu cần.
- Chuyển quy tắc khóa giỏ trong checkout thành khóa dòng users của chủ giỏ. Mọi thao tác sửa giỏ và checkout phải tuân thủ cùng giao thức khóa để tránh thêm/sửa giỏ trong lúc checkout.
- Bỏ timestamp cấp giỏ; nếu cần thời điểm giỏ bị xóa rỗng vẫn phải lưu riêng. Phạm vi hiện tại không dùng dữ liệu đó.

Kết quả: giảm 1 bảng, vẫn giữ giỏ hàng đồng bộ theo tài khoản như Core20.

### 2. Gộp product_specs vào products

Hiện `product_specs.product_id` vừa là PK vừa là FK: mỗi sản phẩm có tối đa một bản thông số. Không có phiên bản hay nhiều bộ thông số độc lập.

- Chuyển component_type, socket_code, memory_type, capacity_gb, form_factor, max_power_draw_w, psu_capacity_w, length_mm, specifications_json sang products.
- Đổi tên metadata thành spec_schema_version, spec_source_url, spec_verified_at để rõ nghĩa.
- Giữ cột thông số có kiểu và các index lọc/tương thích; không chuyển toàn bộ thông số thành văn bản hoặc JSON.
- Sản phẩm không có bộ thông số có thể để cả nhóm NULL. CHECK phải phân biệt không có bộ thông số với có bộ thông số: khi có component_type thì JSON phải là OBJECT và schema_version > 0, đều NOT NULL theo điều kiện. Tránh để CHECK đi qua do kết quả UNKNOWN khi NULL.
- Giữ các giới hạn số dương và quy tắc nguồn xác minh. Backend tiếp tục kiểm tra loại linh kiện theo danh mục, schema JSON và dữ liệu AI.
- Các truy vấn catalog nên chọn cột cần dùng, tránh tải JSON lớn khi chỉ hiển thị danh sách.

Kết quả: giảm 1 bảng, vẫn giữ đầy đủ dữ liệu kiểm tra AI Build. Đánh đổi là products rộng hơn, nhiều cột NULL tùy loại hàng. Ít bảng hơn không tự động có nghĩa hiệu năng tốt hơn.

## Danh sách 18 bảng sau khi gộp

| # | Bảng | Vai trò |
| --- | --- | --- |
| 1 | users | Tài khoản và vai trò |
| 2 | user_addresses | Nhiều địa chỉ của khách |
| 3 | categories | Danh mục linh kiện/phụ kiện |
| 4 | brands | Thương hiệu |
| 5 | products | SKU, giá, tồn, chính sách bảo hành và thông số được gộp |
| 6 | product_images | Nhiều ảnh sản phẩm |
| 7 | promotions | Chương trình tặng quà theo ngưỡng |
| 8 | promotion_gifts | Một hoặc nhiều món quà của chương trình |
| 9 | cart_items | Giỏ theo user_id trực tiếp |
| 10 | orders | Đơn và snapshot địa chỉ/khuyến mãi |
| 11 | order_items | Dòng hàng mua/quà, giá và chính sách chốt khi bán |
| 12 | payments | Các lần thanh toán và hoàn toàn bộ giao dịch |
| 13 | pc_builds | Ngân sách, nhu cầu, kết quả AI và kiểm tra |
| 14 | pc_build_items | Linh kiện, số lượng, giá tham khảo của build |
| 15 | purchased_units | Từng món đã giao, serial/mã nội bộ, thời hạn bảo hành |
| 16 | service_requests | Phiếu bảo hành/bảo trì của từng món |
| 17 | service_request_history | Lịch sử xử lý và người thực hiện |
| 18 | reviews | Đánh giá của người mua |

## Có thể xuống 17 hay ít hơn không?

**17 bảng:** gộp product_images thành images_json trong products, gồm url, alt_text, sort_order. Vẫn có nhiều ảnh nhưng không còn bản ghi ảnh độc lập; backend validate từng phần tử, cập nhật cả danh sách và dùng products.version chống ghi đè đồng thời. Phù hợp nếu mỗi SKU chỉ có bộ ảnh nhỏ. Đây là lựa chọn có đánh đổi, không bắt buộc.

**16 bảng:** từ bản 17, có thể bỏ promotion_gifts và đưa gift_product_id/gift_quantity lên promotions nếu chấp nhận mỗi chương trình chỉ tặng đúng một loại SKU. Vẫn có FK tới products, nhưng mất khả năng cùng chương trình tặng cả chuột lẫn bàn phím. Không khuyến nghị tự áp giới hạn này vì người dùng chưa chốt số loại quà.

Không khuyến nghị giảm bằng cách gộp payments vào orders, purchased_units vào order_items, lịch sử dịch vụ vào một ghi chú, hoặc danh sách linh kiện build vào JSON: sẽ làm mất/khó quản lý nhiều lần thanh toán, nhiều món cùng SKU, lịch sử nhiều lần bảo trì và quan hệ sản phẩm.

## Chức năng và giới hạn kế thừa Core20

- Có phụ kiện: categories và products.
- Tặng quà theo ngưỡng: promotions, promotion_gifts và order_items.is_gift; quà vẫn trừ tồn.
- AI build theo tiền: pc_builds, pc_build_items và thông số trong products; backend kiểm tra giá/tồn/tương thích, link lấy từ catalog.
- Bảo hành/bảo trì từng món: purchased_units, service_requests, service_request_history; có cả phụ kiện không serial, báo phí và chấp thuận.

Phải hiểu đúng chữ “đầy đủ”: Core20 hiện là phạm vi bán hàng gọn của đồ án, chưa bao gồm mọi chức năng thương mại điện tử. Giới hạn đã có trong file gốc: một kho, một SKU mỗi products, giỏ/đơn yêu cầu tài khoản, một chương trình quà mỗi đơn, COD/VNPay, hoàn toàn bộ giao dịch, không đổi trả/hoàn một phần, không sổ nhập xuất/giá vốn, chưa có workflow đổi serial bảo hành hoặc lịch bảo trì định kỳ tự sinh. Các hạn chế này không phải do bước 20 → 18 mới tạo ra.

`appointment_at` hiện là lịch hẹn của phiếu dịch vụ, không phải hệ thống lịch bảo trì định kỳ. Nếu cần nhắc hạn lần bảo trì kế tiếp đơn giản, có thể bổ sung next_maintenance_at trên purchased_units và xử lý bằng job mà không thêm bảng; nhiều lịch hẹn tương lai độc lập cần thiết kế thêm.

## Kết luận duyệt

**Khuyến nghị 18 bảng** vì hai lần gộp phù hợp cardinality hiện có và giữ phạm vi Core20. **17 bảng** cũng khả thi nếu đồng ý lưu bộ ảnh nhỏ bằng JSON. Không có cơ sở gọi một trong hai là số tối thiểu tuyệt đối.

Sau khi chốt, mới cập nhật SQL, ràng buộc, hướng dẫn backend và conceptual diagram/file import draw.io. Workflow dùng Swimlane. Nếu schema đã được import có dữ liệu, cần migration chuyển dữ liệu thay vì chỉ bỏ bảng.
