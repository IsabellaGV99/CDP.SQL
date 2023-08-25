-- LCPR_CROSS_CUST_BEHAVIOUR Redshift
with
csr_attributes as (
    SELECT 
        account_id as numero_cuenta,
        sub_acct_no_sbb as cust_acct,
        as_of as csr_dte,
        CASE WHEN welcome_offer = 'X' THEN true ELSE false END as welcome_off,
        CASE WHEN acp = 'X' THEN true ELSE false END as subsidize_fl,
        CASE WHEN joint_customer = 'X' THEN true ELSE false END as joint_cust,
        CASE 
            WHEN  
                substring(bill_code ,1,1) IN ('R','F') AND 
                substring(bill_code ,2,1) IN ('1','2','3','4','5','6','7') 
                THEN true ELSE false END    as valid_pckg,
        CASE 
            WHEN substring(cast(sub_acct_no_sbb as varchar)  , length(cast(sub_acct_no_sbb as varchar)  )-1,2) in ('24', '99', '67', '41', '19') then 'Control A'
            WHEN substring(cast(sub_acct_no_sbb as varchar)  , length(cast(sub_acct_no_sbb as varchar)  )-1,2) in ('25', '47', '79', '22', '93') then 'Control X' 
            WHEN  substring(cast(sub_acct_no_sbb as varchar)  , length(cast(sub_acct_no_sbb as varchar)   )-1,2) in ('26', '48', '80', '23', '94') then 'Control J' ELSE 'Target'
        END as regime,
        addr1_hse as CUST_ADDR1,
        home_phone_sbb as PHONE_1,
        bus_phone_sbb as PHONE_2,
        cyc_cde_sbb as INVOICE_DAY,
        email as EMAIL,
        cust_typ_sbb AS CUST_TYPE,
        delinquency_days AS DELINQUENCY_DAYS,
        hsd AS HSD,
        bill_code AS PCK_CODE,
        res_name_sbb AS CUST_NAME
            from "prod"."public"."insights_customer_services_rates_lcpr"
   WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
    -- limit 100
),

flagging_attributes as (
select 
    *,
    -- sub_acct_no_sbb as cust_acct,
    case when has_privacy_flag = 'X' then true else false end as privacy_flag ,
    case when has_open_order  = 'X' then true else false end as open_order ,
    case when pending_tc  = 'X' then true else false end as trouble_call ,
    case when is_in_ndnc  = 'X' then true else false end as dnt_call_flag
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
    CSR_FLG.delinquency_days <= 50   and
    -- condición de flagging
    CSR_FLG.open_order = false   and
    CSR_FLG.trouble_call = false  and
    -- condición vista de redshift
    RS_view.change_hsd_speed = false
