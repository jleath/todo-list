require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = session[:lists]
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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list \"#{list_name}\" has been created."
    redirect '/lists'
  end
end

# Change the name of an existing list
post '/lists/:id' do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
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
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Delete a todo list item
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  todo_name = @list[:todos][todo_id][:name]
  @list[:todos].delete_at(todo_id)
  session[:success] = "'#{todo_name}' has been deleted."
  erb :list, layout: :layout
end

# update the status of a todo
post '/lists/:list_id/todos/:todo_id/check' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo = @list[:todos][params[:todo_id].to_i]
  todo[:completed] = (params[:completed] == "true" ? true : false)
  session[:success] = "'#{todo[:name]}' has been updated."
  @list[:todos].sort! { |a, b| a[:completed].to_s <=> b[:completed].to_s }
  redirect "/lists/#{@list_id}"
end

# add a todo list item
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo = params[:todo].strip
  error = todo_name_error(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    @list[:todos].sort! { |a, b| a[:completed].to_s <=> b[:completed].to_s }
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
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Render edit list view
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

private

# Return an error message if list_name is invalid. Otherwise, return nil.
def list_name_error(name)
  if !(1..100).cover?(name.size)
    'The list name must be between 1 and 100 characters in length.'
  elsif session[:lists].any? { |list| list[:name] == name }
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
