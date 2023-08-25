-- LCPR_SINGLE_OFFER_ELIGIBLE Redshift
WITH
csr_attributes as(
    SELECT 
        account_id as numero_cuenta
    from  "prod"."public"."insights_customer_services_rates_lcpr"
    WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),

flagging_attributes as (
select 
    *,
    sub_acct_no_sbb as cust_acct,
    case when has_privacy_flag = 'X' then true else false end as privacy_flag ,
    case when has_open_order  = 'X' then true else false end as open_order ,
    case when pending_tc  = 'X' then true else false end as trouble_call ,
    case when is_in_ndnc  = 'X' then true else false end as dnt_call_flag
from "prod"."public"."flagging"
-- limit 100
),
offers as (
    SELECT 
        account_id AS num_id,
        *
    FROM "prod"."public"."lcpr_offers"

)

select 
    count(distinct CSR_FLAGG.numero_cuenta)
FROM 
(SELECT 
    *
FROM csr_attributes LEFT JOIN flagging_attributes 
ON csr_attributes.numero_cuenta = flagging_attributes.account_id) CSR_FLAGG LEFT JOIN offers ON CSR_FLAGG.numero_cuenta = offers.account_id
WHERE 
    --condiciones offers
    -- offers.next_best_action_date = and 
    lower(offers.offer_type) = 'single' and 
    offers.rank = 1 and 

    
    --condiciones flagging
    CSR_FLAGG.privacy_flag = false -- and
