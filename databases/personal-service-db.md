erDiagram
    employee {
        int id PK
        string first_name
        string last_name
        string id_number
        string email
        string phone
        string address
        string contract_type
        int role_id FK
        int branch_id FK
        float satisfaction_level
    }

    role {
        int id PK
        string name
        json permissions
    }

    branch {
        int id PK
        string name
        string address
        string hours_of_operation
    }

    specialization {
        int id PK
        string name
    }

    employee_specialization {
        int employee_id FK
        int specialization_id FK
    }

    shift_assignment {
        int id PK
        int employee_id FK
        int branch_id FK
        string days_of_week
        time start_time
        time end_time
    }

    attendance {
        int id PK
        int employee_id FK
        int branch_id FK
        datetime clock_in
        datetime clock_out
        int tardiness_minutes
        bool is_absent
        string registration_method
    }

    exception {
        int id PK
        int employee_id FK
        string reason
        date start_date
        date end_date
        int committed_hours
        string approval_status
    }

    employee ||--o{ branch : "works_at"
    employee ||--o{ role : "has"
    employee ||--o{ employee_specialization : "has"
    specialization ||--o{ employee_specialization : "assigned_to"
    employee ||--o{ shift_assignment : "assigned"
    branch ||--o{ shift_assignment : "location"
    employee ||--o{ attendance : "registers"
    employee ||--o{ exception : "has"