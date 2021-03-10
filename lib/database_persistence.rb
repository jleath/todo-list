# frozen_string_literal: true

require 'pg'
require 'pry'

# A simple class that handles interactions with the todolist database.

class DatabasePersistence
  def initialize(logger)
    @logger = logger
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'todos')
          end
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
    select_query = <<~SQL
      SELECT lists.*,
             count(todos.id) as todos_count,
             count(NULLIF(todos.completed, true)) as todos_remaining_count
      FROM lists LEFT OUTER JOIN todos ON lists.id = todos.list_id
      WHERE lists.id = $1
      GROUP BY lists.id
    SQL
    list_info = query(select_query, list_id)[0]
    list = build_list(list_info)
    list[:todos] = fetch_todos(list_info['id'].to_i)
    list
  end

  def all_lists
    select_all_query = <<~SQL
      SELECT lists.*, 
             count(todos.id) as todos_count, 
             count(NULLIF(todos.completed, true)) as todos_remaining_count
      FROM lists LEFT OUTER JOIN todos ON lists.id = todos.list_id
      GROUP BY lists.id
      ORDER BY lists.name;
    SQL
    todo_list_info = query(select_all_query)
    todo_list_info.map do |tuple|
      build_list(tuple)
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

  def update_todo_status(list_id, todo_id, new_status)
    update_sql = 'UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3;'
    query(update_sql, new_status, todo_id, list_id)
  end

  def mark_all_complete(list_id)
    query('UPDATE todos SET completed = true WHERE list_id = $1;', list_id)
  end

  def todo_name(list_id, todo_id)
    query('SELECT name FROM todos WHERE id = $1 AND list_id = $2;', todo_id, list_id)[0]['name']
  end

  def delete_todo(list_id, todo_id)
    query('DELETE FROM todos WHERE id = $1 AND list_id = $2;', todo_id, list_id)
  end

  def disconnect
    @db.close
  end

  private

  def build_list(list_info)
    { id: list_info['id'].to_i,
      name: list_info['name'],
      todos_count: list_info['todos_count'].to_i,
      todos_remaining_count: list_info['todos_remaining_count'].to_i }
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
    @logger.info("#{statement}: #{params}".gsub(/\s+/, ' '))
    @db.exec(statement, params)
  end
end
