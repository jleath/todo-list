CREATE TABLE lists (
    id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text UNIQUE NOT NULL
);

CREATE TABLE todos (
    id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL,
    completed boolean NOT NULL DEFAULT false,
    list_id int NOT NULL REFERENCES lists (id) ON DELETE CASCADE
);