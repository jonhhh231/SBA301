# Frontend — React

Định hướng **React + TypeScript + Vite**, tổ chức feature-first. Một ứng dụng React có các nhóm trang storefront, account, admin, warehouse và technician; dùng chung các feature thay vì sao chép logic giữa các trang.

```text
src/
├── app/
│   ├── routes/       # Router, nhóm route và kiểm tra quyền ở UI
│   ├── providers/    # Auth, query cache, theme, thông báo
│   ├── layouts/      # Storefront, account, admin/workspace
│   └── styles/       # Styles toàn cục và design tokens
├── pages/            # Ghép các feature thành màn hình
├── features/         # Tính năng nghiệp vụ; đặt file trong feature sở hữu
├── shared/
│   ├── api/          # HTTP client, format lỗi và xử lý phiên chung
│   ├── ui/           # Component nền: button, modal, table, input...
│   ├── hooks/
│   ├── lib/
│   ├── types/
│   └── constants/
└── assets/
```

Khi một feature có code, mở thêm `api/`, `components/`, `hooks/`, `types/` bên trong feature theo nhu cầu. Không tạo sẵn hàng loạt lớp/thư mục rỗng cho từng màn hình.

Hướng phụ thuộc: `app/pages → features → shared`; `shared` không phụ thuộc feature, feature không import page. Feature chỉ công khai những API cần thiết; tránh gọi chéo nội bộ. Test nhỏ đặt cạnh component/hook; kịch bản tích hợp/E2E ở `tests/`.

- Copy `.env.example` thành `.env` khi khởi tạo Vite.
- `VITE_API_BASE_URL=http://localhost:8080/api` khớp context-path backend.
- Không đặt password MySQL, AI key, secret OAuth/thanh toán vào biến `VITE_*`.
- ID BIGINT từ backend dùng string; giá và tương thích hiển thị theo kết quả server.
- Phân quyền UI giúp trải nghiệm; backend luôn kiểm tra quyền truy cập dữ liệu.

Hiện chưa có `package.json`, `index.html`, cấu hình Vite hoặc component React. Đây là khung thư mục, chưa có lệnh chạy frontend.
