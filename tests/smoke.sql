-- Run ONLY in a disposable test database after V1 and V2.
-- Fixture DML is rolled back. Routine DDL is not transactional.
SET NAMES utf8mb4;
SET time_zone = '+00:00';
DELIMITER $$
CREATE PROCEDURE pcforge_schema_smoke_test()
BEGIN
  DECLARE v_user BIGINT;
  DECLARE v_brand BIGINT;
  DECLARE v_category BIGINT;
  DECLARE v_product BIGINT;
  DECLARE v_sku BIGINT;
  DECLARE v_warehouse BIGINT;
  DECLARE v_balance BIGINT;
  DECLARE v_serial BIGINT;
  DECLARE v_order BIGINT;
  DECLARE v_item_a BIGINT;
  DECLARE v_item_b BIGINT;
  DECLARE v_attribute BIGINT;
  DECLARE v_got_error BOOLEAN DEFAULT FALSE;
  DECLARE v_count INT;
  DECLARE v_amount DECIMAL(19,2);
  DECLARE v_suffix VARCHAR(32);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET v_suffix = REPLACE(UUID(),'-','');
  START TRANSACTION;

  INSERT INTO users(email, full_name)
  VALUES (CONCAT(v_suffix,'@example.invalid'),'Schema smoke fixture');
  SET v_user = LAST_INSERT_ID();
  INSERT INTO customer_addresses(user_id, recipient_name, phone, province_name, address_line, is_default)
  VALUES (v_user,'Fixture','0000000000','Fixture','Fixture',TRUE);
  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1062 SET v_got_error = TRUE;
    INSERT INTO customer_addresses(user_id, recipient_name, phone, province_name, address_line, is_default)
    VALUES (v_user,'Fixture','0000000000','Fixture','Second default',TRUE);
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: duplicate default address accepted'; END IF;

  SELECT id INTO v_brand FROM brands WHERE slug = 'intel';
  SELECT id INTO v_category FROM categories WHERE slug = 'cpu';
  IF v_brand IS NULL OR v_category IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: run V2 reference data first';
  END IF;
  INSERT INTO products(brand_id, category_id, name, slug, status)
  VALUES(v_brand,v_category,'SMOKE ONLY',CONCAT('smoke-',v_suffix),'ACTIVE');
  SET v_product = LAST_INSERT_ID();
  INSERT INTO product_variants(product_id, sku, name, list_price, sale_price, track_serial, status)
  VALUES(v_product,CONCAT('SMOKE-',v_suffix),'SMOKE ONLY',1000000,1000000,TRUE,'ACTIVE');
  SET v_sku = LAST_INSERT_ID();

  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819 SET v_got_error = TRUE;
    UPDATE product_variants SET sale_price = -1 WHERE id = v_sku;
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: negative SKU price accepted'; END IF;

  SELECT id INTO v_attribute FROM attribute_definitions WHERE code = 'cpu_cores';
  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819 SET v_got_error = TRUE;
    INSERT INTO variant_attribute_values(variant_id, attribute_id, number_value, text_value)
    VALUES(v_sku,v_attribute,6,'two values are invalid');
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: multiple typed attribute values accepted'; END IF;

  INSERT INTO warehouses(code,name,address) VALUES(CONCAT('W-',LEFT(v_suffix,20)),'SMOKE ONLY','Fixture');
  SET v_warehouse = LAST_INSERT_ID();
  INSERT INTO inventory_balances(warehouse_id,variant_id,on_hand,reserved)
  VALUES(v_warehouse,v_sku,1,0);
  SET v_balance = LAST_INSERT_ID();
  UPDATE inventory_balances SET reserved = reserved + 1, version = version + 1
  WHERE id = v_balance AND stock_condition = 'SELLABLE' AND on_hand - reserved >= 1;
  IF ROW_COUNT() <> 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: initial stock reservation failed'; END IF;
  UPDATE inventory_balances SET reserved = reserved + 1, version = version + 1
  WHERE id = v_balance AND stock_condition = 'SELLABLE' AND on_hand - reserved >= 1;
  IF ROW_COUNT() <> 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: conditional update oversold stock'; END IF;
  SELECT available INTO v_count FROM inventory_balances WHERE id = v_balance;
  IF v_count <> 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: generated available incorrect'; END IF;

  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819 SET v_got_error = TRUE;
    UPDATE inventory_balances SET reserved = 2 WHERE id = v_balance;
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: CHECK allowed reserved greater than on_hand'; END IF;

  INSERT INTO serial_units(variant_id,serial_namespace,serial_number,serial_normalized,warehouse_id)
  VALUES(v_sku,'SMOKE',v_suffix,v_suffix,v_warehouse);
  SET v_serial = LAST_INSERT_ID();
  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1062 SET v_got_error = TRUE;
    INSERT INTO serial_units(variant_id,serial_namespace,serial_number,serial_normalized)
    VALUES(v_sku,'SMOKE',v_suffix,v_suffix);
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: duplicate namespace/SN accepted'; END IF;

  INSERT INTO orders(order_number,user_id,customer_email,customer_phone,subtotal,discount_amount,grand_total)
  VALUES(CONCAT('SMOKE-',v_suffix),v_user,CONCAT(v_suffix,'@example.invalid'),'0000000000',2000000,100000,1900000);
  SET v_order = LAST_INSERT_ID();
  INSERT INTO order_items(order_id,variant_id,sku_snapshot,name_snapshot,quantity,unit_price,discount_amount,requires_serial)
  VALUES(v_order,v_sku,'SMOKE','SMOKE',1,1000000,100000,TRUE);
  SET v_item_a = LAST_INSERT_ID();
  INSERT INTO order_items(order_id,variant_id,sku_snapshot,name_snapshot,quantity,unit_price,requires_serial)
  VALUES(v_order,v_sku,'SMOKE','SMOKE',1,1000000,TRUE);
  SET v_item_b = LAST_INSERT_ID();
  SELECT line_total INTO v_amount FROM order_items WHERE id = v_item_a;
  IF v_amount <> 900000 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: line_total generation incorrect'; END IF;

  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819 SET v_got_error = TRUE;
    UPDATE orders SET grand_total = 1 WHERE id = v_order;
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: inconsistent grand_total accepted'; END IF;

  INSERT INTO order_item_serials(order_item_id,serial_unit_id) VALUES(v_item_a,v_serial);
  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1062 SET v_got_error = TRUE;
    INSERT INTO order_item_serials(order_item_id,serial_unit_id) VALUES(v_item_b,v_serial);
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: concurrent active SN allocation accepted'; END IF;
  UPDATE order_item_serials SET released_at = UTC_TIMESTAMP(6), release_reason = 'Test release'
  WHERE order_item_id = v_item_a;
  INSERT INTO order_item_serials(order_item_id,serial_unit_id) VALUES(v_item_b,v_serial);

  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819 SET v_got_error = TRUE;
    INSERT INTO reviews(product_id,user_id,order_item_id,rating,body)
    VALUES(v_product,v_user,v_item_a,6,'Invalid rating');
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: rating outside 1..5 accepted'; END IF;

  SET v_got_error = FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1452 SET v_got_error = TRUE;
    INSERT INTO user_roles(user_id,role_id) VALUES(v_user,-1);
  END;
  IF NOT v_got_error THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: invalid foreign key accepted'; END IF;

  ROLLBACK;
  SELECT 'PASS: address, prices, attributes, stock, SN, totals, reviews, foreign keys; fixtures rolled back' AS result;
END$$
DELIMITER ;
CALL pcforge_schema_smoke_test();
DROP PROCEDURE pcforge_schema_smoke_test;
