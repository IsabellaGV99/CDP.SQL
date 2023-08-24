WITH csr_attributes as (
    SELECT 
        account_id as numero_cuenta,
        as_of as csr_dte
            from "prod"."public"."insights_customer_services_rates_lcpr"
   WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
),
LAST_COMMS_VIEW AS (
    SELECT
        account_id,
        lst_cc_out_contacted_dt,
        lst_cc_out_sent_dt,
        CAST(DATEADD(SECOND, lst_cc_out_contacted_dt/1000,'1970/1/1') AS DATE) AS date_contacted,
        CAST(DATEADD(SECOND, lst_cc_out_sent_dt/1000,'1970/1/1') AS DATE) AS date_sent,
        ADD_MONTHS(current_date,-3) AS min_date,
        CASE WHEN date_contacted >=min_date then true else false end as condition1,
        CASE WHEN date_sent >=min_date then true else false end as condition2
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
    condition1 = true and  condition2 = true
