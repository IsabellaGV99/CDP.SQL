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
        *
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
    CAST(DATEADD(SECOND, link_dt/1000,'1970/1/1') AS DATE) = current_date and
    CAST(DATEADD(SECOND, link_exp_dt/1000,'1970/1/1') AS DATE) between current_date+7 and current_date + 15
