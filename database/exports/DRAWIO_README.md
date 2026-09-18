# Sơ đồ database PCForge

## Mở trong draw.io

1. Truy cập https://app.diagrams.net/ (hoặc dùng draw.io Desktop).
2. Chọn **Device** nếu được hỏi nơi lưu.
3. Chọn **File → Open From → Device**, mở `PCForge_ERD.drawio` trong thư mục này.
   Có thể kéo thả file vào draw.io hoặc dùng **File → Import From → Device**.
4. Chọn tab ở cạnh dưới để xem từng nhóm chức năng. Dùng zoom và **View → Outline**
   để di chuyển trên sơ đồ lớn.

File là XML draw.io đầy đủ, có thể chỉnh sửa bảng, cột và đường nối trực tiếp.
Không cần dán vào hộp thoại SQL/Mermaid.

## Nội dung

- **145 bảng, 1.149 cột, 267 ràng buộc khóa ngoại**, gồm khóa ghép và quan hệ tự tham chiếu.
- **13 tab**: `00 - Full ERD`, 11 nhóm chức năng theo schema và `12 - Reporting views`.
- Tab tổng thể có toàn bộ bảng và khóa ngoại. Các tab chức năng hiển thị đầy đủ cột
  của bảng trong nhóm và các bảng cha được tham chiếu trực tiếp.
- Bảng màu xám có nhãn `[REF]` là bảng thuộc nhóm khác; chỉ các khóa ngoại xuất phát
  từ bảng chính trong nhóm được vẽ trên tab chức năng. Xem tab tổng thể để tra tất cả quan hệ.
- 6 view báo cáo có câu SELECT và đường phụ thuộc từ các bảng nguồn.
- Di chuột trên tiêu đề bảng để xem DDL gốc, bao gồm DEFAULT, CHECK, index và UNIQUE ghép.

### Ký hiệu

| Ký hiệu | Ý nghĩa |
| --- | --- |
| PK | Cột thuộc khóa chính; nhiều cột PK trong một bảng tạo thành khóa chính ghép |
| FK | Cột thuộc khóa ngoại |
| UK | Cột thuộc ít nhất một khóa UNIQUE; không có nghĩa cột đó luôn UNIQUE độc lập |
| NN | NOT NULL |
| AI | AUTO_INCREMENT |
| GEN | Cột được tính tự động (GENERATED ALWAYS) |
| `[REF]` | Bảng được tham chiếu từ nhóm chức năng khác |

Đường khóa ngoại nối **bảng cha (được tham chiếu) → bảng con (chứa FK)**,
neo tại cột đầu tiên của khóa. Nhãn đường ghi đủ các cột, kể cả khóa ghép.
Ký hiệu chân quạ biểu diễn `1` hoặc `0..1` ở phía cha theo tính nullable của FK;
phía con là `0..N`, hoặc `0..1` khi FK chứa một khóa PK/UNIQUE của bảng con.
Đây là cardinality theo FK/UNIQUE/NOT NULL; các CHECK và quy tắc nghiệp vụ bổ sung
có thể ràng buộc dữ liệu chặt hơn, xem DDL trong tooltip.
Đường nét đứt trên tab view chỉ là phụ thuộc truy vấn, không phải khóa ngoại.

## Nguồn và tạo lại

Theo `database/README.md`, nguồn schema chuẩn là:

`backend/src/main/resources/db/migration/V1__schema.sql`

Sơ đồ được tạo từ file SQL trong repo, không phải kết quả truy vấn một MySQL đang chạy.
`PCForge_MySQL_Full.txt` là snapshot tham khảo; V2 chứa dữ liệu tham chiếu.

Chạy tại thư mục gốc project, với Python 3 (không cần cài thư viện):

```powershell
python "database/exports/generate_drawio.py"
```

Script ghi lại `PCForge_ERD.drawio` và kiểm tra XML, ID, đầu nối, số bảng,
cột và khóa ngoại so với V1. Các chỉnh sửa thủ công trong file sơ đồ sẽ bị ghi đè
khi chạy lại; hãy lưu bản chỉnh sửa dưới tên khác nếu cần giữ.
Parser được viết cho cú pháp V1 hiện tại; nếu thêm migration thay đổi schema,
cần cập nhật script để áp dụng các thay đổi đó trước khi tạo lại sơ đồ.

Đã kiểm tra cấu trúc XML và tính đầy đủ của sơ đồ bằng script;
chưa kiểm tra hiển thị trực tiếp bằng giao diện draw.io.
