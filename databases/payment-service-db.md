```mermaid
erDiagram
    Patient {
        int id PK
        string external_patient_id
        string full_name
        string id_number
        string phone
    }

    CashTransaction {
        int id PK
        string type
        decimal amount
        string payment_method
        string description
        date transaction_date
        string category
    }

    PackageSale {
        int id PK
        int patient_id FK
        date sale_date
        decimal base_price
        bool vat_included
        decimal vat_amount
        bool discount_applied
        decimal discount_amount
        decimal total_amount
        string status
        bool informed_consent_signed
    }

    Installment {
        int id PK
        int sale_id FK
        decimal amount
        date payment_date
        string payment_method
        bool is_initial_payment
    }

    Referrer {
        int id PK
        string name
        string type
        string phone
        string payment_info
        decimal default_commission_amount
    }

    CommissionRecord {
        int id PK
        int referrer_id FK
        string patient_id
        decimal amount
        date commission_date
        string status
        date payment_date
    }

    FixedExpense {
        int id PK
        string category
        string description
        decimal amount
        date expense_date
        bool is_paid
        date payment_date
    }

    Patient ||--o{ PackageSale : "buys"
    PackageSale ||--o{ Installment : "paid in"
    Referrer ||--o{ CommissionRecord : "earns"

```