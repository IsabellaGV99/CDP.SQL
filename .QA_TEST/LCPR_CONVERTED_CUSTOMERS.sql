with
csr_attributes as (
    SELECT 
        account_id as numero_cuenta,
        as_of as csr_dte
            from "prod"."public"."insights_customer_services_rates_lcpr"
   WHERE AS_OF = (select max(as_of) from "prod"."public"."insights_customer_services_rates_lcpr" )
  
),
TO_AWS AS (
    SELECT
        account_id AS numero,
        CAST(DATEADD(SECOND, ls_chg_dte_ocr_ms/1000,'1970/1/1') AS DATE) AS migr_date,
        current_date -8 AS min_date,
        CASE WHEN migr_date >= min_date then TRUE ELSE FALSE END AS condition
    FROM "prod"."public"."lcpr_last_transaction_orderactivity"
)
select 
   count(distinct CSR_TO.numero_cuenta)
from (
select 
    *
from csr_attributes CSR left join TO_AWS TORDER on CSR.numero_cuenta = TORDER.numero
)  CSR_TO
WHERE 
   condition = TRUE
