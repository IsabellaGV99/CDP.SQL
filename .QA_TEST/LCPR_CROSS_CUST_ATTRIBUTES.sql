WITH 
csr_customers AS (
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
        res_name_sbb AS CUST_NAME,
        *
    FROM "prod"."public"."lcpr_dna_fixed"
),
offers as (
    SELECT 
        *
    FROM "prod"."public"."lcpr_offers"
),
 RS_view as (
     SELECT 
         *
     FROM "prod"."public"."lcpr_customer_service_features"
 )
SELECT 
    count(distinct numero_cuenta)
FROM
(SELECT 
    -- count(distinct a.numero_cuenta)
    A.*, B.*
FROM csr_customers A
LEFT JOIN offers B
on  a.numero_cuenta = b.account_id) C
LEFT JOIN RS_view D
ON C.numero_cuenta = D.account_id
WHERE 
    -- condiciones de CSR
    C.valid_pckg = true  and 
    C.joint_cust = false and 
    C.welcome_off = false and 
    C.subsidize_fl = false and 
    C.CUST_TYPE = 'RES' and
    -- condicion offers
    C.PCK_CODE = C.pkg_cde and 
    -- condiciones de la vista de RS
    D.num_accounts = 1

