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
  list_id = params[:id].to_i
  @list = session[:lists][list_id]
  error = list_name_error(list_name)
  if list_name = session[:lists][list_id]
    redirect "/lists/#{list_id}"
  elsif error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{list_id}"
  end
end

post '/lists/:id/delete' do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Render the single list view
get '/lists/:id' do
  list_id = params[:id].to_i
  @list = session[:lists][list_id]
  erb :list, layout: :layout
end

# Render edit list view
get '/lists/:id/edit' do
  list_id = params[:id].to_i
  @list = session[:lists][list_id]
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
