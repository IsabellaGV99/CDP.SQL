with
csr_attributes as (
    SELECT 
        account_id as numero_cuenta,
        sub_acct_no_sbb as cust_acct,
        as_of as csr_dte,
        delinquency_days AS DELINQUENCY_DAYS
            from "prod"."public"."lcpren_dna_fixed"
),
flagging_attributes as (
select 
    account_id,
    case when has_open_order  = 'X' then true else false end as open_order,
    case when pending_tc  = 'X' then true else false end as trouble_call
from "prod"."public"."flagging"
-- limit 100
),
RS_view as (
     SELECT 
         *
     FROM "prod"."public"."lcpr_customer_service_features"
 )
select 
   count(distinct CSR_FLG.numero_cuenta)
from (
select 
    CSR.*, FLG.*
from csr_attributes CSR left join flagging_attributes FLG on CSR.numero_cuenta = FLG.account_id 
)  CSR_FLG LEFT JOIN RS_view ON CSR_FLG.numero_cuenta = RS_view.account_id
where 
    -- condición de CSR
    CSR_FLG.delinquency_days < 50   and
    -- condición de flagging
    CSR_FLG.open_order = false   and
    CSR_FLG.trouble_call = false  and
    -- condición vista de redshift
    RS_view.change_hsd_speed = false
