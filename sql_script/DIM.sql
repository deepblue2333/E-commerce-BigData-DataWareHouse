-- Active: 1724848274437@@192.168.31.161@10000@gmall
DROP TABLE IF EXISTS dim_sku_full;

load data inpath '/origin_data/gmall/db/base_category2_full/2020-06-14' OVERWRITE into table gmall.ods_base_category2_full partition(dt='2020-06-14');

show tables;

DROP TABLE IF EXISTS ods_base_category2_full; 
CREATE EXTERNAL TABLE ods_base_category2_full
(
    `id`           STRING COMMENT '编号',
    `name`         STRING COMMENT '二级分类名称',
    `category1_id` STRING COMMENT '一级分类编号'
) COMMENT '二级品类表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
    LOCATION '/warehouse/gmall/ods/ods_base_category2_full/';

CREATE EXTERNAL TABLE dim_sku_full
(
    `id`                   STRING COMMENT 'sku_id',
    `price`                DECIMAL(16, 2) COMMENT '商品价格',
    `sku_name`             STRING COMMENT '商品名称',
    `sku_desc`             STRING COMMENT '商品描述',
    `weight`               DECIMAL(16, 2) COMMENT '重量',
    `is_sale`              BOOLEAN COMMENT '是否在售',
    `spu_id`               STRING COMMENT 'spu编号',
    `spu_name`             STRING COMMENT 'spu名称',
    `category3_id`         STRING COMMENT '三级分类id',
    `category3_name`       STRING COMMENT '三级分类名称',
    `category2_id`         STRING COMMENT '二级分类id',
    `category2_name`       STRING COMMENT '二级分类名称',
    `category1_id`         STRING COMMENT '一级分类id',
    `category1_name`       STRING COMMENT '一级分类名称',
    `tm_id`                STRING COMMENT '品牌id',
    `tm_name`              STRING COMMENT '品牌名称',
    `sku_attr_values`      ARRAY<STRUCT<`attr_id`:STRING,`value_id`:STRING,`attr_name`:STRING,`value_name`:STRING>> COMMENT '平台属性',
    `sku_sale_attr_values` ARRAY<STRUCT<`sale_attr_id`:STRING,`sale_attr_value_id`:STRING,`sale_attr_name`:STRING,`sale_attr_value_name`:STRING>> COMMENT '销售属性',
    `create_time`          STRING COMMENT '创建时间'
) 
COMMENT '商品维度表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_sku_full/'
TBLPROPERTIES ('orc.compress' = 'snappy');

select * from ods_base_category2_full;

-- UPDATE ods_base_category2_full SET dt = '2020-06-14';


with
sku as
(
    select
        id,
        price,
        sku_name,
        sku_desc,
        weight,
        is_sale,
        spu_id,
        category3_id,
        tm_id,
        create_time
    from ods_sku_info_full
    where dt='2020-06-14'
),
spu as
(
    select
        id,
        spu_name
    from ods_spu_info_full
    where dt='2020-06-14'
),
c3 as
(
    select
        id,
        name,
        category2_id
    from ods_base_category3_full
    where dt='2020-06-14'
),
c2 as
(
    select
        id,
        name,
        category1_id
    from ods_base_category2_full
    where dt='2020-06-14'
),
c1 as
(
    select
        id,
        name
    from ods_base_category1_full
    where dt='2020-06-14'
),
tm as
(
    select
        id,
        tm_name
    from ods_base_trademark_full
    where dt='2020-06-14'
),
attr as
(
    select
        sku_id,
        collect_set(named_struct('attr_id',attr_id,'value_id',value_id,'attr_name',attr_name,'value_name',value_name)) attrs
    from ods_sku_attr_value_full
    where dt='2020-06-14'
    group by sku_id
),
sale_attr as
(
    select
        sku_id,
        collect_set(named_struct('sale_attr_id',sale_attr_id,'sale_attr_value_id',sale_attr_value_id,'sale_attr_name',sale_attr_name,'sale_attr_value_name',sale_attr_value_name)) sale_attrs
    from ods_sku_sale_attr_value_full
    where dt='2020-06-14'
    group by sku_id
)
insert overwrite table dim_sku_full partition(dt='2020-06-14')
select
    sku.id,
    sku.price,
    sku.sku_name,
    sku.sku_desc,
    sku.weight,
    sku.is_sale,
    sku.spu_id,
    spu.spu_name,
    sku.category3_id,
    c3.name,
    c3.category2_id,
    c2.name,
    c2.category1_id,
    c1.name,
    sku.tm_id,
    tm.tm_name,
    attr.attrs,
    sale_attr.sale_attrs,
    sku.create_time
from sku
left join spu on sku.spu_id=spu.id
left join c3 on sku.category3_id=c3.id
left join c2 on c3.category2_id=c2.id
left join c1 on c2.category1_id=c1.id
left join tm on sku.tm_id=tm.id
left join attr on sku.id=attr.sku_id
left join sale_attr on sku.id=sale_attr.sku_id;


select * from dim_sku_full;


DROP TABLE IF EXISTS dim_coupon_full;
CREATE EXTERNAL TABLE dim_coupon_full
(
    `id`               STRING COMMENT '购物券编号',
    `coupon_name`      STRING COMMENT '购物券名称',
    `coupon_type_code` STRING COMMENT '购物券类型编码',
    `coupon_type_name` STRING COMMENT '购物券类型名称',
    `condition_amount` DECIMAL(16, 2) COMMENT '满额数',
    `condition_num`    BIGINT COMMENT '满件数',
    `activity_id`      STRING COMMENT '活动编号',
    `benefit_amount`   DECIMAL(16, 2) COMMENT '减金额',
    `benefit_discount` DECIMAL(16, 2) COMMENT '折扣',
    `benefit_rule`     STRING COMMENT '优惠规则:满元*减*元，满*件打*折',
    `create_time`      STRING COMMENT '创建时间',
    `range_type_code`  STRING COMMENT '优惠范围类型编码',
    `range_type_name`  STRING COMMENT '优惠范围类型名称',
    `limit_num`        BIGINT COMMENT '最多领取次数',
    `taken_count`      BIGINT COMMENT '已领取次数',
    `start_time`       STRING COMMENT '可以领取的开始日期',
    `end_time`         STRING COMMENT '可以领取的结束日期',
    `operate_time`     STRING COMMENT '修改时间',
    `expire_time`      STRING COMMENT '过期时间'
) COMMENT '优惠券维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_coupon_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

insert overwrite table dim_coupon_full partition(dt='2020-06-14')
select
    id,
    coupon_name,
    coupon_type,
    coupon_dic.dic_name,
    condition_amount,
    condition_num,
    activity_id,
    benefit_amount,
    benefit_discount,
    case coupon_type
        when '3201' then concat('满',condition_amount,'元减',benefit_amount,'元')
        when '3202' then concat('满',condition_num,'件打',10*(1-benefit_discount),'折')
        when '3203' then concat('减',benefit_amount,'元')
    end benefit_rule,
    create_time,
    range_type,
    range_dic.dic_name,
    limit_num,
    taken_count,
    start_time,
    end_time,
    operate_time,
    expire_time
from
(
    select
        id,
        coupon_name,
        coupon_type,
        condition_amount,
        condition_num,
        activity_id,
        benefit_amount,
        benefit_discount,
        create_time,
        range_type,
        limit_num,
        taken_count,
        start_time,
        end_time,
        operate_time,
        expire_time
    from ods_coupon_info_full
    where dt='2020-06-14'
)ci
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='32'
)coupon_dic
on ci.coupon_type=coupon_dic.dic_code
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='33'
)range_dic
on ci.range_type=range_dic.dic_code;


SELECT * from dim_coupon_full;

DROP TABLE IF EXISTS dim_activity_full;
CREATE EXTERNAL TABLE dim_activity_full
(
    `activity_rule_id`   STRING COMMENT '活动规则ID',
    `activity_id`        STRING COMMENT '活动ID',
    `activity_name`      STRING COMMENT '活动名称',
    `activity_type_code` STRING COMMENT '活动类型编码',
    `activity_type_name` STRING COMMENT '活动类型名称',
    `activity_desc`      STRING COMMENT '活动描述',
    `start_time`         STRING COMMENT '开始时间',
    `end_time`           STRING COMMENT '结束时间',
    `create_time`        STRING COMMENT '创建时间',
    `condition_amount`   DECIMAL(16, 2) COMMENT '满减金额',
    `condition_num`      BIGINT COMMENT '满减件数',
    `benefit_amount`     DECIMAL(16, 2) COMMENT '优惠金额',
    `benefit_discount`   DECIMAL(16, 2) COMMENT '优惠折扣',
    `benefit_rule`       STRING COMMENT '优惠规则',
    `benefit_level`      STRING COMMENT '优惠级别'
) COMMENT '活动信息表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_activity_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

insert overwrite table dim_activity_full partition(dt='2020-06-14')
select
    rule.id,
    info.id,
    activity_name,
    rule.activity_type,
    dic.dic_name,
    activity_desc,
    start_time,
    end_time,
    create_time,
    condition_amount,
    condition_num,
    benefit_amount,
    benefit_discount,
    case rule.activity_type
        when '3101' then concat('满',condition_amount,'元减',benefit_amount,'元')
        when '3102' then concat('满',condition_num,'件打',10*(1-benefit_discount),'折')
        when '3103' then concat('打',10*(1-benefit_discount),'折')
    end benefit_rule,
    benefit_level
from
(
    select
        id,
        activity_id,
        activity_type,
        condition_amount,
        condition_num,
        benefit_amount,
        benefit_discount,
        benefit_level
    from ods_activity_rule_full
    where dt='2020-06-14'
)rule
left join
(
    select
        id,
        activity_name,
        activity_type,
        activity_desc,
        start_time,
        end_time,
        create_time
    from ods_activity_info_full
    where dt='2020-06-14'
)info
on rule.activity_id=info.id
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='31'
)dic
on rule.activity_type=dic.dic_code;





DROP TABLE IF EXISTS dim_province_full;
CREATE EXTERNAL TABLE dim_province_full
(
    `id`            STRING COMMENT 'id',
    `province_name` STRING COMMENT '省市名称',
    `area_code`     STRING COMMENT '地区编码',
    `iso_code`      STRING COMMENT '旧版ISO-3166-2编码，供可视化使用',
    `iso_3166_2`    STRING COMMENT '新版IOS-3166-2编码，供可视化使用',
    `region_id`     STRING COMMENT '地区id',
    `region_name`   STRING COMMENT '地区名称'
) COMMENT '地区维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_province_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


insert overwrite table dim_province_full partition(dt='2020-06-14')
select
    province.id,
    province.name,
    province.area_code,
    province.iso_code,
    province.iso_3166_2,
    region_id,
    region_name
from
(
    select
        id,
        name,
        region_id,
        area_code,
        iso_code,
        iso_3166_2
    from ods_base_province_full
    where dt='2020-06-14'
)province
left join
(
    select
        id,
        region_name
    from ods_base_region_full
    where dt='2020-06-14'
)region
on province.region_id=region.id;


DROP TABLE IF EXISTS dim_date;
CREATE EXTERNAL TABLE dim_date
(
    `date_id`    STRING COMMENT '日期ID',
    `week_id`    STRING COMMENT '周ID,一年中的第几周',
    `week_day`   STRING COMMENT '周几',
    `day`        STRING COMMENT '每月的第几天',
    `month`      STRING COMMENT '一年中的第几月',
    `quarter`    STRING COMMENT '一年中的第几季度',
    `year`       STRING COMMENT '年份',
    `is_workday` STRING COMMENT '是否是工作日',
    `holiday_id` STRING COMMENT '节假日'
) COMMENT '时间维度表'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_date/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS tmp_dim_date_info;
CREATE EXTERNAL TABLE tmp_dim_date_info (
    `date_id` STRING COMMENT '日',
    `week_id` STRING COMMENT '周ID',
    `week_day` STRING COMMENT '周几',
    `day` STRING COMMENT '每月的第几天',
    `month` STRING COMMENT '第几月',
    `quarter` STRING COMMENT '第几季度',
    `year` STRING COMMENT '年',
    `is_workday` STRING COMMENT '是否是工作日',
    `holiday_id` STRING COMMENT '节假日'
) COMMENT '时间维度表'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/tmp/tmp_dim_date_info/';


insert overwrite table dim_date select * from tmp_dim_date_info;

select * from dim_date;

DROP TABLE IF EXISTS dim_user_zip;
CREATE EXTERNAL TABLE dim_user_zip
(
    `id`           STRING COMMENT '用户id',
    `login_name`   STRING COMMENT '用户名称',
    `nick_name`    STRING COMMENT '用户昵称',
    `name`         STRING COMMENT '用户姓名',
    `phone_num`    STRING COMMENT '手机号码',
    `email`        STRING COMMENT '邮箱',
    `user_level`   STRING COMMENT '用户等级',
    `birthday`     STRING COMMENT '生日',
    `gender`       STRING COMMENT '性别',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '操作时间',
    `start_date`   STRING COMMENT '开始日期',
    `end_date`     STRING COMMENT '结束日期'
) COMMENT '用户表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_user_zip/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


insert overwrite table dim_user_zip partition (dt='9999-12-31')
select
    data.id,
    data.login_name,
    data.nick_name,
    md5(data.name),
    md5(data.phone_num),
    md5(data.email),
    data.user_level,
    data.birthday,
    data.gender,
    data.create_time,
    data.operate_time,
    '2020-06-14' start_date,
    '9999-12-31' end_date
from ods_user_info_inc
where dt='2020-06-14'
and type='bootstrap-insert';

-----------------------------------------------
-- DWD
-----------------------------------------------

DROP TABLE IF EXISTS dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE dwd_trade_cart_add_inc
(
    `id`               STRING COMMENT '编号',
    `user_id`          STRING COMMENT '用户id',
    `sku_id`           STRING COMMENT '商品id',
    `date_id`          STRING COMMENT '时间id',
    `create_time`      STRING COMMENT '加购时间',
    `source_id`        STRING COMMENT '来源类型ID',
    `source_type_code` STRING COMMENT '来源类型编码',
    `source_type_name` STRING COMMENT '来源类型名称',
    `sku_num`          BIGINT COMMENT '加购物车件数'
) COMMENT '交易域加购物车事务事实表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_order_detail_inc
(
    `id`                    STRING COMMENT '编号',
    `order_id`              STRING COMMENT '订单id',
    `user_id`               STRING COMMENT '用户id',
    `sku_id`                STRING COMMENT '商品id',
    `province_id`           STRING COMMENT '省份id',
    `activity_id`           STRING COMMENT '参与活动规则id',
    `activity_rule_id`      STRING COMMENT '参与活动规则id',
    `coupon_id`             STRING COMMENT '使用优惠券id',
    `date_id`               STRING COMMENT '下单日期id',
    `create_time`           STRING COMMENT '下单时间',
    `source_id`             STRING COMMENT '来源编号',
    `source_type_code`      STRING COMMENT '来源类型编码',
    `source_type_name`      STRING COMMENT '来源类型名称',
    `sku_num`               BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`    DECIMAL(16, 2) COMMENT '最终价格分摊'
) COMMENT '交易域下单明细事务事实表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_trade_cancel_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_cancel_detail_inc
(
    `id`                    STRING COMMENT '编号',
    `order_id`              STRING COMMENT '订单id',
    `user_id`               STRING COMMENT '用户id',
    `sku_id`                STRING COMMENT '商品id',
    `province_id`           STRING COMMENT '省份id',
    `activity_id`           STRING COMMENT '参与活动规则id',
    `activity_rule_id`      STRING COMMENT '参与活动规则id',
    `coupon_id`             STRING COMMENT '使用优惠券id',
    `date_id`               STRING COMMENT '取消订单日期id',
    `cancel_time`           STRING COMMENT '取消订单时间',
    `source_id`             STRING COMMENT '来源编号',
    `source_type_code`      STRING COMMENT '来源类型编码',
    `source_type_name`      STRING COMMENT '来源类型名称',
    `sku_num`               BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`    DECIMAL(16, 2) COMMENT '最终价格分摊'
) COMMENT '交易域取消订单明细事务事实表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cancel_detail_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_trade_pay_detail_suc_inc;
CREATE EXTERNAL TABLE dwd_trade_pay_detail_suc_inc
(
    `id`                    STRING COMMENT '编号',
    `order_id`              STRING COMMENT '订单id',
    `user_id`               STRING COMMENT '用户id',
    `sku_id`                STRING COMMENT '商品id',
    `province_id`           STRING COMMENT '省份id',
    `activity_id`           STRING COMMENT '参与活动规则id',
    `activity_rule_id`      STRING COMMENT '参与活动规则id',
    `coupon_id`             STRING COMMENT '使用优惠券id',
    `payment_type_code`     STRING COMMENT '支付类型编码',
    `payment_type_name`     STRING COMMENT '支付类型名称',
    `date_id`               STRING COMMENT '支付日期id',
    `callback_time`         STRING COMMENT '支付成功时间',
    `source_id`             STRING COMMENT '来源编号',
    `source_type_code`      STRING COMMENT '来源类型编码',
    `source_type_name`      STRING COMMENT '来源类型名称',
    `sku_num`               BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '应支付原始金额',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
    `split_payment_amount`  DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域成功支付事务事实表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_pay_detail_suc_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_trade_order_refund_inc;
CREATE EXTERNAL TABLE dwd_trade_order_refund_inc
(
    `id`                      STRING COMMENT '编号',
    `user_id`                 STRING COMMENT '用户ID',
    `order_id`                STRING COMMENT '订单ID',
    `sku_id`                  STRING COMMENT '商品ID',
    `province_id`             STRING COMMENT '地区ID',
    `date_id`                 STRING COMMENT '日期ID',
    `create_time`             STRING COMMENT '退单时间',
    `refund_type_code`        STRING COMMENT '退单类型编码',
    `refund_type_name`        STRING COMMENT '退单类型名称',
    `refund_reason_type_code` STRING COMMENT '退单原因类型编码',
    `refund_reason_type_name` STRING COMMENT '退单原因类型名称',
    `refund_reason_txt`       STRING COMMENT '退单原因描述',
    `refund_num`              BIGINT COMMENT '退单件数',
    `refund_amount`           DECIMAL(16, 2) COMMENT '退单金额'
) COMMENT '交易域退单事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_order_refund_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_trade_refund_pay_suc_inc;
CREATE EXTERNAL TABLE dwd_trade_refund_pay_suc_inc
(
    `id`                STRING COMMENT '编号',
    `user_id`           STRING COMMENT '用户ID',
    `order_id`          STRING COMMENT '订单编号',
    `sku_id`            STRING COMMENT 'SKU编号',
    `province_id`       STRING COMMENT '地区ID',
    `payment_type_code` STRING COMMENT '支付类型编码',
    `payment_type_name` STRING COMMENT '支付类型名称',
    `date_id`           STRING COMMENT '日期ID',
    `callback_time`     STRING COMMENT '支付成功时间',
    `refund_num`        DECIMAL(16, 2) COMMENT '退款件数',
    `refund_amount`     DECIMAL(16, 2) COMMENT '退款金额'
) COMMENT '交易域提交退款成功事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_refund_pay_suc_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_trade_cart_full;
CREATE EXTERNAL TABLE dwd_trade_cart_full
(
    `id`       STRING COMMENT '编号',
    `user_id`  STRING COMMENT '用户id',
    `sku_id`   STRING COMMENT '商品id',
    `sku_name` STRING COMMENT '商品名称',
    `sku_num`  BIGINT COMMENT '加购物车件数'
) COMMENT '交易域购物车周期快照事实表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_tool_coupon_get_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_get_inc
(
    `id`        STRING COMMENT '编号',
    `coupon_id` STRING COMMENT '优惠券ID',
    `user_id`   STRING COMMENT 'userid',
    `date_id`   STRING COMMENT '日期ID',
    `get_time`  STRING COMMENT '领取时间'
) COMMENT '优惠券领取事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_tool_coupon_get_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_tool_coupon_order_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_order_inc
(
    `id`         STRING COMMENT '编号',
    `coupon_id`  STRING COMMENT '优惠券ID',
    `user_id`    STRING COMMENT 'user_id',
    `order_id`   STRING COMMENT 'order_id',
    `date_id`    STRING COMMENT '日期ID',
    `order_time` STRING COMMENT '使用下单时间'
) COMMENT '优惠券使用下单事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_tool_coupon_order_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_tool_coupon_pay_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_pay_inc
(
    `id`           STRING COMMENT '编号',
    `coupon_id`    STRING COMMENT '优惠券ID',
    `user_id`      STRING COMMENT 'user_id',
    `order_id`     STRING COMMENT 'order_id',
    `date_id`      STRING COMMENT '日期ID',
    `payment_time` STRING COMMENT '使用下单时间'
) COMMENT '优惠券使用支付事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_tool_coupon_pay_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_interaction_favor_add_inc;
CREATE EXTERNAL TABLE dwd_interaction_favor_add_inc
(
    `id`          STRING COMMENT '编号',
    `user_id`     STRING COMMENT '用户id',
    `sku_id`      STRING COMMENT 'sku_id',
    `date_id`     STRING COMMENT '日期id',
    `create_time` STRING COMMENT '收藏时间'
) COMMENT '收藏事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_interaction_favor_add_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_interaction_comment_inc;
CREATE EXTERNAL TABLE dwd_interaction_comment_inc
(
    `id`            STRING COMMENT '编号',
    `user_id`       STRING COMMENT '用户ID',
    `sku_id`        STRING COMMENT 'sku_id',
    `order_id`      STRING COMMENT '订单ID',
    `date_id`       STRING COMMENT '日期ID',
    `create_time`   STRING COMMENT '评价时间',
    `appraise_code` STRING COMMENT '评价编码',
    `appraise_name` STRING COMMENT '评价名称'
) COMMENT '评价事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_interaction_comment_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_traffic_page_view_inc;
CREATE EXTERNAL TABLE dwd_traffic_page_view_inc
(
    `province_id`    STRING COMMENT '省份id',
    `brand`          STRING COMMENT '手机品牌',
    `channel`        STRING COMMENT '渠道',
    `is_new`         STRING COMMENT '是否首次启动',
    `model`          STRING COMMENT '手机型号',
    `mid_id`         STRING COMMENT '设备id',
    `operate_system` STRING COMMENT '操作系统',
    `user_id`        STRING COMMENT '会员id',
    `version_code`   STRING COMMENT 'app版本号',
    `page_item`      STRING COMMENT '目标id ',
    `page_item_type` STRING COMMENT '目标类型',
    `last_page_id`   STRING COMMENT '上页类型',
    `page_id`        STRING COMMENT '页面ID ',
    `source_type`    STRING COMMENT '来源类型',
    `date_id`        STRING COMMENT '日期id',
    `view_time`      STRING COMMENT '跳入时间',
    `session_id`     STRING COMMENT '所属会话id',
    `during_time`    BIGINT COMMENT '持续时间毫秒'
) COMMENT '页面日志表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_traffic_start_inc;
CREATE EXTERNAL TABLE dwd_traffic_start_inc
(
    `province_id`     STRING COMMENT '省份id',
    `brand`           STRING COMMENT '手机品牌',
    `channel`         STRING COMMENT '渠道',
    `is_new`          STRING COMMENT '是否首次启动',
    `model`           STRING COMMENT '手机型号',
    `mid_id`          STRING COMMENT '设备id',
    `operate_system`  STRING COMMENT '操作系统',
    `user_id`         STRING COMMENT '会员id',
    `version_code`    STRING COMMENT 'app版本号',
    `entry`           STRING COMMENT 'icon手机图标 notice 通知',
    `open_ad_id`      STRING COMMENT '广告页ID ',
    `date_id`         STRING COMMENT '日期id',
    `start_time`      STRING COMMENT '启动时间',
    `loading_time_ms` BIGINT COMMENT '启动加载时间',
    `open_ad_ms`      BIGINT COMMENT '广告总共播放时间',
    `open_ad_skip_ms` BIGINT COMMENT '用户跳过广告时点'
) COMMENT '启动日志表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_start_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_traffic_action_inc;
CREATE EXTERNAL TABLE dwd_traffic_action_inc
(
    `province_id`      STRING COMMENT '省份id',
    `brand`            STRING COMMENT '手机品牌',
    `channel`          STRING COMMENT '渠道',
    `is_new`           STRING COMMENT '是否首次启动',
    `model`            STRING COMMENT '手机型号',
    `mid_id`           STRING COMMENT '设备id',
    `operate_system`   STRING COMMENT '操作系统',
    `user_id`          STRING COMMENT '会员id',
    `version_code`     STRING COMMENT 'app版本号',
    `during_time`      BIGINT COMMENT '持续时间毫秒',
    `page_item`        STRING COMMENT '目标id ',
    `page_item_type`   STRING COMMENT '目标类型',
    `last_page_id`     STRING COMMENT '上页类型',
    `page_id`          STRING COMMENT '页面id ',
    `source_type`      STRING COMMENT '来源类型',
    `action_id`        STRING COMMENT '动作id',
    `action_item`      STRING COMMENT '目标id ',
    `action_item_type` STRING COMMENT '目标类型',
    `date_id`          STRING COMMENT '日期id',
    `action_time`      STRING COMMENT '动作发生时间'
) COMMENT '动作日志表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_action_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');

DROP TABLE IF EXISTS dwd_traffic_display_inc;
CREATE EXTERNAL TABLE dwd_traffic_display_inc
(
    `province_id`       STRING COMMENT '省份id',
    `brand`             STRING COMMENT '手机品牌',
    `channel`           STRING COMMENT '渠道',
    `is_new`            STRING COMMENT '是否首次启动',
    `model`             STRING COMMENT '手机型号',
    `mid_id`            STRING COMMENT '设备id',
    `operate_system`    STRING COMMENT '操作系统',
    `user_id`           STRING COMMENT '会员id',
    `version_code`      STRING COMMENT 'app版本号',
    `during_time`       BIGINT COMMENT 'app版本号',
    `page_item`         STRING COMMENT '目标id ',
    `page_item_type`    STRING COMMENT '目标类型',
    `last_page_id`      STRING COMMENT '上页类型',
    `page_id`           STRING COMMENT '页面ID ',
    `source_type`       STRING COMMENT '来源类型',
    `date_id`           STRING COMMENT '日期id',
    `display_time`      STRING COMMENT '曝光时间',
    `display_type`      STRING COMMENT '曝光类型',
    `display_item`      STRING COMMENT '曝光对象id ',
    `display_item_type` STRING COMMENT 'app版本号',
    `display_order`     BIGINT COMMENT '曝光顺序',
    `display_pos_id`    BIGINT COMMENT '曝光位置'
) COMMENT '曝光日志表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_display_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_traffic_error_inc;
CREATE EXTERNAL TABLE dwd_traffic_error_inc
(
    `province_id`     STRING COMMENT '地区编码',
    `brand`           STRING COMMENT '手机品牌',
    `channel`         STRING COMMENT '渠道',
    `is_new`          STRING COMMENT '是否首次启动',
    `model`           STRING COMMENT '手机型号',
    `mid_id`          STRING COMMENT '设备id',
    `operate_system`  STRING COMMENT '操作系统',
    `user_id`         STRING COMMENT '会员id',
    `version_code`    STRING COMMENT 'app版本号',
    `page_item`       STRING COMMENT '目标id ',
    `page_item_type`  STRING COMMENT '目标类型',
    `last_page_id`    STRING COMMENT '上页类型',
    `page_id`         STRING COMMENT '页面ID ',
    `source_type`     STRING COMMENT '来源类型',
    `entry`           STRING COMMENT 'icon手机图标  notice 通知',
    `loading_time`    STRING COMMENT '启动加载时间',
    `open_ad_id`      STRING COMMENT '广告页ID ',
    `open_ad_ms`      STRING COMMENT '广告总共播放时间',
    `open_ad_skip_ms` STRING COMMENT '用户跳过广告时点',
    `actions`         ARRAY<STRUCT<action_id:STRING,item:STRING,item_type:STRING,ts:BIGINT>> COMMENT '动作信息',
    `displays`        ARRAY<STRUCT<display_type :STRING,item :STRING,item_type :STRING,`order` :STRING,pos_id
                                   :STRING>> COMMENT '曝光信息',
    `date_id`         STRING COMMENT '日期id',
    `error_time`      STRING COMMENT '错误时间',
    `error_code`      STRING COMMENT '错误码',
    `error_msg`       STRING COMMENT '错误信息'
) COMMENT '错误日志表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_error_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');


DROP TABLE IF EXISTS dwd_user_register_inc;
CREATE EXTERNAL TABLE dwd_user_register_inc
(
    `user_id`        STRING COMMENT '用户ID',
    `date_id`        STRING COMMENT '日期ID',
    `create_time`    STRING COMMENT '注册时间',
    `channel`        STRING COMMENT '应用下载渠道',
    `province_id`    STRING COMMENT '省份id',
    `version_code`   STRING COMMENT '应用版本',
    `mid_id`         STRING COMMENT '设备id',
    `brand`          STRING COMMENT '设备品牌',
    `model`          STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户注册事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_register_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


DROP TABLE IF EXISTS dwd_user_login_inc;
CREATE EXTERNAL TABLE dwd_user_login_inc
(
    `user_id`        STRING COMMENT '用户ID',
    `date_id`        STRING COMMENT '日期ID',
    `login_time`     STRING COMMENT '登录时间',
    `channel`        STRING COMMENT '应用下载渠道',
    `province_id`    STRING COMMENT '省份id',
    `version_code`   STRING COMMENT '应用版本',
    `mid_id`         STRING COMMENT '设备id',
    `brand`          STRING COMMENT '设备品牌',
    `model`          STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户登录事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_login_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");


SELECT * FROM dwd_user_register_inc; 


set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_user_register_inc partition(dt)
select
    ui.user_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system,
    date_format(create_time,'yyyy-MM-dd')
from
(
    select
        data.id user_id,
        data.create_time
    from ods_user_info_inc
    where dt='2020-06-14'
    and type='bootstrap-insert'
)ui
left join
(
    select
        common.ar area_code,
        common.ba brand,
        common.ch channel,
        common.md model,
        common.mid mid_id,
        common.os operate_system,
        common.uid user_id,
        common.vc version_code
    from ods_log_inc
    where dt='2020-06-14'
    and page.page_id='register'
    and common.uid is not null
)log
on ui.user_id=log.user_id
left join
(
    select
        id province_id,
        area_code
    from ods_base_province_full
    where dt='2020-06-14'
)bp
on log.area_code=bp.area_code;

show tables;

select * from ods_coupon_use_inc;

insert overwrite table dwd_tool_coupon_pay_inc partition(dt)
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.used_time,'yyyy-MM-dd') date_id,
    data.used_time,
    date_format(data.used_time,'yyyy-MM-dd')
from ods_coupon_use_inc
where dt='2020-06-14'
and type='bootstrap-insert'
and data.used_time is not null;


set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_cart_add_inc partition (dt)
select
    id,
    user_id,
    sku_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time,
    source_id,
    source_type,
    dic.dic_name,
    sku_num,
    date_format(create_time, 'yyyy-MM-dd')
from
(
    select
        data.id,
        data.user_id,
        data.sku_id,
        data.create_time,
        data.source_id,
        data.source_type,
        data.sku_num
    from ods_cart_info_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
)ci
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='24'
)dic
on ci.source_type=dic.dic_code;

show tables;

select * from ods_order_info_inc;

insert overwrite table dwd_trade_cancel_detail_inc partition (dt)
select
    od.id,
    order_id,
    user_id,
    sku_id,
    province_id,
    activity_id,
    activity_rule_id,
    coupon_id,
    date_format(canel_time,'yyyy-MM-dd') date_id,
    canel_time,
    source_id,
    source_type,
    dic_name,
    sku_num,
    split_original_amount,
    split_activity_amount,
    split_coupon_amount,
    split_total_amount,
    date_format(canel_time,'yyyy-MM-dd')
from
(
    select
        data.id,
        data.order_id,
        data.sku_id,
        data.source_id,
        data.source_type,
        data.sku_num,
        data.sku_num * data.order_price split_original_amount,
        data.split_total_amount,
        data.split_activity_amount,
        data.split_coupon_amount
    from ods_order_detail_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) od
join
(
    select
        data.id,
        data.user_id,
        data.province_id,
        data.operate_time canel_time
    from ods_order_info_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
    and data.order_status='1003'
) oi
on od.order_id = oi.id
left join
(
    select
        data.order_detail_id,
        data.activity_id,
        data.activity_rule_id
    from ods_order_detail_activity_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) act
on od.id = act.order_detail_id
left join
(
    select
        data.order_detail_id,
        data.coupon_id
    from ods_order_detail_coupon_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) cou
on od.id = cou.order_detail_id
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='24'
)dic
on od.source_type=dic.dic_code;


insert overwrite table dwd_tool_coupon_pay_inc partition(dt)
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.used_time,'yyyy-MM-dd') date_id,
    data.used_time,
    date_format(data.used_time,'yyyy-MM-dd')
from ods_coupon_use_inc
where dt='2020-06-14'
and type='bootstrap-insert'
and data.used_time is not null;


insert overwrite table dwd_tool_coupon_order_inc partition(dt)
select
    data.id,
    data.coupon_id,
    data.user_id,
    data.order_id,
    date_format(data.using_time,'yyyy-MM-dd') date_id,
    data.using_time,
    date_format(data.using_time,'yyyy-MM-dd')
from ods_coupon_use_inc
where dt='2020-06-14'
and type='bootstrap-insert'
and data.using_time is not null;


insert overwrite table dwd_tool_coupon_get_inc partition(dt)
select
    data.id,
    data.coupon_id,
    data.user_id,
    date_format(data.get_time,'yyyy-MM-dd') date_id,
    data.get_time,
    date_format(data.get_time,'yyyy-MM-dd')
from ods_coupon_use_inc
where dt='2020-06-14'
and type='bootstrap-insert';


insert overwrite table dwd_interaction_comment_inc partition(dt)
select
    id,
    user_id,
    sku_id,
    order_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time,
    appraise,
    dic_name,
    date_format(create_time,'yyyy-MM-dd')
from
(
    select
        data.id,
        data.user_id,
        data.sku_id,
        data.order_id,
        data.create_time,
        data.appraise
    from ods_comment_info_inc
    where dt='2020-06-14'
    and type='bootstrap-insert'
)ci
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='12'
)dic
on ci.appraise=dic.dic_code;


set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_order_detail_inc partition (dt)
select
    od.id,
    order_id,
    user_id,
    sku_id,
    province_id,
    activity_id,
    activity_rule_id,
    coupon_id,
    date_format(create_time, 'yyyy-MM-dd') date_id,
    create_time,
    source_id,
    source_type,
    dic_name,
    sku_num,
    split_original_amount,
    split_activity_amount,
    split_coupon_amount,
    split_total_amount,
    date_format(create_time,'yyyy-MM-dd')
from
(
    select
        data.id,
        data.order_id,
        data.sku_id,
        data.create_time,
        data.source_id,
        data.source_type,
        data.sku_num,
        data.sku_num * data.order_price split_original_amount,
        data.split_total_amount,
        data.split_activity_amount,
        data.split_coupon_amount
    from ods_order_detail_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) od
left join
(
    select
        data.id,
        data.user_id,
        data.province_id
    from ods_order_info_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) oi
on od.order_id = oi.id
left join
(
    select
        data.order_detail_id,
        data.activity_id,
        data.activity_rule_id
    from ods_order_detail_activity_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) act
on od.id = act.order_detail_id
left join
(
    select
        data.order_detail_id,
        data.coupon_id
    from ods_order_detail_coupon_inc
    where dt = '2020-06-14'
    and type = 'bootstrap-insert'
) cou
on od.id = cou.order_detail_id
left join
(
    select
        dic_code,
        dic_name
    from ods_base_dic_full
    where dt='2020-06-14'
    and parent_code='24'
)dic
on od.source_type=dic.dic_code;


















