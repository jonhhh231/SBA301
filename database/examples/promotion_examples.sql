-- OPTIONAL EXAMPLE. NOT a Flyway migration. Replace IDs before executing.
-- It creates DRAFT programs only. Publish after rule simulation in Spring Boot.
-- Requirements:
--   @admin_id: existing staff user; @gift_variant_id: existing mouse-pad SKU.
-- SET @admin_id = 123;
-- SET @gift_variant_id = 456;
-- Never execute with unset variables.

START TRANSACTION;

-- Example 1: strictly greater than VND 10 million -> one free mouse pad.
INSERT INTO promotions (code, name, created_by)
VALUES ('GIFT_OVER_10M','Đơn trên 10 triệu tặng lót chuột',@admin_id);
SET @promotion_id = LAST_INSERT_ID();
INSERT INTO promotion_versions (promotion_id, version_no, starts_at, ends_at, stacking_policy)
VALUES (@promotion_id,1,UTC_TIMESTAMP(6),DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 DAY),'EXCLUSIVE');
SET @version_id = LAST_INSERT_ID();
INSERT INTO promotion_condition_groups (promotion_version_id, logical_operator) VALUES (@version_id,'AND');
SET @group_id = LAST_INSERT_ID();
INSERT INTO promotion_conditions (group_id, condition_type, comparison_operator, configuration)
VALUES (@group_id,'ORDER_AMOUNT','GT',JSON_OBJECT('amount',10000000,'exclude_gifts',TRUE));
INSERT INTO promotion_targets (promotion_version_id, selector_key, target_role, variant_id)
VALUES (@version_id,'mouse_pad_gifts','GIFT',@gift_variant_id);
INSERT INTO promotion_actions (promotion_version_id, action_type, gift_quantity, configuration)
VALUES (@version_id,'GIFT',1,JSON_OBJECT('gift_selector','mouse_pad_gifts','out_of_stock','SKIP_BENEFIT'));
INSERT INTO promotion_usage_counters (promotion_version_id) VALUES (@version_id);

-- Example 2: strictly greater than VND 20 million -> 5%, capped at VND 2 million.
INSERT INTO promotions (code, name, created_by)
VALUES ('PERCENT_OVER_20M','Đơn trên 20 triệu giảm 5%',@admin_id);
SET @promotion_id = LAST_INSERT_ID();
INSERT INTO promotion_versions (promotion_id, version_no, starts_at, ends_at, stacking_policy)
VALUES (@promotion_id,1,UTC_TIMESTAMP(6),DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 DAY),'EXCLUSIVE');
SET @version_id = LAST_INSERT_ID();
INSERT INTO promotion_condition_groups (promotion_version_id, logical_operator) VALUES (@version_id,'AND');
SET @group_id = LAST_INSERT_ID();
INSERT INTO promotion_conditions (group_id, condition_type, comparison_operator, configuration)
VALUES (@group_id,'ORDER_AMOUNT','GT',JSON_OBJECT('amount',20000000,'exclude_gifts',TRUE));
INSERT INTO promotion_actions (promotion_version_id, action_type, percent_value, max_discount, configuration)
VALUES (@version_id,'PERCENT_DISCOUNT',5,2000000,JSON_OBJECT('scope','ELIGIBLE_ITEMS','rounding','HALF_UP','currency_scale',0));
INSERT INTO promotion_usage_counters (promotion_version_id) VALUES (@version_id);

-- Example 3: CPU + motherboard -> VND 500,000 per matched pair, at most one pair.
INSERT INTO promotions (code, name, created_by)
VALUES ('CPU_MB_COMBO','Combo CPU và mainboard giảm 500.000đ',@admin_id);
SET @promotion_id = LAST_INSERT_ID();
INSERT INTO promotion_versions (promotion_id, version_no, starts_at, ends_at, max_applications_per_order)
VALUES (@promotion_id,1,UTC_TIMESTAMP(6),DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 30 DAY),1);
SET @version_id = LAST_INSERT_ID();
INSERT INTO promotion_condition_groups (promotion_version_id, logical_operator) VALUES (@version_id,'AND');
SET @group_id = LAST_INSERT_ID();
INSERT INTO promotion_targets (promotion_version_id, selector_key, target_role, category_id)
SELECT @version_id,'cpu_set','INCLUDE',id FROM categories WHERE slug = 'cpu';
INSERT INTO promotion_targets (promotion_version_id, selector_key, target_role, category_id)
SELECT @version_id,'mb_set','INCLUDE',id FROM categories WHERE slug = 'mainboard';
INSERT INTO promotion_conditions (group_id, condition_type, comparison_operator, configuration) VALUES
(@group_id,'ITEM_QUANTITY','GTE',JSON_OBJECT('selector','cpu_set','quantity',1)),
(@group_id,'ITEM_QUANTITY','GTE',JSON_OBJECT('selector','mb_set','quantity',1));
INSERT INTO promotion_actions (promotion_version_id, action_type, amount, configuration)
VALUES (@version_id,'FIXED_DISCOUNT',500000,JSON_OBJECT('scope','MATCHED_COMBO','pair_selectors',JSON_ARRAY('cpu_set','mb_set'),'consume_matched_quantity',TRUE,'allocation','PROPORTIONAL','rounding','HALF_UP'));
INSERT INTO promotion_usage_counters (promotion_version_id) VALUES (@version_id);

COMMIT;
