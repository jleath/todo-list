require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = [
    {name: "Lunch Groceries", todos: []},
    {name: "Dinner Groceries", todos: []}
  ]
  erb :lists, layout: :layout
end
