# SQL lite database

#### `projects`
```sql
id INTEGER PRIMARY KEY
name TEXT NOT NULL
description TEXT
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
```

#### `groups`
```sql
id INTEGER PRIMARY KEY
project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE
name TEXT NOT NULL
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
```

#### `group_metadata`
```sql
id INTEGER PRIMARY KEY
group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE
field_name TEXT NOT NULL
field_value TEXT
updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
UNIQUE(group_id, field_name)
```

#### `files`
```sql
id INTEGER PRIMARY KEY
file_path TEXT NOT NULL
file_name TEXT NOT NULL
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
UNIQUE(file_path, file_name)
```

#### `project_files` (many-to-many)
```sql
project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE
file_id INTEGER NOT NULL REFERENCES files(id) ON DELETE CASCADE
group_id INTEGER REFERENCES groups(id) ON DELETE SET NULL
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
PRIMARY KEY (project_id, file_id)
```

#### `file_metadata`
```sql
id INTEGER PRIMARY KEY
file_id INTEGER REFERENCES files(id) ON DELETE SET NULL
field_name TEXT NOT NULL
field_value TEXT
updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
UNIQUE(file_id, field_name)
```

#### `analysis_results`
```sql
id INTEGER PRIMARY KEY
file_id INTEGER REFERENCES files(id) ON DELETE SET NULL
module_name TEXT NOT NULL
module_display_name TEXT
module_description TEXT
analysis_timestamp BIGINT NOT NULL
report_path TEXT NOT NULL
parameters_json TEXT
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
```

#### `analysis_scripts`
```sql
id INTEGER PRIMARY KEY
name TEXT NOT NULL
script_path TEXT NOT NULL
description TEXT
UNIQUE(script_path)
```

#### `result_scripts` 
```sql
result_id INTEGER NOT NULL REFERENCES analysis_results(id) ON DELETE CASCADE
script_id INTEGER NOT NULL REFERENCES analysis_scripts(id) ON DELETE CASCADE
PRIMARY KEY (result_id, script_id)
```

## Table Relationships

```mermaid
erDiagram
    projects ||--o{ groups : "has"
    groups ||--o{ group_metadata : "has"
    projects ||--o{ project_files : "has"
    files ||--o{ project_files : "belongs to"
    groups ||--o| project_files : "optional"
    files ||--o{ file_metadata : "has"
    files ||--o{ analysis_results : "has"
    analysis_results ||--o{ result_scripts : "optional"
    analysis_scripts ||--o{ result_scripts : "used in"
    
    projects {
        INTEGER id PK
        TEXT name
        TEXT description
        DATETIME created_at
        DATETIME updated_at
    }
    
    groups {
        INTEGER id PK
        INTEGER project_id FK
        TEXT name
        DATETIME created_at
    }
    
    group_metadata {
        INTEGER id PK
        INTEGER group_id FK
        TEXT field_name
        TEXT field_value
        DATETIME updated_at
    }
    
    files {
        INTEGER id PK
        TEXT file_path
        TEXT file_name
        DATETIME created_at
    }
    
    project_files {
        INTEGER project_id PK,FK
        INTEGER file_id PK,FK
        INTEGER group_id FK
        DATETIME created_at
    }
    
    file_metadata {
        INTEGER id PK
        INTEGER file_id FK
        TEXT field_name
        TEXT field_value
        DATETIME updated_at
    }
    
    analysis_results {
        INTEGER id PK
        INTEGER file_id FK
        TEXT module_name
        TEXT module_display_name
        TEXT module_description
        BIGINT analysis_timestamp
        TEXT report_path
        TEXT parameters_json
        DATETIME created_at
    }
    
    analysis_scripts {
        INTEGER id PK
        TEXT name
        TEXT script_path
        TEXT description
    }
    
    result_scripts {
        INTEGER result_id PK,FK
        INTEGER script_id PK,FK
    }
```
