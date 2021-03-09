class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def create_new_list(list_name)
    list_id = next_element_id(all_lists)
    @session[:lists] << {id: list_id, name: list_name, todos: []}
  end

  def delete_list(list_id)
    @session[:lists].reject! { |list| list[:id] == list_id }
  end

  def find_list(list_id)
    @session[:lists].find { |list| list[:id] == list_id }
  end

  def find_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].find { |todo| todo[:id] == todo_id }
  end

  def all_lists
    @session[:lists]
  end

  def update_list_name(list_id, new_name)
    find_list(list_id)[:name] = new_name
  end

  def create_new_todo(list_id, todo_text)
    list = find_list(list_id)
    new_todo_id = next_element_id(list[:todos])
    list[:todos] << { id: new_todo_id, name: todo_text, completed: false }
  end

  def update_todo_status(list_id, todo_id, new_status)
    find_todo(list_id, todo_id)[:completed] = new_status
  end

  def mark_all_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  def todo_name(list_id, todo_id)
    find_todo(list_id, todo_id)[:name]
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  private

  def next_element_id(elements)
    (elements.map { |element| element[:id]}.max || 0) + 1
  end
end