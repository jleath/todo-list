# frozen_string_literal: true

require 'pg'

# A simple class that handles interactions with the todolist database.

# Example:
# storage = DatabasePersistence.new(logger)
# current_lists = storage.all_lists
# all_lists.each do |list_info|
#   todos = list_info[:todos]
#   todos.each do |todo_info|
#     puts "#{list_info[:name]: todo_info[:name]"
#   end
# end
class DatabasePersistence
  def initialize(logger)
    @logger = logger
    @db = PG.connect(dbname: 'todos')
    setup_schema
  end

  def create_new_list(list_name)
    insert_sql = 'INSERT INTO lists (name) VALUES ($1);'
    query(insert_sql, list_name)
  end

  def delete_list(list_id)
    query('DELETE FROM lists WHERE id = $1;', list_id)
  end

  def find_list(list_id)
    list_name = query('SELECT name FROM lists WHERE id = $1;', list_id)[0]['name']
    build_list(list_id, list_name)
  end

  def all_lists
    list_info = query('SELECT * FROM lists;')
    list_info.map do |list_tuple|
      build_list(list_tuple['id'], list_tuple['name'])
    end
  end

  def update_list_name(list_id, new_name)
    update_sql = 'UPDATE lists SET name = $1 WHERE id = $2;'
    query(update_sql, new_name, list_id)
  end

  def create_new_todo(list_id, todo_text)
    insert_sql = 'INSERT INTO todos (name, list_id) VALUES ($1, $2);'
    query(insert_sql, todo_text, list_id)
  end

  def update_todo_status(_, todo_id, new_status)
    update_sql = 'UPDATE todos SET completed = $1 WHERE id = $2;'
    query(update_sql, new_status, todo_id)
  end

  def mark_all_complete(list_id)
    query('UPDATE todos SET completed = true WHERE list_id = $1;', list_id)
  end

  def todo_name(_, todo_id)
    query('SELECT name FROM todos WHERE id = $1;', todo_id)[0]['name']
  end

  def delete_todo(_, todo_id)
    query('DELETE FROM todos WHERE id = $1;', todo_id)
  end

  private

  def build_list(id, name)
    { id: id, name: name, todos: fetch_todos(id.to_i) }
  end

  def fetch_todos(list_id)
    todo_tuples = query('SELECT * FROM todos WHERE list_id = $1;', list_id)
    todo_tuples.map do |todo_tuple|
      { id: todo_tuple['id'].to_i,
        name: todo_tuple['name'],
        completed: todo_tuple['completed'] == 't' }
    end
  end

  def setup_schema
    check_exists_sql = <<~SQL
      SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'todos';
    SQL
    return unless query(check_exists_sql)[0]['count'].to_i.zero?

    File.open('schema.sql', 'r') { |schema_file| query(schema_file.read) }
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}".gsub("\n", ' '))
    @db.exec(statement, params)
  end
end
