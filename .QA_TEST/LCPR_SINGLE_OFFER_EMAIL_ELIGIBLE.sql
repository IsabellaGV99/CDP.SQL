LCPR_SINGLE_OFFER_EMAIL_ELIGIBLE:
WITH
csr_attributes as(
    SELECT 
        account_id as numero_cuenta,
        *
    from  "prod"."public"."insights_customer_services_rates_lcpr"
    WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),
offers as (
    SELECT 
        account_id AS num_id,
        *
    FROM "prod"."public"."lcpr_offers"
-- limit 100
),
cs_features as (
    SELECT 
        account_id AS numero,
        lst_bill_dt, 
        CAST(DATEADD(SECOND, lst_bill_dt/1000,'1970/1/1') AS DATE) AS converted_date, 
        current_date-10 AS period_evaluated
    FROM "prod"."public"."lcpr_customer_service_features"
)
select 
    count(distinct numero_cuenta)
FROM 
(SELECT 
    *
FROM csr_attributes LEFT JOIN offers 
ON csr_attributes.numero_cuenta = offers.num_id) CSR_OFFERS LEFT JOIN cs_features ON csr_offers.numero_cuenta = cs_features.numero
WHERE 
    hsd=1 and
    channel = 'email' and 
    email is not null  and 
    converted_date <= period_evaluated
