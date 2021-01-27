require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
end

helpers do
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = partition_with_index(lists) do |list|
      list_complete?(list)
    end

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = partition_with_index(todos) do |todo|
      todo[:completed]
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def list_complete?(list)
    list_size(list) > 0 && num_complete(list) == list_size(list)
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def num_complete(list)
    list[:todos].select { |todo| todo[:completed] }.size
  end

  def list_size(list)
    list[:todos].size
  end
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  erb :lists, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = list_name_error(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @lists << { name: list_name, todos: [] }
    session[:success] = "The list \"#{list_name}\" has been created."
    redirect '/lists'
  end
end

# Change the name of an existing list
post '/lists/:id' do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  error = list_name_error(list_name)
  if list_name == @list[:name]
    redirect "/lists/#{@list_id}"
  elsif error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post '/lists/:id/delete' do
  @lists.delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Delete a todo list item
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  todo_name = @list[:todos][todo_id][:name]
  @list[:todos].delete_at(todo_id)
  session[:success] = "'#{todo_name}' has been deleted."
  erb :list, layout: :layout
end

# update the status of a todo
post '/lists/:list_id/todos/:todo_id/check' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo = @list[:todos][params[:todo_id].to_i]
  todo[:completed] = (params[:completed] == "true" ? true : false)
  session[:success] = "'#{todo[:name]}' has been updated."
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

# add a todo list item
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo = params[:todo].strip
  error = todo_name_error(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    session[:success] = "'#{todo}' has been added to the list."
    redirect "lists/#{@list_id}"
  end
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Render the single list view
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  if @list.nil?
    session[:error] = "The specified list was not found."
    redirect "/lists"
  else
    erb :list, layout: :layout
  end
end

# Render edit list view
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

private

def load_list(list_id)
  list = @lists[list_id]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# Return an error message if list_name is invalid. Otherwise, return nil.
def list_name_error(name)
  if !(1..100).cover?(name.size)
    'The list name must be between 1 and 100 characters in length.'
  elsif @lists.any? { |list| list[:name] == name }
    'The list name must be unique.'
  else
    nil
  end
end

def todo_name_error(name)
  if !(1..100).cover?(name.size)
    'The todo name must be between 1 and 100 characters in length.'
  else
    nil
  end
end

def partition_with_index(container)
  true_values = {}
  false_values = {}

  container.each_with_index do |item, index|
    truth_value = block_given? ? yield(item) : !!item
    if truth_value
      true_values[item] = index
    else
      false_values[item] = index
    end
  end
  [true_values, false_values]
end