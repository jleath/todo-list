require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'lib/session_persistence'
require_relative 'lib/database_persistence'

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, 'secret'
end

before do
  @storage = DatabasePersistence.new
end

helpers do
  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each(&block)
    complete.each(&block)
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }

    incomplete.each(&block)
    complete.each(&block)
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
  @lists = @storage.all_lists
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
    @storage.create_new_list(list_name);
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
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post '/lists/:id/delete' do
  @storage.delete_list(params[:id].to_i)
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == 'XMLHttpRequest'
    "/lists"
  else
    redirect "/lists"
  end
end

# Delete a todo list item
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  todo_name = @storage.todo_name(@list_id, todo_id) 

  @storage.delete_todo(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = "'#{todo_name}' has been deleted."
    erb :list, layout: :layout
  end
end

# update the status of a todo
post '/lists/:list_id/todos/:todo_id/check' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  todo_name = @storage.todo_name(@list_id, todo_id)
  new_status = params[:completed] == 'true'

  @storage.update_todo_status(@list_id, todo_id, new_status)

  session[:success] = "'#{todo_name}' has been updated."
  redirect "/lists/#{@list_id}"
end

# complete all todos in a list
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_complete(@list_id)

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

# add a todo list item
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip
  error = todo_name_error(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
    session[:success] = "'#{text}' has been added to the list."
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
  p @list
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
  list = @storage.find_list(list_id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# Return an error message if list_name is invalid. Otherwise, return nil.
def list_name_error(name)
  if !(1..100).cover?(name.size)
    'The list name must be between 1 and 100 characters in length.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
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