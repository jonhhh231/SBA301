# PCForge — Phương án rút gọn database để duyệt

**Trạng thái: ĐÃ RÚT LẠI — SAI MỐC SO SÁNH.** Đề xuất 50 bảng bên dưới dựa trên schema 145 bảng, chưa xét bản Core20 đã có nên không phù hợp yêu cầu rút gọn tiếp của người dùng. Thay bằng [phương án Core20 xuống 18 bảng](database-core20-simplification.md). Nội dung dưới đây chỉ giữ để ghi nhận đề xuất cũ, không dùng làm thiết kế được duyệt.

## 1. Kết luận rà soát

Nguồn kiểm tra: `backend/src/main/resources/db/migration/V1__schema.sql`, `docs/database.md` và `README.md`.

Thiết kế hiện tại được tài liệu ghi nhận là **145 bảng, 267 khóa ngoại, 6 view**. Schema có nhiều nghiệp vụ nâng cao: nhiều kho, điều chuyển, đặt mua nhà cung cấp, cây điều kiện khuyến mãi, revision build, benchmark, CMS, analytics và outbox. README cho biết project mới có khung ứng dụng và tài sản database. Lần rà soát này phân tích file thiết kế, không kiểm tra dữ liệu trên MySQL đang chạy.

**Đề xuất: 50 bảng**, giảm 95 bảng, khoảng **65,5%**, cho phạm vi bên dưới. Số bảng không phải tiêu chí duy nhất: giữ quan hệ quan trọng, lịch sử giao dịch, SKU, hàng vật lý, thanh toán và hậu mãi riêng biệt.

Điểm cần cải thiện so với schema cũ: `warranty_entitlements.serial_unit_id` và `warranty_claim_items.serial_unit_id` đều bắt buộc. Phụ kiện không có serial vì vậy chưa có đường biểu diễn bảo hành riêng theo món đã bán. Phương án mới dùng mã đơn vị bán nội bộ, serial nhà sản xuất là tùy chọn.

## 2. Phạm vi cần duyệt cùng phương án

- Một cửa hàng, một kho, VND. Không có điều chuyển liên chi nhánh hoặc quy trình đặt mua nhà cung cấp nhiều đợt; vẫn có phiếu nhập hàng và giá vốn.
- Sản phẩm có nhiều SKU: dung lượng, màu sắc, phiên bản khác nhau. Linh kiện và phụ kiện dùng chung danh mục hàng hóa.
- Tài khoản có thể có nhiều vai trò cố định; quyền của vai trò cấu hình trong Spring Security. Đăng ký, đăng nhập, xác thực email, quên mật khẩu, refresh/revoke token được hỗ trợ; OAuth chưa nằm trong bản gọn.
- Giỏ hàng hỗ trợ người dùng hoặc khách. Đặt đơn có thông tin liên hệ và địa chỉ snapshot. Các chức năng lưu build, đánh giá, yêu thích và đặt lịch hậu mãi yêu cầu tài khoản; có thể liên kết đơn khách với tài khoản sau xác minh.
- Một đơn giao toàn bộ hàng, không tách kiện giao từng phần. Cho phép nhiều lần thử giao nhưng chỉ một lần giao thành công; mỗi lần thử là một shipment, không phải một phần đơn.
- Khuyến mãi theo ngưỡng toàn đơn: giảm tiền, giảm phần trăm có trần, miễn phí ship, tặng một hoặc nhiều SKU. Mỗi đơn áp dụng tối đa một chương trình; voucher là cách kích hoạt chương trình, không cộng dồn chương trình khác.
- Có hủy đơn, trả một phần/toàn bộ, hoàn tiền. Đổi hàng khác SKU thực hiện bằng trả hàng và đơn thay thế có liên kết, không ghi đè đơn gốc.
- AI đề xuất PC theo ngân sách/nhu cầu từ SKU cửa hàng, lưu nhiều phương án và cho sửa cấu hình. Không lưu kho benchmark hoặc lịch sử mọi thao tác chỉnh sửa.
- Một phiếu hậu mãi cho một món đã bán; một lần mang nhiều món sẽ tạo nhiều phiếu và có thể chung mã nhóm tiếp nhận. Có bảo hành, bảo trì định kỳ, sửa chữa có phí, linh kiện thay thế và đổi mới sản phẩm.
- Mỗi SKU có một chính sách bảo hành cửa hàng tổng hợp tại một thời điểm; chưa quản lý nhiều hợp đồng bảo hành đồng thời từ hãng, cửa hàng và nhà cung cấp.
- Một báo giá được chấp thuận cho mỗi phiếu dịch vụ. Muốn báo giá thêm sau đó tạo phiếu tiếp nối có liên kết; không sửa giá đã chấp thuận.

Đây là phạm vi web bán hàng hoàn chỉnh ở mức đồ án/cửa hàng đơn, không giữ nguyên toàn bộ tính năng nâng cao của thiết kế 145 bảng.

## 3. Danh sách chính xác 50 bảng dự kiến

Các thuộc tính dưới đây là thuộc tính chính phục vụ duyệt, chưa phải DDL đầy đủ. Bảng có định danh, thời gian tạo/cập nhật và ràng buộc phù hợp khi triển khai.

### A. Tài khoản — 5 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 1 | `users` | Email, mật khẩu hash, tên, điện thoại, trạng thái, xác thực email |
| 2 | `roles` | CUSTOMER, ADMIN, SALES, WAREHOUSE, TECHNICIAN, MARKETING |
| 3 | `user_roles` | Liên kết người dùng–vai trò; khóa duy nhất theo cặp |
| 4 | `auth_tokens` | User, token hash, purpose VERIFY_EMAIL/RESET_PASSWORD/REFRESH, hết hạn, sử dụng, thu hồi; quy tắc vòng đời riêng từng loại |
| 5 | `customer_addresses` | Sổ địa chỉ của khách; chỉ một địa chỉ mặc định mỗi khách |

### B. Hàng hóa và thông số — 8 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 6 | `categories` | Danh mục cha, nhóm COMPONENT/ACCESSORY, loại linh kiện |
| 7 | `brands` | Thương hiệu |
| 8 | `products` | Tên, slug, thương hiệu, danh mục, mô tả, trạng thái |
| 9 | `product_variants` | SKU, product, tên biến thể, giá bán, theo dõi serial, thời hạn/điều khoản bảo hành, chu kỳ bảo trì |
| 10 | `product_media` | Product, SKU tùy chọn, ảnh/video, thứ tự |
| 11 | `spec_definitions` | Category, code, tên, kiểu dữ liệu, đơn vị, bắt buộc, dùng lọc; duy nhất category–code |
| 12 | `variant_spec_values` | SKU, spec, giá trị có kiểu NUMBER/TEXT/BOOLEAN/JSON; duy nhất SKU–spec |
| 13 | `compatibility_overrides` | Hai SKU, rule_code, kết quả, điều kiện BIOS/lắp đặt, nguồn xác minh; hỗ trợ danh sách CPU–mainboard đã kiểm chứng |

Thông số vô hướng dùng cột có kiểu và index; cấu trúc nhiều giá trị như danh sách đầu nguồn/khe cắm dùng JSON có schema validate. Không dùng chuỗi mô tả tự do làm nguồn quyết định tương thích. `spec_definitions` thay cho việc duy trì đồng thời EAV phục vụ lọc và nhiều bộ thông số chuyên biệt. Đánh đổi: nhiều kiểm tra theo loại linh kiện phải thực hiện tại backend.

### C. Nhập hàng và tồn kho — 6 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 14 | `suppliers` | Nhà cung cấp |
| 15 | `goods_receipts` | Nhà cung cấp, người nhập, ngày, trạng thái phiếu |
| 16 | `goods_receipt_items` | Phiếu nhập, SKU, số lượng, giá vốn |
| 17 | `inventory_balances` | SKU, tình trạng SELLABLE/QUARANTINE/DAMAGED, on_hand, reserved, version; duy nhất SKU–tình trạng |
| 18 | `inventory_movements` | Biến động tồn, số lượng có dấu, giá vốn, nguồn phiếu nhập/đơn/trả hàng/dịch vụ, serial tùy chọn, operation_key duy nhất |
| 19 | `serial_units` | SKU, namespace hãng, serial chuẩn hóa, nguồn nhập, trạng thái, BIOS nếu có |

Hàng không serial quản lý số lượng. Hàng serial quản lý từng đơn vị. Một giao dịch phải cập nhật tồn, serial và lịch sử nhất quán. Giá vốn theo bình quân gia quyền cho hàng không serial, giá vốn thực tế cho hàng serial; chốt giá vốn xuất bán để báo cáo không phụ thuộc giá nhập tương lai.

### D. Giỏ hàng, đơn hàng, vận chuyển — 7 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 20 | `carts` | User hoặc guest token hash, trạng thái |
| 21 | `cart_items` | Cart, SKU, số lượng, build_id/group_key tùy chọn |
| 22 | `orders` | Khách, snapshot liên hệ/địa chỉ, trạng thái, tiền hàng/giảm/ship/phí lắp ráp/tổng, expires_at, checkout_key và request_hash, replacement_for_return_id tùy chọn |
| 23 | `order_items` | Order, SKU, số lượng, snapshot tên/giá/giá vốn/chính sách, giảm giá, is_gift, build snapshot/group_key; trạng thái giữ/xuất/giải phóng hàng |
| 24 | `order_item_units` | Order item, unit_no, serial tùy chọn, giao/thu hồi, trạng thái; mã nội bộ cho từng món, kể cả phụ kiện không serial |
| 25 | `order_status_history` | Đơn, miền ORDER/PAYMENT/SHIPPING, từ/đến trạng thái, người xử lý, lý do |
| 26 | `shipments` | Đơn, lần giao, hãng vận chuyển, mã vận đơn, trạng thái, COD, mốc thời gian; lịch sử chi tiết API có thể là snapshot JSON |

Không giữ bảng checkout quote: backend tính lại tại checkout, tạo đơn chờ cùng thời hạn thanh toán. Giữ hàng được biểu diễn trên dòng đơn, có thời hạn chung tại order. Giỏ hàng chưa tạo đơn không giữ hàng. Hàng tặng cũng giữ tồn. Phí lắp ráp là một khoản trên đơn, không phải danh mục nhiều dịch vụ mua kèm.

`order_item_units` tạo đủ số lượng khi chuẩn bị/giao hàng, không xóa khi trả hàng. Mỗi serial chỉ được phân bổ cho một đơn vị bán đang còn hiệu lực; trả hàng đóng phân bổ cũ rồi mới có thể bán lại. Dùng mã nội bộ để bảo hành không đồng nghĩa phụ kiện có serial nhà sản xuất.

### E. Khuyến mãi — 4 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 27 | `promotions` | Tên, thời gian, min_order_amount, phép so sánh GT/GTE, loại giảm tiền/%, trần giảm, miễn ship, hạn mức toàn chương trình/mỗi khách, requires_coupon, trạng thái |
| 28 | `promotion_gifts` | Promotion, SKU quà, số lượng; một chương trình có nhiều quà |
| 29 | `coupons` | Promotion, mã duy nhất, thời hạn, hạn mức, khách được gán tùy chọn |
| 30 | `order_promotions` | Order, promotion, coupon tùy chọn, trạng thái RESERVED/APPLIED/REVERSED/EXPIRED, thời hạn, khách, snapshot điều kiện/quà, giá trị lợi ích; UNIQUE order_id |

Ngưỡng mặc định tính trên tiền hàng phải trả trước giảm của chương trình, không gồm hàng tặng, ship và phí lắp ráp. Mốc tính này phải hiển thị rõ cho khách. Nếu muốn ngưỡng sau voucher hoặc cộng dồn nhiều chương trình, cần mở rộng thiết kế.

Một chương trình có thể vừa giảm giá vừa tặng nhiều món. Ví dụ: từ 20 triệu tặng chuột và lót chuột; từ 30 triệu là chương trình khác. Khách/hệ thống chọn một chương trình hợp lệ, không mặc định cộng cả hai mốc.

Quà là dòng `order_items` giá 0, `is_gift=true`, có giá vốn, giữ/xuất kho và quyền bảo hành riêng nếu chính sách cho phép. Quà hết hàng: chương trình không còn hợp lệ, thông báo để khách chọn lại trước khi xác nhận; không tự bỏ quà đã hứa. Hạn mức tính cả lượt RESERVED chưa hết hạn và APPLIED; khóa promotion/coupon trước khi kiểm tra và tạo lượt để tránh vượt hạn mức.

### F. Thanh toán và hoàn tiền — 3 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 31 | `payments` | Một lần thử thu tiền; thuộc đúng một order hoặc service_ticket; phương thức, số tiền, merchant/provider reference duy nhất, trạng thái, paid_at |
| 32 | `refunds` | Payment thành công, return_request tùy chọn, số tiền, reference duy nhất, trạng thái, lý do |
| 33 | `refund_items` | Refund, order_item/service_ticket hoặc loại SHIPPING/ASSEMBLY, số lượng và số tiền phân bổ |

Một đơn/phiếu dịch vụ có nhiều payment attempts, không ghi đè lần thất bại. Bản gọn dùng thu tiền trực tiếp, không có AUTHORIZE/CAPTURE nhiều bước. Callback xác minh chữ ký, merchant, số tiền, tiền tệ; khóa payment và chuyển trạng thái có điều kiện, callback lặp không ghi nhận thêm tiền hoặc xuất kho lần nữa. Hoàn tiền đang chờ + thành công không vượt số đã thu. Callback tới sau khi hết hạn giữ hàng cần cấp lại tồn trong transaction hoặc đưa vào hoàn tiền.

### G. Trả/đổi hàng — 3 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 34 | `return_requests` | Đơn, người yêu cầu, lý do, trạng thái, REFUND/EXCHANGE |
| 35 | `return_items` | Request, order_item, số lượng, kết quả kiểm tra, tình trạng nhập lại |
| 36 | `return_item_units` | Return item và order_item_unit cụ thể được nhận lại |

Món đã trả không được trả lặp. Khi trả hàng làm mất điều kiện tặng quà, quy trình yêu cầu trả cả quà hoặc áp dụng khoản khấu trừ theo chính sách đã công bố và chốt trên đơn; không trừ theo giá quà hiện tại. Tiền hoàn theo giá sau phân bổ giảm giá trên đơn gốc. Món trả phải kiểm tra rồi mới nhập SELLABLE, nếu chưa kiểm tra thì QUARANTINE.

### H. AI Build PC — 3 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 37 | `build_requests` | User, ngân sách, phạm vi TOWER/FULL_SETUP, nhu cầu, ưu tiên, model, prompt_version, trạng thái/lỗi |
| 38 | `pc_builds` | User, request tùy chọn, nguồn AI/MANUAL, tên, tổng giá đề xuất, giải thích, trạng thái kiểm tra, validation snapshot, mã chia sẻ tùy chọn |
| 39 | `pc_build_items` | Build, SKU, loại linh kiện, số lượng, giá/thông số snapshot, lý do AI chọn |

Một request sinh nhiều build. Gửi yêu cầu mới khi muốn tái sinh để giữ kết quả lần trước. Sửa cấu hình đã chọn: clone build hoặc sửa bản nháp; đơn hàng giữ snapshot riêng nên không bị thay đổi theo build. Có thể lưu chi tiết các lần gọi/retry AI trong log vận hành, không cần bảng quan hệ riêng.

AI nhận danh sách SKU có thật, giá hiện tại, tồn và thông số; trả SKU ID + số lượng + lý do. Backend kiểm tra lại ID, giá, tồn, ngân sách và tương thích trước khi hiển thị kết quả được xác nhận. Link sản phẩm được backend tạo từ product/slug, không dùng link AI tự bịa. Tổng ngân sách phải nói rõ gồm thùng máy hay cả màn hình/phụ kiện; phí ship và lắp ráp hiển thị riêng trong bản gọn.

Rule tương thích cố định có version trong code: socket, danh sách CPU/BIOS hỗ trợ, loại RAM và số thanh/dung lượng, khe SSD, kích thước main/case/GPU/tản, công suất và đầu nguồn, nhu cầu GPU khi CPU không có iGPU. Socket giống nhau chưa đủ kết luận. Thiếu thông số trả UNKNOWN/cần xác minh. Nếu không tìm được cấu hình hợp lệ trong ngân sách, trả NO_SOLUTION và lý do, không tự vượt ngân sách. Thông số chuẩn phục vụ lọc và bộ kiểm tra dùng chung nguồn.

### I. Bảo hành, bảo trì, sửa chữa — 6 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 40 | `warranties` | Order item unit, owner, snapshot điều khoản, bắt đầu/kết thúc, trạng thái, parent_warranty_id khi cấp thay thế |
| 41 | `service_tickets` | Order item unit, warranty tùy chọn, WARRANTY/MAINTENANCE/REPAIR, kỹ thuật viên, lịch hẹn, mô tả, chẩn đoán, báo giá snapshot/tổng/approval, kết quả, trạng thái; previous_ticket_id tùy chọn |
| 42 | `service_events` | Ticket, người thực hiện, STATUS/NOTE/MESSAGE/ATTACHMENT/QUOTE_APPROVAL, thời gian, visibility, nội dung/metadata |
| 43 | `service_parts` | Ticket, SKU, serial tùy chọn, số lượng, giá vốn/giá thu, trạng thái dự kiến/đã dùng/hoàn; xuất kho khi thực dùng |
| 44 | `warranty_replacements` | Ticket, đơn vị bán cũ/mới, serial mới tùy chọn, warranty mới, lý do, thời điểm |
| 45 | `maintenance_schedules` | Order item unit, hạn bảo trì, nội dung, trạng thái, ticket thực hiện tùy chọn, mốc nhắc |

Ngày hết bảo hành không tính lại từ chính sách SKU hiện tại. Chính sách được chốt khi bán, kích hoạt khi giao thành công. Phụ kiện không có serial được tra bằng đơn và mã đơn vị bán. Sản phẩm có thể có nhiều phiếu dịch vụ và nhiều lịch bảo trì theo thời gian, kể cả ngoài hạn bảo hành; không dùng một cột last_maintenance_date thay thế lịch sử.

Đổi bảo hành: tạo order_item_unit thay thế, liên kết nguồn bằng bảng replacements, đóng hiệu lực đơn vị cũ, cấp warranty mới theo thời hạn kế thừa hoặc khởi động lại đã chốt. Đơn vị thay thế gắn dòng đơn gốc để truy nguồn nhưng được đánh dấu REPLACEMENT, không cộng vào số lượng bán/doanh thu ban đầu. Dịch vụ nhiều món dùng nhiều ticket để mỗi món có tiến độ và bảo hành độc lập. Báo giá phải được khách chấp thuận trước khi sửa có phí; chứng cứ chấp thuận ghi ở event và snapshot. Phụ tùng sử dụng liên kết movements để trừ kho thật.

### J. Tương tác và quản trị nội dung — 5 bảng

| # | Bảng | Nội dung chính |
| --- | --- | --- |
| 46 | `reviews` | User, order_item, rating, nội dung, ảnh JSON, một phản hồi chính thức của shop, trạng thái duyệt |
| 47 | `wishlist_items` | User, SKU; một danh sách mặc định cho mỗi khách |
| 48 | `content_entries` | PAGE/BANNER, title, slug, body/image/target_url, vị trí và lịch hiển thị; CHECK theo loại |
| 49 | `notifications` | User, kênh IN_APP/EMAIL, nội dung, đọc/gửi, attempts/next_attempt_at, dedup_key; mỗi kênh một bản ghi |
| 50 | `audit_logs` | Người thao tác, hành động, đối tượng, trước/sau, thời gian; không thay thế ledger tiền/tồn |

Mẫu email quản lý trong code. Notification được ghi cùng transaction nghiệp vụ và worker gửi lại theo trạng thái. Báo cáo doanh thu, tiền thu/hoàn, hàng bán chạy, tồn kho và hậu mãi truy vấn/view từ dữ liệu gốc; không cần bảng report riêng. Doanh thu và tiền thu thực tế phải phân biệt, và không cộng JOIN nhiều bảng con gây nhân bản tiền.

## 4. Các nhóm được rút gọn như thế nào?

| Nhóm hiện tại | Cách rút gọn | Đánh đổi rõ ràng |
| --- | --- | --- |
| `permissions`, `role_permissions`, nhóm khách | Quyền cố định trong backend; giữ roles và user_roles | Chưa có giao diện tạo quyền động/ưu đãi riêng nhóm khách |
| `auth_sessions` và token | Gộp lưu trữ vào auth_tokens theo purpose | Backend phải phân biệt vòng đời và thu hồi từng loại |
| Thuộc tính lọc + hơn 20 bảng thông số/tương thích | Một bộ spec có kiểu và compatibility_overrides | Ít ràng buộc theo loại ở DB, cần validator theo category |
| Warehouses, locations, transfers, purchase_orders | Một kho; nhập hàng trực tiếp và ledger | Không có logistics nhiều kho/đặt mua nhiều đợt |
| Usage profiles, benchmarks, AI runs, revisions, recommendations, alternatives | Ba bảng AI/build, snapshot validation | Không benchmark riêng, không lịch sử chỉnh sửa từng bước |
| Promotion versions, condition tree, actions, targets, counters, reservations, redemptions | Bốn bảng promotion theo ngưỡng và order snapshot | Không rule AND/OR tùy ý, combo nhiều điều kiện hoặc stacking |
| Checkout/shipping quotes và stock_reservations | Tính tại checkout, order pending + order_item giữ tồn | Không cam kết giữ giá/tồn từ lúc chỉ xem giỏ |
| Order addresses, services | Snapshot địa chỉ và phí lắp ráp trên order | Một địa chỉ giao, một khoản lắp ráp trên đơn |
| Shipment items, shipment serial mappings | Giao nguyên đơn; mapping đơn vị bán tại order_item_units | Không giao tách một phần đơn |
| Payment transactions/webhook events | Một payment cho mỗi attempt; provider key duy nhất và xử lý idempotent | Không authorization/capture tách nhiều bước; log webhook đầy đủ ở hệ thống log |
| Warranty policies, claims/items, jobs, messages, attachments, estimates | Policy snapshot, ticket một món, events và parts | Một chính sách tổng hợp, một báo giá chốt mỗi ticket |
| Reviews/media/replies/votes, wishlists | Reviews gọn và wishlist_items trực tiếp theo user | Không vote, không hội thoại phản hồi nhiều cấp, không nhiều wishlist |
| Banners/pages, notification templates/deliveries | Content theo loại; notification theo kênh; template trong code | Không CMS/template engine riêng |
| Analytics sessions/events, outbox, idempotency_keys | Báo cáo dữ liệu nghiệp vụ; notification worker; unique key trên nghiệp vụ | Không analytics hành vi đầy đủ và event bus tổng quát |

Snapshot JSON dùng cho dữ liệu lịch sử hoặc cấu trúc phụ trợ, không thay khóa ngoại của SKU, món đã bán, giao dịch thanh toán, linh kiện build, quà tặng hoặc phiếu dịch vụ.

## 5. Các ràng buộc không được bỏ khi viết SQL/backend

1. Giá, số lượng, thời hạn hợp lệ; tiền dùng DECIMAL/BigDecimal. Tổng đơn = tiền hàng - giảm giá + ship sau giảm + phí lắp ráp. Thuế nếu giá đã gồm thuế thì không cộng lại.
2. Checkout idempotency theo chủ thể + key và request_hash; cùng key khác nội dung phải bị từ chối. Khóa tồn theo thứ tự SKU cố định; tồn khả dụng không âm.
3. Trạng thái giữ hàng trên order_item là nguồn đối chiếu reserved; timeout/hủy/xuất hàng không giải phóng hoặc trừ hàng hai lần. Job hết hạn dùng cùng cơ chế khóa với callback.
4. Snapshot giảm giá phân bổ từng dòng để hoàn một phần chính xác. Quà không làm tăng tiền thu nhưng có giá vốn và làm giảm tồn.
5. SKU của serial, order_item_unit, phiếu dịch vụ và phụ tùng phải nhất quán. Đơn vị thay thế được kiểm tra riêng với nguồn đổi mới, không áp điều kiện SKU cũ nếu chính sách cho đổi model.
6. Phiếu trả chỉ chứa món thuộc đúng đơn, tổng trả không vượt lượng đã giao còn hiệu lực. Hàng đổi bảo hành không tạo thêm quyền trả tiền ngoài số lượng đã mua.
7. Payments thuộc đúng một order hoặc ticket; refunds tham chiếu khoản thu thành công cùng chủ thể; callback không được hạ trạng thái đã thành công về thất bại.
8. Các bộ đếm tổng và quan hệ chéo không được đảm bảo chỉ bằng FK/CHECK; service cần transaction, kiểm tra quyền sở hữu và kiểm tra tổng số lượng/tiền.
9. Chính sách đang chạy không sửa hồi tố trên đơn đã tạo. Đổi chính sách bằng chương trình mới hoặc snapshot mới cho giao dịch mới.
10. Backend thực hiện tìm kiếm/lọc, kiểm tra tương thích, gọi AI và khuyến mãi; có bảng dữ liệu không đồng nghĩa chức năng đã được triển khai.

## 6. Đối chiếu yêu cầu người dùng

| Chức năng | Bảng chính / cách đáp ứng |
| --- | --- |
| Bán linh kiện và phụ kiện | Categories → products → variants; kho, giỏ, đơn, thanh toán, giao hàng |
| Mua trên ngưỡng tặng đồ | Promotions + promotion_gifts; quà là order_item thật, giá 0, có tồn |
| AI đề xuất PC theo số tiền | Build_requests → pc_builds → pc_build_items; SKU/giá thật và kiểm tra tương thích |
| Bảo hành từng sản phẩm | Order_item_units → warranties → service_tickets; hỗ trợ có/không serial |
| Bảo trì từng sản phẩm | Maintenance_schedules + service_tickets/events/parts; nhắc lịch và thu phí khi có |
| Chức năng web bán hàng cơ bản | Tài khoản, phân quyền, danh mục/lọc, biến thể, giỏ, đơn, COD/online, giao hàng, trả/hoàn, đánh giá, yêu thích, nội dung, thông báo, quản trị và báo cáo |

## 7. Có thể ít hơn 50 bảng không?

Có, nhưng phải tiếp tục thu hẹp phạm vi: bỏ nhiều vai trò, biến thể, trả hàng từng món, đối soát hoàn tiền theo dòng, lịch bảo trì hoặc lịch sử xuất nhập. Không khuyến nghị ép xuống khoảng 20–25 bảng chỉ bằng nhét các quan hệ này vào JSON hoặc một bảng quá nhiều trách nhiệm.

**50 bảng là phương án cân bằng đề nghị duyệt, không phải số tối thiểu tuyệt đối.** Conceptual diagram sau khi duyệt sẽ thể hiện thực thể và cardinality theo nghiệp vụ, có trang tổng quan và trang chi tiết để đọc được; không cần ép toàn bộ chi tiết vật lý vào một trang.

## 8. Sau khi được duyệt

1. Chốt phương án và các giới hạn ở mục 2; xác nhận có DB đã chạy/dữ liệu cần giữ trước khi lập migration.
2. Viết schema rút gọn, dữ liệu nền, cập nhật tài liệu và kiểm tra ràng buộc. Nếu đã có dữ liệu thật, lập migration chuyển đổi thay vì thay V1 tùy tiện.
3. Tạo conceptual database diagram hoàn chỉnh và file `.drawio` mở trực tiếp được bằng diagrams.net. Các sơ đồ quy trình sẽ dùng Swimlane theo yêu cầu.

Câu hỏi duyệt: **Bạn đồng ý phương án 50 bảng với một kho, một chương trình khuyến mãi mỗi đơn, giao nguyên đơn và hậu mãi theo từng món chứ?** Nếu khác, cần điều chỉnh phạm vi trước khi viết schema và vẽ.
