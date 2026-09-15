-- Reference data only. No customer, admin password, stock, or fabricated benchmark.
SET NAMES utf8mb4;
SET time_zone = '+00:00';
START TRANSACTION;

INSERT INTO roles (code, name) VALUES
('CUSTOMER', 'Khách hàng'), ('ADMIN', 'Quản trị viên'),
('SALES', 'Nhân viên bán hàng'), ('WAREHOUSE', 'Nhân viên kho'),
('TECHNICIAN', 'Kỹ thuật viên'), ('MARKETING', 'Nhân viên marketing');

INSERT INTO permissions (code, description) VALUES
('catalog.read', 'Xem danh mục và sản phẩm'),
('catalog.write', 'Quản lý sản phẩm và thông số'),
('inventory.read', 'Xem tồn kho và SN'),
('inventory.write', 'Nhập xuất kho và điều chuyển'),
('orders.read', 'Xem đơn hàng'),
('orders.write', 'Xử lý đơn hàng'),
('payments.read', 'Xem thanh toán'),
('refunds.write', 'Thực hiện hoàn tiền'),
('customers.read', 'Xem khách hàng'),
('customers.write', 'Quản lý khách hàng'),
('promotions.read', 'Xem khuyến mãi'),
('promotions.write', 'Tạo và phát hành khuyến mãi'),
('builds.read', 'Xem cấu hình và lịch sử AI'),
('builds.configure', 'Quản lý quy tắc tương thích và hồ sơ nhu cầu'),
('warranty.read', 'Xem phiếu bảo hành'),
('warranty.write', 'Xử lý bảo hành và sửa chữa'),
('reports.read', 'Xem báo cáo'),
('content.write', 'Quản lý nội dung và đánh giá'),
('staff.manage', 'Quản lý nhân viên và phân quyền'),
('audit.read', 'Xem nhật ký quản trị');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'ADMIN';
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'SALES' AND p.code IN
('catalog.read','inventory.read','orders.read','orders.write','payments.read','customers.read','promotions.read','builds.read','warranty.read');
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'WAREHOUSE' AND p.code IN ('catalog.read','inventory.read','inventory.write','orders.read');
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'TECHNICIAN' AND p.code IN ('catalog.read','inventory.read','builds.read','warranty.read','warranty.write');
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'MARKETING' AND p.code IN ('catalog.read','promotions.read','promotions.write','reports.read','content.write');
-- CUSTOMER uses authenticated ownership checks, not global admin permissions.

INSERT INTO customer_groups (code, name) VALUES
('RETAIL','Khách lẻ'), ('VIP','Khách VIP'), ('BUSINESS','Khách doanh nghiệp');

INSERT INTO brands (name, slug) VALUES
('Intel','intel'), ('AMD','amd'), ('ASUS','asus'), ('MSI','msi'),
('Gigabyte','gigabyte'), ('ASRock','asrock'), ('Kingston','kingston'),
('Corsair','corsair'), ('G.Skill','gskill'), ('Samsung','samsung'),
('Western Digital','western-digital'), ('Crucial','crucial'),
('Seasonic','seasonic'), ('Cooler Master','cooler-master'),
('DeepCool','deepcool'), ('Lian Li','lian-li'), ('Logitech','logitech'),
('Razer','razer'), ('LG','lg'), ('Dell','dell');

INSERT INTO categories (name, slug, category_group, component_type, sort_order) VALUES
('Linh kiện máy tính','linh-kien','COMPONENT',NULL,1),
('Phụ kiện máy tính','phu-kien','ACCESSORY',NULL,2);
INSERT INTO categories (parent_id, name, slug, category_group, component_type, sort_order)
SELECT p.id, x.name, x.slug, 'COMPONENT', x.kind, x.pos
FROM categories p CROSS JOIN (
  SELECT 'Bộ vi xử lý CPU' AS name, 'cpu' AS slug, 'CPU' AS kind, 1 AS pos
  UNION ALL SELECT 'Bo mạch chủ','mainboard','MOTHERBOARD',2
  UNION ALL SELECT 'Bộ nhớ RAM','ram','RAM',3
  UNION ALL SELECT 'Card đồ họa','card-do-hoa','GPU',4
  UNION ALL SELECT 'Ổ cứng SSD / HDD','o-cung','STORAGE',5
  UNION ALL SELECT 'Nguồn máy tính','nguon','PSU',6
  UNION ALL SELECT 'Vỏ máy tính','vo-case','CASE',7
  UNION ALL SELECT 'Tản nhiệt CPU','tan-nhiet','COOLER',8
  UNION ALL SELECT 'Quạt case','quat-case','FAN',9
) x WHERE p.slug = 'linh-kien';
INSERT INTO categories (parent_id, name, slug, category_group, component_type, sort_order)
SELECT p.id, x.name, x.slug, 'ACCESSORY', x.kind, x.pos
FROM categories p CROSS JOIN (
  SELECT 'Màn hình' AS name, 'man-hinh' AS slug, 'MONITOR' AS kind, 1 AS pos
  UNION ALL SELECT 'Bàn phím','ban-phim','OTHER',2
  UNION ALL SELECT 'Chuột','chuot','OTHER',3
  UNION ALL SELECT 'Tai nghe','tai-nghe','OTHER',4
  UNION ALL SELECT 'Cáp kết nối','cap-ket-noi','OTHER',5
  UNION ALL SELECT 'Lót chuột','lot-chuot','OTHER',6
) x WHERE p.slug = 'phu-kien';

INSERT INTO attribute_definitions (code, name, data_type, unit) VALUES
('memory_type','Chuẩn RAM','OPTION',NULL),
('ram_capacity_gb','Tổng dung lượng RAM','NUMBER','GB'),
('ram_speed_mts','Tốc độ RAM','NUMBER','MT/s'),
('ram_module_count','Số thanh RAM mỗi bộ','NUMBER','thanh'),
('cpu_socket','Socket CPU','OPTION',NULL),
('cpu_cores','Số nhân CPU','NUMBER','nhân'),
('has_igpu','Có đồ họa tích hợp','BOOLEAN',NULL),
('motherboard_form_factor','Kích thước mainboard','OPTION',NULL),
('has_wifi','Có Wi-Fi','BOOLEAN',NULL),
('vram_gb','Dung lượng VRAM','NUMBER','GB'),
('storage_capacity_gb','Dung lượng ổ cứng','NUMBER','GB'),
('storage_interface','Giao tiếp ổ cứng','OPTION',NULL),
('psu_power_w','Công suất nguồn','NUMBER','W'),
('monitor_refresh_hz','Tần số quét','NUMBER','Hz'),
('monitor_size_inch','Kích thước màn hình','NUMBER','inch'),
('monitor_resolution','Độ phân giải','OPTION',NULL),
('monitor_panel','Tấm nền','OPTION',NULL),
('connection_type','Kết nối','OPTION',NULL);

INSERT INTO attribute_options (attribute_id, value)
SELECT a.id, x.value FROM attribute_definitions a JOIN (
  SELECT 'memory_type' AS code, 'DDR4' AS value
  UNION ALL SELECT 'memory_type','DDR5'
  UNION ALL SELECT 'cpu_socket','LGA1700'
  UNION ALL SELECT 'cpu_socket','LGA1851'
  UNION ALL SELECT 'cpu_socket','AM4'
  UNION ALL SELECT 'cpu_socket','AM5'
  UNION ALL SELECT 'motherboard_form_factor','ATX'
  UNION ALL SELECT 'motherboard_form_factor','MICRO_ATX'
  UNION ALL SELECT 'motherboard_form_factor','MINI_ITX'
  UNION ALL SELECT 'motherboard_form_factor','E_ATX'
  UNION ALL SELECT 'storage_interface','SATA'
  UNION ALL SELECT 'storage_interface','PCIE_NVME'
  UNION ALL SELECT 'monitor_resolution','1920x1080'
  UNION ALL SELECT 'monitor_resolution','2560x1440'
  UNION ALL SELECT 'monitor_resolution','3840x2160'
  UNION ALL SELECT 'monitor_panel','IPS'
  UNION ALL SELECT 'monitor_panel','VA'
  UNION ALL SELECT 'monitor_panel','TN'
  UNION ALL SELECT 'monitor_panel','OLED'
  UNION ALL SELECT 'connection_type','USB'
  UNION ALL SELECT 'connection_type','BLUETOOTH'
  UNION ALL SELECT 'connection_type','WIRELESS_2_4G'
) x ON x.code = a.code;

INSERT INTO category_attributes (category_id, attribute_id, is_required, is_filterable)
SELECT c.id, a.id, TRUE, TRUE
FROM categories c JOIN (
  SELECT 'ram' AS slug, 'memory_type' AS code
  UNION ALL SELECT 'ram','ram_capacity_gb'
  UNION ALL SELECT 'ram','ram_speed_mts'
  UNION ALL SELECT 'ram','ram_module_count'
  UNION ALL SELECT 'cpu','cpu_socket'
  UNION ALL SELECT 'cpu','cpu_cores'
  UNION ALL SELECT 'cpu','has_igpu'
  UNION ALL SELECT 'mainboard','cpu_socket'
  UNION ALL SELECT 'mainboard','memory_type'
  UNION ALL SELECT 'mainboard','motherboard_form_factor'
  UNION ALL SELECT 'mainboard','has_wifi'
  UNION ALL SELECT 'card-do-hoa','vram_gb'
  UNION ALL SELECT 'o-cung','storage_capacity_gb'
  UNION ALL SELECT 'o-cung','storage_interface'
  UNION ALL SELECT 'nguon','psu_power_w'
  UNION ALL SELECT 'man-hinh','monitor_refresh_hz'
  UNION ALL SELECT 'man-hinh','monitor_size_inch'
  UNION ALL SELECT 'man-hinh','monitor_resolution'
  UNION ALL SELECT 'man-hinh','monitor_panel'
  UNION ALL SELECT 'ban-phim','connection_type'
  UNION ALL SELECT 'chuot','connection_type'
  UNION ALL SELECT 'tai-nghe','connection_type'
) x ON c.slug = x.slug
JOIN attribute_definitions a ON a.code = x.code;

INSERT INTO cpu_sockets (code, manufacturer) VALUES
('LGA1700','Intel'), ('LGA1851','Intel'), ('AM4','AMD'), ('AM5','AMD');
INSERT INTO power_connector_types (code, name) VALUES
('ATX_24','ATX 24-pin'), ('EPS_8','EPS CPU 8-pin'),
('EPS_4','EPS CPU 4-pin'), ('PCIE_6','PCIe 6-pin'),
('PCIE_8','PCIe 8-pin'), ('12VHPWR','12VHPWR 16-pin'),
('12V_2X6','12V-2x6 16-pin'), ('SATA_POWER','SATA power'), ('MOLEX_4','Molex 4-pin');

-- Illustrative optimization weights, not benchmark claims.
INSERT INTO usage_profiles (code, name, weights, minimum_requirements) VALUES
('GAMING','Chơi game',JSON_OBJECT('cpu',0.25,'gpu',0.50,'ram',0.15,'storage',0.10),JSON_OBJECT('ram_gb',16,'storage_gb',500)),
('RENDER_3D','Đồ họa 3D',JSON_OBJECT('cpu',0.30,'gpu',0.40,'ram',0.20,'storage',0.10),JSON_OBJECT('ram_gb',32,'storage_gb',1000)),
('OFFICE','Văn phòng',JSON_OBJECT('cpu',0.40,'gpu',0.05,'ram',0.25,'storage',0.30),JSON_OBJECT('ram_gb',8,'storage_gb',250)),
('PROGRAMMING','Lập trình',JSON_OBJECT('cpu',0.45,'gpu',0.05,'ram',0.30,'storage',0.20),JSON_OBJECT('ram_gb',16,'storage_gb',500)),
('VIDEO_EDITING','Dựng phim',JSON_OBJECT('cpu',0.30,'gpu',0.30,'ram',0.20,'storage',0.20),JSON_OBJECT('ram_gb',32,'storage_gb',1000));

INSERT INTO compatibility_rules (code, rule_version, evaluator_key, severity, configuration, description) VALUES
('REQUIRED_COMPONENTS',1,'requiredComponents','ERROR',JSON_OBJECT('required',JSON_ARRAY('CPU','MOTHERBOARD','RAM','STORAGE','PSU','CASE'),'require_cooling_solution',TRUE,'require_display_solution',TRUE),'Đủ các linh kiện và giải pháp tản nhiệt / xuất hình'),
('CPU_SOCKET',1,'cpuSocket','ERROR',JSON_OBJECT(),'CPU và mainboard phải đúng socket'),
('CPU_BIOS_SUPPORT',1,'cpuBiosSupport','ERROR',JSON_OBJECT('unknown_result','UNKNOWN'),'Kiểm tra danh sách CPU hỗ trợ và BIOS tối thiểu'),
('RAM_COMPATIBILITY',1,'ramCompatibility','ERROR',JSON_OBJECT(),'Đúng DDR, module, số khe, dung lượng và khả năng hỗ trợ CPU'),
('CASE_FORM_FACTOR',1,'caseFormFactor','ERROR',JSON_OBJECT(),'Mainboard và PSU phù hợp chuẩn case'),
('GPU_CLEARANCE',1,'gpuClearance','ERROR',JSON_OBJECT(),'GPU vừa không gian lắp đặt thực tế'),
('COOLER_COMPATIBILITY',1,'coolerCompatibility','ERROR',JSON_OBJECT(),'Tản hỗ trợ socket, kích thước và cấu hình lắp'),
('STORAGE_SLOTS',1,'storageSlots','ERROR',JSON_OBJECT(),'Đủ khe, đúng giao tiếp, protocol và kích thước lưu trữ'),
('LANE_SHARING',1,'laneSharing','ERROR',JSON_OBJECT(),'Không dùng cổng bị vô hiệu hóa do chia sẻ lane'),
('PSU_CAPACITY',1,'psuCapacity','ERROR',JSON_OBJECT('headroom_ratio',1.30,'respect_gpu_vendor_minimum',TRUE),'Ước tính tải cực đại và dự phòng nguồn; tỷ lệ phải được kỹ thuật hiệu chỉnh'),
('POWER_CONNECTORS',1,'powerConnectors','ERROR',JSON_OBJECT('allow_unverified_adapters',FALSE),'Đủ đầu nguồn đúng loại cho toàn hệ thống'),
('DISPLAY_SOLUTION',1,'displaySolution','ERROR',JSON_OBJECT(),'Có GPU rời hoặc iGPU và cổng xuất hình phù hợp'),
('BUDGET_LIMIT',1,'budgetLimit','ERROR',JSON_OBJECT(),'Tổng tiền không vượt phạm vi ngân sách đã chọn'),
('SELLABLE_STOCK',1,'sellableStock','ERROR',JSON_OBJECT(),'Linh kiện cần mua đang bán và đủ khả năng cấp hàng');

INSERT INTO shipping_providers (code, name) VALUES
('GHN','Giao Hàng Nhanh'), ('GHTK','Giao Hàng Tiết Kiệm'),
('VIETTEL_POST','Viettel Post'), ('STORE','Cửa hàng tự giao / nhận tại cửa hàng');
INSERT INTO shipping_methods (provider_id, code, name, supports_cod)
SELECT id, 'STANDARD', 'Giao hàng tiêu chuẩn', TRUE
FROM shipping_providers WHERE code IN ('GHN','GHTK','VIETTEL_POST');
INSERT INTO shipping_methods (provider_id, code, name, supports_cod)
SELECT id, 'PICKUP', 'Nhận tại cửa hàng', TRUE FROM shipping_providers WHERE code = 'STORE';

COMMIT;
