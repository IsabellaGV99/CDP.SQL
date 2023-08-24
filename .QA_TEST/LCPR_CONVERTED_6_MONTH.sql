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
TO_AWS AS (
    SELECT
        account_id AS numero,
        CASE WHEN lower(ord_typ) IN ('downgrade', 'upgrade', 'sidegrade') THEN ls_chg_dte_ocr ELSE null END AS migration_dte,
        ord_typ
    FROM 
        "prod"."public"."transactions_orderactivity"
)
select 
    -- numero_cuenta,
    -- migration_dte
   count(distinct numero_cuenta)
from (
select 
    *
from csr_attributes CSR left join TO_AWS TORDER on CSR.numero_cuenta = TORDER.numero
)  CSR_TO
WHERE 
     migration_dte >= DATEADD(month, -6, CURRENT_DATE)
