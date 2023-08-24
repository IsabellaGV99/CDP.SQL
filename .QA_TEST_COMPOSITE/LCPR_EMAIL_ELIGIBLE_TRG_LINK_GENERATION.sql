WITH CROSS_ELIGIBLE AS(
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
        bill_code AS pck_code_csr,
        res_name_sbb AS CUST_NAME,
        tenure
            from "prod"."public"."lcpr_dna_fixed"
   WHERE AS_OF = (select max(as_of) from "prod"."public"."lcpr_dna_fixed")
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

RS_view_attributes as (
     SELECT 
         *
     FROM "prod"."public"."lcpr_customer_service_features"
 ),

 offers as (
    SELECT 
        *
    FROM "prod"."public"."lcpr_offers"

),

migrations as (
    select 
        CAST(DATEADD(SECOND, ls_chg_dte_ocr_ms/1000,'1970/1/1') AS DATE) AS chg_date_ocr,
        *
    from  "prod"."public"."lcpr_last_transaction_orderactivity"
),

retargeting_suppres as (
    select 
        numero_cuenta as retargeting_Account_id,
        *
    from csr_attributes left join migrations on numero_cuenta = migrations.account_id
    where 
        chg_date_ocr  >=  DATEADD(month, -3, CURRENT_DATE) or
        tenure <= 0.5
),

source_qualify as (
    SELECT 
        *
    FROM 
    (
    select 
    *
    from (
        select 
            CSR.*, FLG.*
        from csr_attributes CSR left join flagging_attributes FLG on CSR.numero_cuenta = FLG.account_id 
    )  CSR_FLG LEFT JOIN RS_view_attributes ON CSR_FLG.numero_cuenta = RS_view_attributes.account_id
    ) CSR_FLAG_RSVIEW LEFT JOIN offers ON CSR_FLAG_RSVIEW.numero_cuenta = offers.account_id


    where 
        -- CONDICIONES CROSS_CUST_ATTRIBUTES 
        -- condiciones de CSR
        valid_pckg = true  and 
        joint_cust = false and 
        welcome_off = false and 
        subsidize_fl = false and 
        CUST_TYPE = 'RES' and

        -- condicion offers
        pck_code_csr = pkg_cde and 
        -- condiciones de la vista de RS
        num_accounts = 1 
        and

        -- CONDICIONES CROSS_BEHAVIOUR

        -- condición de CSR
        delinquency_days < 50   and
        -- condición de flagging
        (open_order = false  or open_order is null) and
        (trouble_call = false  or trouble_call is null) 
)
SELECT
        DISTINCT source_qualify.numero_cuenta
FROM source_qualify left join retargeting_suppres on source_qualify.numero_cuenta = retargeting_suppres.retargeting_Account_id
where retargeting_suppres.retargeting_Account_id is null)
,

-- SINGLE OFFER ELIGIBLE

SINGLE_OFFER_ELIGIBLE AS(
    WITH
csr_attributes as(
    SELECT 
        account_id as numero1
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
    distinct CSR_FLAGG.numero1
FROM 
(SELECT 
    *
FROM csr_attributes LEFT JOIN flagging_attributes 
ON csr_attributes.numero1 = flagging_attributes.account_id) CSR_FLAGG LEFT JOIN offers ON CSR_FLAGG.numero1 = offers.num_id
WHERE 
    --condiciones offers
    lower(offers.offer_type) = 'single' and 
    offers.rank = 1 and 
    next_best_action_date= current_date AND
    
    --condiciones flagging
    (CSR_FLAGG.privacy_flag = false or CSR_FLAGG.privacy_flag is null)

)
,

--SINGLE OFFER EMAIL ELIGIBLE

SINGLE_OFFER_EMAIL_ELIGIBLE AS(

WITH
csr_attributes as(
    SELECT 
        account_id as cuenta,
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
    distinct cuenta
FROM 
(SELECT 
    *
FROM csr_attributes LEFT JOIN offers 
ON csr_attributes.cuenta = offers.num_id) CSR_OFFERS LEFT JOIN cs_features ON csr_offers.cuenta = cs_features.numero
WHERE 
    hsd=1 and
    channel = 'email' and 
    email is not null  and 
    converted_date <= period_evaluated

),

-- TARGET CUSTOMER

TARGET_CUST AS(

WITH csr_customers AS (
    SELECT 
        account_id as cuenta1,
        as_of as csr_dte,
        CASE WHEN welcome_offer = 'X' THEN true ELSE false END as welcome_offer,
        CASE WHEN acp = 'X' THEN true ELSE false END as subsidize_flag,
        CASE WHEN joint_customer = 'X' THEN true ELSE false END as joint_customer,
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
        email as email_csr,
        cust_typ_sbb AS CUST_TYPE,
        delinquency_days AS DELINQUENCY_DAYS,
        hsd AS hsd_csr,
        bill_code AS PCK_CODE,
        res_name_sbb AS CUST_NAME,
        *
    FROM "prod"."public"."insights_customer_services_rates_lcpr"
    WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),
offers as (
    SELECT 
        account_id,
        max(regime) as regime_of
    FROM "prod"."public"."lcpr_offers"
    group by 1
)
SELECT 
    Distinct csr_customers.cuenta1
FROM csr_customers LEFT JOIN offers ON csr_customers.cuenta1 = offers.account_id
WHERE lower(offers.regime_of)= 'offerfit'

)
,

-- EMAIL RETARGETING
EMAIL_RET AS(

WITH csr_attributes as ( 
SELECT  
account_id as account, 
as_of as csr_dte 
from "prod"."public"."insights_customer_services_rates_lcpr" 
WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr"))

, 

LAST_COMMS_42 AS ( 
    SELECT  
        account_id,
        lst_cc_out_sent_dt, 
        CAST(DATEADD(SECOND, lst_cc_out_sent_dt/1000,'1970/1/1') AS DATE) AS date,
        CURRENT_DATE - 42 AS period,
        CASE WHEN date >= period then true else false end as condition
    FROM 
         "prod"."public"."lcpr_last_comms")


,
LAST_COMMS_1M AS ( 
SELECT 
account_id, 
lst_cc_out_contacted_dt, 
lst_cc_out_sent_dt, 
CAST(DATEADD(SECOND, lst_cc_out_contacted_dt/1000,'1970/1/1') AS DATE) AS date_contacted, 
CAST(DATEADD(SECOND, lst_cc_out_sent_dt/1000,'1970/1/1') AS DATE) AS date_sent, 
ADD_MONTHS(current_date,-1) AS min_date, 
CASE WHEN date_contacted >=min_date then true else false end as condition1, 
CASE WHEN date_sent >=min_date then true else false end as condition2 
FROM "prod"."public"."lcpr_last_comms") 

,


LAST_COMMS_21 AS ( 
    SELECT
        account_id,
        lst_email_sent_dt, 
        CAST(DATEADD(SECOND, lst_email_sent_dt/1000,'1970/1/1') AS DATE) AS date,
        CURRENT_DATE - 21 AS period,
        CASE WHEN date >= period then true else false end as condition
    FROM 
         "prod"."public"."lcpr_last_comms"
) 


SELECT
DISTINCT a.account
From csr_attributes a
Left JOIN LAST_COMMS_42 b ON a.account = b.account_id
Left JOIN LAST_COMMS_1M c ON a.account = c.account_id
Left JOIN LAST_COMMS_21 d ON a.account = d.account_id
Where 
    -- out_call_sent_6_weeks
    b.condition = true  
    or
    -- out_Call_contacted_1_mont
    (c.condition1 =true and c.condition2 =true ) 
    or  
    -- -- email sent v3 weeks
    d.condition =true

)
,

-- SIDEGRADE RETARGETING

SIDEGRADE_RET AS(

with
csr_attributes as (
    SELECT 
        account_id as account_id_num,
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
   distinct account_id_num
from csr_attributes CSR left join TO_AWS TORDER on CSR.account_id_num = TORDER.numero
WHERE 
     migration_dte >= DATEADD(month, -6, CURRENT_DATE)

)

SELECT
COUNT(DISTINCT a.numero_cuenta)
From CROSS_ELIGIBLE a
INNER JOIN SINGLE_OFFER_ELIGIBLE b ON a.numero_cuenta = b.numero1
FULL OUTER JOIN SINGLE_OFFER_EMAIL_ELIGIBLE c ON a.numero_cuenta = c.cuenta
FULL OUTER JOIN TARGET_CUST d ON a.numero_cuenta = d.cuenta1
Left JOIN EMAIL_RET e ON a.numero_cuenta = e.account 
Left JOIN SIDEGRADE_RET f ON a.numero_cuenta = f.account_id_num 
WHERE e.account is null and f.account_id_num is null
