# Report Service Database Schema
Aclaracion, estas tablas no son 100% obligatorias, son sugerentes, los campos pueden ser solicitados de forma dinamica desde las otras bases de datos, se recomienda su uso para emitir informes automaticamente

```mermaid
erDiagram
    DailyIncomeSummary {
        int id PK
        date report_date
        decimal total_cash_inflow
        decimal total_yape_inflow
        decimal total_invoice_amount
        decimal total_operating_expenses
        decimal net_cash_balance
    }

    MonthlyStats {
        int id PK
        int year
        int month
        int total_patients
        decimal total_income
        decimal total_vat
        int total_packages_sold
        int peak_day
    }

    PackageSaleSummary {
        int id PK
        date sale_date
        int package_sale_id
        decimal amount
        bool vat_included
        int patient_id
    }
```