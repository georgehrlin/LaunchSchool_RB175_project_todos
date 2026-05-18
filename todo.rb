require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubi"
require "securerandom"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

helpers do
  def generate_class_complete(list)
    if list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] }
      "complete"
    end
  end

  def complete_list?(list)
    list[:todos].all? { |todo| todo[:completed] }
  end

  def incomplete_list?(list)
    !complete_list?(list)
  end

  def empty_list?(list)
    list[:todos].empty?
  end

  def generate_todos_fraction(list)
    todos = list[:todos]
    "#{todos.count { |todo| !todo[:completed] }} / #{ todos.size }"
  end

  def sort_lists(lists, &block)
    incomplete_lists, complete_lists = lists.partition { |list| incomplete_list?(list) || empty_list?(list) }

    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    complete_lists.each { |list| yield(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    incomplete_todos, complete_todos = todos.partition { |todo| !todo[:completed] }

    incomplete_todos.each { |todo| yield(todo, todos.index(todo)) }
    complete_todos.each { |todo| yield(todo, todos.index(todo)) }
  end

=begin
  # My own attempt at Assignment 24
  def sort_lists_complete_first_incomplete_last(lists)
    lists.sort do |a, b|
      if incomplete_list?(a) && complete_list?(b)
        -1
      elsif complete_list?(a) && incomplete_list?(b)
        1
      elsif empty_list?(a) && empty_list?(b)
        0
      elsif empty_list?(a)
        -1
      elsif empty_list?(b)
        1
      else
        0
      end
    end
  end

  # My own attempt at Assignment 24
  def sort_todos_complete_first_incomplete_last(todos)
    todos.sort do |a, b|
      if !a[:completed] && b[:completed]
        -1
      elsif a[:completed] && !b[:completed]
        1
      else
        0
      end
    end
  end
=end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

def sort_lists_complete_first_incomplete_last!(lists)
  lists.sort! do |list_a, list_b|
    if complete_list?(list_a) && !complete_list?(list_b)
      1
    elsif !complete_list?(list_a) && complete_list?(list_b)
      -1
    else
      0
    end
  end
end

def sort_todos_complete_first_incomplete_last!(todos)
  todos.sort! do |todo_a, todo_b|
    if todo_a[:completed] && !todo_b[:completed]
      1
    elsif !todo_a[:completed] && todo_b[:completed]
      -1
    else
      0
    end
  end
end

def sort_complete_first_incomplete_last!(array)
  array.sort! do |a, b|
    if yield(a) && !yield(b)
      1
    elsif !yield(a) && yield(b)
      -1
    else
      0
    end
  end
end

# Return an error message if the name is invalid. Return nil if name is valid
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

def error_for_todo_name(name)
  if !(1..100).cover?(name.size)
    "Todo name must be between 1 and 100 characters."
  end
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a list's todos
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Enter the page to edit an existing list
get "/lists/:id/edit_list" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Edit a list's name
post "/lists/:id" do
  @list_id = params[:id].to_i
  new_list_name = params[:list_name].strip
  @list = session[:lists][@list_id]
  error = error_for_list_name(new_list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = "The list name has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a list
post "/lists/:id/delete" do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to the list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_text = params[:todo].strip
  error = error_for_todo_name(todo_text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_text, completed: false }
    session[:success] = "The new todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Mark a todo as complete or incomplete
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_index].to_i
  intended_state_of_completion = params[:completed] == "true"

  @list[:todos][todo_id][:completed] = intended_state_of_completion
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos of the list as complete
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been marked complete."
  redirect "/lists/#{@list_id}"
end

# Delete a todo from the list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  todo_to_be_deleted = @list[:todos][todo_id][:name]

  @list[:todos].delete_at(todo_id)
  session[:success] = "The \"#{todo_to_be_deleted}\" todo has been deleted."
  redirect "/lists/#{@list_id}"
end