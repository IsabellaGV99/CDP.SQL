WITH
csr_attributes as(
    SELECT 
        account_id as numero_cuenta
    from  "prod"."public"."insights_customer_services_rates_lcpr"
    WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),
flagging_attributes as (
select
    account_id,
    case when has_privacy_flag = 'X' then true else false end as privacy_flag 
from "prod"."public"."flagging"
),
offers as (
    SELECT 
        account_id AS num_id,
        offer_type,
        rank,
        next_best_action_date
    FROM "prod"."public"."lcpr_offers"
)
select 
    count(distinct CSR_FLAGG.numero_cuenta)
FROM 
(SELECT 
    *
FROM csr_attributes LEFT JOIN flagging_attributes 
ON csr_attributes.numero_cuenta = flagging_attributes.account_id) CSR_FLAGG LEFT JOIN offers ON CSR_FLAGG.numero_cuenta = offers.num_id
WHERE 
    --condiciones offers
    lower(offers.offer_type) = 'single' and 
    offers.rank = 1 and 
    next_best_action_date= current_date AND
    
    --condiciones flagging
    (CSR_FLAGG.privacy_flag = false or CSR_FLAGG.privacy_flag is null)
