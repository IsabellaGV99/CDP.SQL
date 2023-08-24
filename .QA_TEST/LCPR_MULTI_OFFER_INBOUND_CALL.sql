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
OFFERS_ATTRIBUTES_AWS AS (
    SELECT
        account_id AS cuenta,
        pkg_cde AS from_pck_code,
        online_descr_pkg AS from_online_descr,
        smt_descr_pkg AS smt_descr_pkg,
        hsd_service AS from_hsd_speed,
        bundlecharge_csg AS from_bundle_chrg,
        bundlecharge_csg AS to_pck_code,
        tocsgcodefriendlyname AS to_hsd_speed,
        to_online_descr_pkg AS to_online_descr,
        to_smt_descr_pckg AS to_smt_descr,
        to_bundlecharge_csg AS to_bundle_chrg,
        discount AS discount,
       --- date AS dte,
        rank AS rank_order,
        stb AS stb_code,
        additional_charge AS stb_additional_chrg,
        delta_arpu AS pay_diff,
        source AS source,
        regime AS regime,
        reward AS reward,
        offer_type AS type,
        use_case AS use_case,
        channel AS channel,
        week_day AS week_day,
        next_best_action_date_ms AS next_bst_action_dte,
        time_frame AS time_frame,
        additional_param_1 AS template_type,
        additional_param_2 AS message_text,
        additional_param_3 AS call_to_action,
        additional_param_4 AS message_subject
    FROM 
        "prod"."public"."lcpr_offers"
)
select 
   count(distinct CSR_OFFERS.numero_cuenta)
from (
select 
    *
from csr_attributes CSR left join OFFERS_ATTRIBUTES_AWS OFFERS on CSR.numero_cuenta = OFFERS.cuenta 
)  CSR_OFFERS 
where 
    -- condición de offers
    CSR_OFFERS.rank_order= 1   and
    lower(CSR_OFFERS.type) = 'multiple'     and
    CSR_OFFERS.valid_pckg = TRUE 
