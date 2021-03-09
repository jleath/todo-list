require 'pg'

class DatabasePersistence
  def initialize
    @db = PG.connect(dbname: 'todos')
    setup_schema
  end

  def create_new_list(list_name)
    insert_sql = 'INSERT INTO lists (name) VALUES ($1);'
    @db.exec_params(insert_sql, [list_name])
  end

  def delete_list(list_id)
    @db.exec_params("DELETE FROM lists WHERE id = $1;", [list_id])
  end

  def find_list(list_id)
    list_name = @db.exec_params("SELECT name FROM lists WHERE id = $1;", [list_id])[0]['name']
    build_list(list_id, list_name)
  end

  def all_lists
    results = @db.exec("SELECT * FROM lists;")
    results.map do |tuple|
      list_id = tuple['id']
      list_name = tuple['name']
      build_list(list_id, list_name)
    end
  end

  def update_list_name(list_id, new_name)
    update_sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    @db.exec_params(update_sql, [new_name, list_id])
  end

  def create_new_todo(list_id, todo_text)
    insert_sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2);"
    @db.exec_params(insert_sql, [todo_text, list_id])
  end

  def update_todo_status(_, todo_id, new_status)
    update_sql = "UPDATE todos SET completed = $1 WHERE id = $2;"
    @db.exec_params(update_sql, [new_status, todo_id])
  end

  def mark_all_complete(list_id)
    @db.exec_params("UPDATE todos SET completed = true WHERE list_id = $1;", [list_id])
  end

  def todo_name(_, todo_id)
    @db.exec_params("SELECT name FROM todos WHERE id = $1;", [todo_id])[0]['name']
  end

  def delete_todo(_, todo_id)
    @db.exec_params("DELETE FROM todos WHERE id = $1;", [todo_id])
  end

  private

  def build_list(id, name)
    { id: id, name: name, todos: fetch_todos(id.to_i) }
  end

  def fetch_todos(list_id)
    todo_tuples = @db.exec_params("SELECT * FROM todos WHERE list_id = $1;", [list_id])
    todo_tuples.map do |tuple|
      todo_id = tuple['id'].to_i
      todo_name = tuple['name']
      todo_complete = tuple['completed'] == 't'
      { id: todo_id, name: todo_name, completed: todo_complete }
    end
  end

  def setup_schema
    check_exists_sql = <<~SQL
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'todos';
    SQL
    if @db.exec(check_exists_sql)[0]['count'].to_i == 0
      File.open('schema.sql', 'r') { |schema_file| @db.exec(schema_file.read) }
    end
  end
end