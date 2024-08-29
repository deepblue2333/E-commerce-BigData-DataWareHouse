-- Active: 1724848274437@@192.168.31.161@10000@gmall
DROP TABLE IF EXISTS ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE ads_traffic_stats_by_channel
(
    `dt`               STRING COMMENT '统计日期',
    `recent_days`      BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `channel`          STRING COMMENT '渠道',
    `uv_count`         BIGINT COMMENT '访客人数',
    `avg_duration_sec` BIGINT COMMENT '会话平均停留时长，单位为秒',
    `avg_page_count`   BIGINT COMMENT '会话平均浏览页面数',
    `sv_count`         BIGINT COMMENT '会话数',
    `bounce_rate`      DECIMAL(16, 2) COMMENT '跳出率'
) COMMENT '各渠道流量统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_traffic_stats_by_channel/';


insert overwrite table ads_traffic_stats_by_channel
select * from ads_traffic_stats_by_channel
union
select
    '2020-06-14' dt,
    recent_days,
    channel,
    cast(count(distinct(mid_id)) as bigint) uv_count,
    cast(avg(during_time_1d)/1000 as bigint) avg_duration_sec,
    cast(avg(page_count_1d) as bigint) avg_page_count,
    cast(count(*) as bigint) sv_count,
    cast(sum(if(page_count_1d=1,1,0))/count(*) as decimal(16,2)) bounce_rate
from dws_traffic_session_page_view_1d lateral view explode(array(1,7,30)) tmp as recent_days
where dt>=date_add('2020-06-14',-recent_days+1)
group by recent_days,channel;

SELECT * FROM ads_traffic_stats_by_channel;

DROP TABLE IF EXISTS ads_page_path;
CREATE EXTERNAL TABLE ads_page_path
(
    `dt`          STRING COMMENT '统计日期',
    `recent_days` BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `source`      STRING COMMENT '跳转起始页面ID',
    `target`      STRING COMMENT '跳转终到页面ID',
    `path_count`  BIGINT COMMENT '跳转次数'
) COMMENT '页面浏览路径分析'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_page_path/';

insert overwrite table ads_page_path
select * from ads_page_path
union
select
    '2020-06-14' dt,
    recent_days,
    source,
    nvl(target,'null'),
    count(*) path_count
from
(
    select
        recent_days,
        concat('step-',rn,':',page_id) source,
        concat('step-',rn+1,':',next_page_id) target
    from
    (
        select
            recent_days,
            page_id,
            lead(page_id,1,null) over(partition by session_id,recent_days) next_page_id,
            row_number() over (partition by session_id,recent_days order by view_time) rn
        from dwd_traffic_page_view_inc lateral view explode(array(1,7,30)) tmp as recent_days
        where dt>=date_add('2020-06-14',-recent_days+1)
    )t1
)t2
group by recent_days,source,target;


SELECT * from ads_page_path;

DROP TABLE IF EXISTS ads_user_change;
CREATE EXTERNAL TABLE ads_user_change
(
    `dt`               STRING COMMENT '统计日期',
    `user_churn_count` BIGINT COMMENT '流失用户数',
    `user_back_count`  BIGINT COMMENT '回流用户数'
) COMMENT '用户变动统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_change/';

insert overwrite table ads_user_change
select * from ads_user_change
union
select
    churn.dt,
    user_churn_count,
    user_back_count
from
(
    select
        '2020-06-14' dt,
        count(*) user_churn_count
    from dws_user_user_login_td
    where dt='2020-06-14'
    and login_date_last=date_add('2020-06-14',-7)
)churn
join
(
    select
        '2020-06-14' dt,
        count(*) user_back_count
    from
    (
        select
            user_id,
            login_date_last
        from dws_user_user_login_td
        where dt='2020-06-14'
    )t1
    join
    (
        select
            user_id,
            login_date_last login_date_previous
        from dws_user_user_login_td
        where dt=date_add('2020-06-14',-1)
    )t2
    on t1.user_id=t2.user_id
    where datediff(login_date_last,login_date_previous)>=8
)back
on churn.dt=back.dt;


SELECT * FROM ads_user_change;


DROP TABLE IF EXISTS ads_user_retention;
CREATE EXTERNAL TABLE ads_user_retention
(
    `dt`              STRING COMMENT '统计日期',
    `create_date`     STRING COMMENT '用户新增日期',
    `retention_day`   INT COMMENT '截至当前日期留存天数',
    `retention_count` BIGINT COMMENT '留存用户数量',
    `new_user_count`  BIGINT COMMENT '新增用户数量',
    `retention_rate`  DECIMAL(16, 2) COMMENT '留存率'
) COMMENT '用户留存率'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_retention/';


insert overwrite table ads_user_retention
select * from ads_user_retention
union
select
    '2020-06-14' dt,
    login_date_first create_date,
    datediff('2020-06-14',login_date_first) retention_day,
    sum(if(login_date_last='2020-06-14',1,0)) retention_count,
    count(*) new_user_count,
    cast(sum(if(login_date_last='2020-06-14',1,0))/count(*)*100 as decimal(16,2)) retention_rate
from
(
    select
        user_id,
        date_id login_date_first
    from dwd_user_register_inc
    where dt>=date_add('2020-06-14',-7)
    and dt<'2020-06-14'
)t1
join
(
    select
        user_id,
        login_date_last
    from dws_user_user_login_td
    where dt='2020-06-14'
)t2
on t1.user_id=t2.user_id
group by login_date_first;


SELECT* FROM ads_user_retention;

DROP TABLE IF EXISTS ads_user_stats;
CREATE EXTERNAL TABLE ads_user_stats
(
    `dt`                STRING COMMENT '统计日期',
    `recent_days`       BIGINT COMMENT '最近n日,1:最近1日,7:最近7日,30:最近30日',
    `new_user_count`    BIGINT COMMENT '新增用户数',
    `active_user_count` BIGINT COMMENT '活跃用户数'
) COMMENT '用户新增活跃统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_stats/';


insert overwrite table ads_user_stats
select * from ads_user_stats
union
select
    '2020-06-14' dt,
    t1.recent_days,
    new_user_count,
    active_user_count
from
(
    select
        recent_days,
        sum(if(login_date_last>=date_add('2020-06-14',-recent_days+1),1,0)) new_user_count
    from dws_user_user_login_td lateral view explode(array(1,7,30)) tmp as recent_days
    where dt='2020-06-14'
    group by recent_days
)t1
join
(
    select
        recent_days,
        sum(if(date_id>=date_add('2020-06-14',-recent_days+1),1,0)) active_user_count
    from dwd_user_register_inc lateral view explode(array(1,7,30)) tmp as recent_days
    group by recent_days
)t2
on t1.recent_days=t2.recent_days;

select * from ads_user_stats;

DROP TABLE IF EXISTS ads_user_action;
CREATE EXTERNAL TABLE ads_user_action
(
    `dt`                STRING COMMENT '统计日期',
    `recent_days`       BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `home_count`        BIGINT COMMENT '浏览首页人数',
    `good_detail_count` BIGINT COMMENT '浏览商品详情页人数',
    `cart_count`        BIGINT COMMENT '加入购物车人数',
    `order_count`       BIGINT COMMENT '下单人数',
    `payment_count`     BIGINT COMMENT '支付人数'
) COMMENT '漏斗分析'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_action/';

insert overwrite table ads_user_action
select * from ads_user_action
union
select
    '2020-06-14' dt,
    page.recent_days,
    home_count,
    good_detail_count,
    cart_count,
    order_count,
    payment_count
from
(
    select
        1 recent_days,
        sum(if(page_id='home',1,0)) home_count,
        sum(if(page_id='good_detail',1,0)) good_detail_count
    from dws_traffic_page_visitor_page_view_1d
    where dt='2020-06-14'
    and page_id in ('home','good_detail')
    union all
    select
        recent_days,
        sum(if(page_id='home' and view_count>0,1,0)),
        sum(if(page_id='good_detail' and view_count>0,1,0))
    from
    (
        select
            recent_days,
            page_id,
            case recent_days
                when 7 then view_count_7d
                when 30 then view_count_30d
            end view_count
        from dws_traffic_page_visitor_page_view_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
        and page_id in ('home','good_detail')
    )t1
    group by recent_days
)page
join
(
    select
        1 recent_days,
        count(*) cart_count
    from dws_trade_user_cart_add_1d
    where dt='2020-06-14'
    union all
    select
        recent_days,
        sum(if(cart_count>0,1,0))
    from
    (
        select
            recent_days,
            case recent_days
                when 7 then cart_add_count_7d
                when 30 then cart_add_count_30d
            end cart_count
        from dws_trade_user_cart_add_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days
)cart
on page.recent_days=cart.recent_days
join
(
    select
        1 recent_days,
        count(*) order_count
    from dws_trade_user_order_1d
    where dt='2020-06-14'
    union all
    select
        recent_days,
        sum(if(order_count>0,1,0))
    from
    (
        select
            recent_days,
            case recent_days
                when 7 then order_count_7d
                when 30 then order_count_30d
            end order_count
        from dws_trade_user_order_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days
)ord
on page.recent_days=ord.recent_days
join
(
    select
        1 recent_days,
        count(*) payment_count
    from dws_trade_user_payment_1d
    where dt='2020-06-14'
    union all
    select
        recent_days,
        sum(if(order_count>0,1,0))
    from
    (
        select
            recent_days,
            case recent_days
                when 7 then payment_count_7d
                when 30 then payment_count_30d
            end order_count
        from dws_trade_user_payment_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days
)pay
on page.recent_days=pay.recent_days;

select * from ads_user_action;

DROP TABLE IF EXISTS ads_new_buyer_stats;
CREATE EXTERNAL TABLE ads_new_buyer_stats
(
    `dt`                     STRING COMMENT '统计日期',
    `recent_days`            BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `new_order_user_count`   BIGINT COMMENT '新增下单人数',
    `new_payment_user_count` BIGINT COMMENT '新增支付人数'
) COMMENT '新增交易用户统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_new_buyer_stats/';


insert overwrite table ads_new_buyer_stats
select * from ads_new_buyer_stats
union
select
    '2020-06-14',
    odr.recent_days,
    new_order_user_count,
    new_payment_user_count
from
(
    select
        recent_days,
        sum(if(order_date_first>=date_add('2020-06-14',-recent_days+1),1,0)) new_order_user_count
    from dws_trade_user_order_td lateral view explode(array(1,7,30)) tmp as recent_days
    where dt='2020-06-14'
    group by recent_days
)odr
join
(
    select
        recent_days,
        sum(if(payment_date_first>=date_add('2020-06-14',-recent_days+1),1,0)) new_payment_user_count
    from dws_trade_user_payment_td lateral view explode(array(1,7,30)) tmp as recent_days
    where dt='2020-06-14'
    group by recent_days
)pay
on odr.recent_days=pay.recent_days;


select * from ads_new_buyer_stats;


DROP TABLE IF EXISTS ads_repeat_purchase_by_tm;
CREATE EXTERNAL TABLE ads_repeat_purchase_by_tm
(
    `dt`                STRING COMMENT '统计日期',
    `recent_days`       BIGINT COMMENT '最近天数,7:最近7天,30:最近30天',
    `tm_id`             STRING COMMENT '品牌ID',
    `tm_name`           STRING COMMENT '品牌名称',
    `order_repeat_rate` DECIMAL(16, 2) COMMENT '复购率'
) COMMENT '各品牌复购率统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_repeat_purchase_by_tm/';



insert overwrite table ads_repeat_purchase_by_tm
select * from ads_repeat_purchase_by_tm
union
select
    '2020-06-14' dt,
    recent_days,
    tm_id,
    tm_name,
    cast(sum(if(order_count>=2,1,0))/sum(if(order_count>=1,1,0)) as decimal(16,2))
from
(
    select
        '2020-06-14' dt,
        recent_days,
        user_id,
        tm_id,
        tm_name,
        sum(order_count) order_count
    from
    (
        select
            recent_days,
            user_id,
            tm_id,
            tm_name,
            case recent_days
                when 7 then order_count_7d
                when 30 then order_count_30d
            end order_count
        from dws_trade_user_sku_order_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days,user_id,tm_id,tm_name
)t2
group by recent_days,tm_id,tm_name;

select * from ads_repeat_purchase_by_tm;


DROP TABLE IF EXISTS ads_trade_stats_by_tm;
CREATE EXTERNAL TABLE ads_trade_stats_by_tm
(
    `dt`                      STRING COMMENT '统计日期',
    `recent_days`             BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `tm_id`                   STRING COMMENT '品牌ID',
    `tm_name`                 STRING COMMENT '品牌名称',
    `order_count`             BIGINT COMMENT '订单数',
    `order_user_count`        BIGINT COMMENT '订单人数',
    `order_refund_count`      BIGINT COMMENT '退单数',
    `order_refund_user_count` BIGINT COMMENT '退单人数'
) COMMENT '各品牌商品交易统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_trade_stats_by_tm/';



set hive.vectorized.execution.enabled = false;
set hive.vectorized.execution.reduce.enabled = false;

insert overwrite table ads_trade_stats_by_tm
select * from ads_trade_stats_by_tm
union
select
    '2020-06-14' as dt,
    nvl(odr.recent_days, refund.recent_days) as recent_days,
    nvl(odr.tm_id, refund.tm_id) as tm_id,
    nvl(odr.tm_name, refund.tm_name) as tm_name,
    nvl(order_count, 0) as order_count,
    nvl(order_user_count, 0) as order_user_count,
    nvl(order_refund_count, 0) as order_refund_count,
    nvl(order_refund_user_count, 0) as order_refund_user_count
from
(
    select
        1 as recent_days,
        tm_id,
        tm_name,
        sum(order_count_1d) as order_count,
        count(distinct user_id) as order_user_count
    from dws_trade_user_sku_order_1d
    where dt='2020-06-14'
    group by tm_id, tm_name
    union all
    select
        recent_days,
        tm_id,
        tm_name,
        sum(order_count) as order_count,
        count(distinct if(order_count > 0, user_id, null)) as order_user_count
    from
    (
        select
            recent_days,
            user_id,
            tm_id,
            tm_name,
            case recent_days
                when 7 then order_count_7d
                when 30 then order_count_30d
            end as order_count
        from dws_trade_user_sku_order_nd 
        lateral view explode(array(7, 30)) tmp as recent_days
        where dt='2020-06-14'
    ) t1
    group by recent_days, tm_id, tm_name
) odr
full outer join
(
    select
        1 as recent_days,
        tm_id,
        tm_name,
        sum(order_refund_count_1d) as order_refund_count,
        count(distinct user_id) as order_refund_user_count
    from dws_trade_user_sku_order_refund_1d
    where dt='2020-06-14'
    group by tm_id, tm_name
    union all
    select
        recent_days,
        tm_id,
        tm_name,
        sum(order_refund_count) as order_refund_count,
        count(if(order_refund_count > 0, user_id, null)) as order_refund_user_count
    from
    (
        select
            recent_days,
            user_id,
            tm_id,
            tm_name,
            case recent_days
                when 7 then order_refund_count_7d
                when 30 then order_refund_count_30d
            end as order_refund_count
        from dws_trade_user_sku_order_refund_nd 
        lateral view explode(array(7, 30)) tmp as recent_days
        where dt='2020-06-14'
    ) t1
    group by recent_days, tm_id, tm_name
) refund
on odr.recent_days = refund.recent_days
and odr.tm_id = refund.tm_id
and odr.tm_name = refund.tm_name;


SELECT * FROM ads_trade_stats_by_tm;


DROP TABLE IF EXISTS ads_trade_stats_by_cate;
CREATE EXTERNAL TABLE ads_trade_stats_by_cate
(
    `dt`                      STRING COMMENT '统计日期',
    `recent_days`             BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `category1_id`            STRING COMMENT '一级分类id',
    `category1_name`          STRING COMMENT '一级分类名称',
    `category2_id`            STRING COMMENT '二级分类id',
    `category2_name`          STRING COMMENT '二级分类名称',
    `category3_id`            STRING COMMENT '三级分类id',
    `category3_name`          STRING COMMENT '三级分类名称',
    `order_count`             BIGINT COMMENT '订单数',
    `order_user_count`        BIGINT COMMENT '订单人数',
    `order_refund_count`      BIGINT COMMENT '退单数',
    `order_refund_user_count` BIGINT COMMENT '退单人数'
) COMMENT '各分类商品交易统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_trade_stats_by_cate/';


insert overwrite table ads_trade_stats_by_cate
select * from ads_trade_stats_by_cate
union
select
    '2020-06-14' dt,
    nvl(odr.recent_days,refund.recent_days),
    nvl(odr.category1_id,refund.category1_id),
    nvl(odr.category1_name,refund.category1_name),
    nvl(odr.category2_id,refund.category2_id),
    nvl(odr.category2_name,refund.category2_name),
    nvl(odr.category3_id,refund.category3_id),
    nvl(odr.category3_name,refund.category3_name),
    nvl(order_count,0),
    nvl(order_user_count,0),
    nvl(order_refund_count,0),
    nvl(order_refund_user_count,0)
from
(
    select
        1 recent_days,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        sum(order_count_1d) order_count,
        count(distinct(user_id)) order_user_count
    from dws_trade_user_sku_order_1d
    where dt='2020-06-14'
    group by category1_id,category1_name,category2_id,category2_name,category3_id,category3_name
    union all
    select
        recent_days,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        sum(order_count),
        count(distinct(if(order_count>0,user_id,null)))
    from
    (
        select
            recent_days,
            user_id,
            category1_id,
            category1_name,
            category2_id,
            category2_name,
            category3_id,
            category3_name,
            case recent_days
                when 7 then order_count_7d
                when 30 then order_count_30d
            end order_count
        from dws_trade_user_sku_order_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days,category1_id,category1_name,category2_id,category2_name,category3_id,category3_name
)odr
full outer join
(
    select
        1 recent_days,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        sum(order_refund_count_1d) order_refund_count,
        count(distinct(user_id)) order_refund_user_count
    from dws_trade_user_sku_order_refund_1d
    where dt='2020-06-14'
    group by category1_id,category1_name,category2_id,category2_name,category3_id,category3_name
    union all
    select
        recent_days,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        sum(order_refund_count),
        count(distinct(if(order_refund_count>0,user_id,null)))
    from
    (
        select
            recent_days,
            user_id,
            category1_id,
            category1_name,
            category2_id,
            category2_name,
            category3_id,
            category3_name,
            case recent_days
                when 7 then order_refund_count_7d
                when 30 then order_refund_count_30d
            end order_refund_count
        from dws_trade_user_sku_order_refund_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days,category1_id,category1_name,category2_id,category2_name,category3_id,category3_name
)refund
on odr.recent_days=refund.recent_days
and odr.category1_id=refund.category1_id
and odr.category1_name=refund.category1_name
and odr.category2_id=refund.category2_id
and odr.category2_name=refund.category2_name
and odr.category3_id=refund.category3_id
and odr.category3_name=refund.category3_name;


select * from ads_trade_stats_by_cate;

DROP TABLE IF EXISTS ads_sku_cart_num_top3_by_cate;
CREATE EXTERNAL TABLE ads_sku_cart_num_top3_by_cate
(
    `dt`             STRING COMMENT '统计日期',
    `category1_id`   STRING COMMENT '一级分类ID',
    `category1_name` STRING COMMENT '一级分类名称',
    `category2_id`   STRING COMMENT '二级分类ID',
    `category2_name` STRING COMMENT '二级分类名称',
    `category3_id`   STRING COMMENT '三级分类ID',
    `category3_name` STRING COMMENT '三级分类名称',
    `sku_id`         STRING COMMENT '商品id',
    `sku_name`       STRING COMMENT '商品名称',
    `cart_num`       BIGINT COMMENT '购物车中商品数量',
    `rk`             BIGINT COMMENT '排名'
) COMMENT '各分类商品购物车存量Top10'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_sku_cart_num_top3_by_cate/';


insert overwrite table ads_sku_cart_num_top3_by_cate
select * from ads_sku_cart_num_top3_by_cate
union
select
    '2020-06-14' dt,
    category1_id,
    category1_name,
    category2_id,
    category2_name,
    category3_id,
    category3_name,
    sku_id,
    sku_name,
    cart_num,
    rk
from
(
    select
        sku_id,
        sku_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        cart_num,
        rank() over (partition by category1_id,category2_id,category3_id order by cart_num desc) rk
    from
    (
        select
            sku_id,
            sum(sku_num) cart_num
        from dwd_trade_cart_full
        where dt='2020-06-14'
        group by sku_id
    )cart
    left join
    (
        select
            id,
            sku_name,
            category1_id,
            category1_name,
            category2_id,
            category2_name,
            category3_id,
            category3_name
        from dim_sku_full
        where dt='2020-06-14'
    )sku
    on cart.sku_id=sku.id
)t1
where rk<=3;


DROP TABLE IF EXISTS ads_trade_stats;
CREATE EXTERNAL TABLE ads_trade_stats
(
    `dt`                      STRING COMMENT '统计日期',
    `recent_days`             BIGINT COMMENT '最近天数,1:最近1日,7:最近7天,30:最近30天',
    `order_total_amount`      DECIMAL(16, 2) COMMENT '订单总额,GMV',
    `order_count`             BIGINT COMMENT '订单数',
    `order_user_count`        BIGINT COMMENT '下单人数',
    `order_refund_count`      BIGINT COMMENT '退单数',
    `order_refund_user_count` BIGINT COMMENT '退单人数'
) COMMENT '交易统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_trade_stats/';


insert overwrite table ads_trade_stats
select * from ads_trade_stats
union
select
    '2020-06-14',
    odr.recent_days,
    order_total_amount,
    order_count,
    order_user_count,
    order_refund_count,
    order_refund_user_count
from
(
    select
        1 recent_days,
        sum(order_total_amount_1d) order_total_amount,
        sum(order_count_1d) order_count,
        count(*) order_user_count
    from dws_trade_user_order_1d
    where dt='2020-06-14'
    union all
    select
        recent_days,
        sum(order_total_amount),
        sum(order_count),
        sum(if(order_count>0,1,0))
    from
    (
        select
            recent_days,
            case recent_days
                when 7 then order_total_amount_7d
                when 30 then order_total_amount_30d
            end order_total_amount,
            case recent_days
                when 7 then order_count_7d
                when 30 then order_count_30d
            end order_count
        from dws_trade_user_order_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days
)odr
join
(
    select
        1 recent_days,
        sum(order_refund_count_1d) order_refund_count,
        count(*) order_refund_user_count
    from dws_trade_user_order_refund_1d
    where dt='2020-06-14'
    union all
    select
        recent_days,
        sum(order_refund_count),
        sum(if(order_refund_count>0,1,0))
    from
    (
        select
            recent_days,
            case recent_days
                when 7 then order_refund_count_7d
                when 30 then order_refund_count_30d
            end order_refund_count
        from dws_trade_user_order_refund_nd lateral view explode(array(7,30)) tmp as recent_days
        where dt='2020-06-14'
    )t1
    group by recent_days
)refund
on odr.recent_days=refund.recent_days;


DROP TABLE IF EXISTS ads_order_by_province;
CREATE EXTERNAL TABLE ads_order_by_province
(
    `dt`                 STRING COMMENT '统计日期',
    `recent_days`        BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `province_id`        STRING COMMENT '省份ID',
    `province_name`      STRING COMMENT '省份名称',
    `area_code`          STRING COMMENT '地区编码',
    `iso_code`           STRING COMMENT '国际标准地区编码',
    `iso_code_3166_2`    STRING COMMENT '国际标准地区编码',
    `order_count`        BIGINT COMMENT '订单数',
    `order_total_amount` DECIMAL(16, 2) COMMENT '订单金额'
) COMMENT '各地区订单统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_by_province/';


insert overwrite table ads_order_by_province
select * from ads_order_by_province
union
select
    '2020-06-14' dt,
    1 recent_days,
    province_id,
    province_name,
    area_code,
    iso_code,
    iso_3166_2,
    order_count_1d,
    order_total_amount_1d
from dws_trade_province_order_1d
where dt='2020-06-14'
union
select
    '2020-06-14' dt,
    recent_days,
    province_id,
    province_name,
    area_code,
    iso_code,
    iso_3166_2,
    sum(order_count),
    sum(order_total_amount)
from
(
    select
        recent_days,
        province_id,
        province_name,
        area_code,
        iso_code,
        iso_3166_2,
        case recent_days
            when 7 then order_count_7d
            when 30 then order_count_30d
        end order_count,
        case recent_days
            when 7 then order_total_amount_7d
            when 30 then order_total_amount_30d
        end order_total_amount
    from dws_trade_province_order_nd lateral view explode(array(7,30)) tmp as recent_days
    where dt='2020-06-14'
)t1
group by recent_days,province_id,province_name,area_code,iso_code,iso_3166_2;


DROP TABLE IF EXISTS ads_coupon_stats;
CREATE EXTERNAL TABLE ads_coupon_stats
(
    `dt`          STRING COMMENT '统计日期',
    `coupon_id`   STRING COMMENT '优惠券ID',
    `coupon_name` STRING COMMENT '优惠券名称',
    `start_date`  STRING COMMENT '发布日期',
    `rule_name`   STRING COMMENT '优惠规则，例如满100元减10元',
    `reduce_rate` DECIMAL(16, 2) COMMENT '补贴率'
) COMMENT '优惠券统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_coupon_stats/';

insert overwrite table ads_coupon_stats
select * from ads_coupon_stats
union
select
    '2020-06-14' dt,
    coupon_id,
    coupon_name,
    start_date,
    coupon_rule,
    cast(coupon_reduce_amount_30d/original_amount_30d as decimal(16,2))
from dws_trade_coupon_order_nd
where dt='2020-06-14';

DROP TABLE IF EXISTS ads_activity_stats;
CREATE EXTERNAL TABLE ads_activity_stats
(
    `dt`            STRING COMMENT '统计日期',
    `activity_id`   STRING COMMENT '活动ID',
    `activity_name` STRING COMMENT '活动名称',
    `start_date`    STRING COMMENT '活动开始日期',
    `reduce_rate`   DECIMAL(16, 2) COMMENT '补贴率'
) COMMENT '活动统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_activity_stats/';

insert overwrite table ads_activity_stats
select * from ads_activity_stats
union
select
    '2020-06-14' dt,
    activity_id,
    activity_name,
    start_date,
    cast(activity_reduce_amount_30d/original_amount_30d as decimal(16,2))
from dws_trade_activity_order_nd
where dt='2020-06-14';



