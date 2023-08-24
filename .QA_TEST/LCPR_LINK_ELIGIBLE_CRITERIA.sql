
  
WITH 
csr_customers AS (
    SELECT 
        account_id as numero_cuenta,
        sub_acct_no_sbb as cust_acct
    FROM "prod"."public"."insights_customer_services_rates_lcpr"
    WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),
offers as (
    SELECT 
        account_id,
        link,
        link_dt,
        CAST(DATEADD(SECOND, link_dt/1000,'1970/1/1') AS DATE) AS link_date,
       current_date-7 AS min_link_date,
       case when link_date >= min_link_date then true else false end AS test_link_dt,
        link_exp_dt,
        CAST(DATEADD(SECOND, link_exp_dt/1000,'1970/1/1') AS DATE) AS link_exp_date,
        current_date+7 AS min_link_exp_date,
         case when link_exp_date >= min_link_exp_date then true else false end,
        current_date+15 AS max_link_exp_date,
         case when link_exp_date <= max_link_exp_date then true else false end,
         case when link_exp_date >= min_link_exp_date and link_exp_date <= max_link_exp_date then true else false end as test_link_exp_date
    FROM "prod"."public"."lcpr_offers"
)

SELECT 
    count(distinct numero_cuenta)
FROM
csr_customers A
LEFT JOIN offers B
on  a.numero_cuenta = b.account_id 
WHERE 
   link is not null and
    test_link_dt =true and
    test_link_exp_date =true
