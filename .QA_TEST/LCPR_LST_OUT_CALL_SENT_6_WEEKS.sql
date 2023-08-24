WITH csr_attributes as (
    SELECT 
        sub_acct_no_sbb as numero_cuenta,
        as_of as csr_dte
            from "prod"."public"."insights_customer_services_rates_lcpr"
   WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),
LAST_COMMS_VIEW AS (
    SELECT
        account_id,
        lst_cc_out_sent_dt, 
        CAST(DATEADD(SECOND, lst_cc_out_sent_dt/1000,'1970/1/1') AS DATE) AS date,
        CURRENT_DATE - 42 AS period,
        CASE WHEN date >= period then true else false end as condition
    FROM 
         "prod"."public"."lcpr_last_comms"
)
SELECT 
   COUNT(DISTINCT CSR_COMMS.numero_cuenta)
FROM (
    SELECT 
        *
    FROM csr_attributes CSR
    LEFT JOIN LAST_COMMS_VIEW COMMS ON CSR.numero_cuenta = COMMS.account_ID
) CSR_COMMS
WHERE 
    condition = true
