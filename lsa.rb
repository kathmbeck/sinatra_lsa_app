require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development? 
require 'tilt/erubis'
require 'bcrypt'
require 'yaml'
require 'require_all'

require_all 'lib'

configure do
  enable :sessions
  set :session_secret, 'secret lsa'
end


before do
  session[:clients] ||= []
end

def require_signed_in_user
  unless user_signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def user_signed_in?
  session.key?(:username)
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/user_credentials.yml", __FILE__)
  else
    File.expand_path("../user_credentials.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def retrieve_sample_client
  {name: "Sample Client", years: "4", months: "4", transcript: SAMPLE_TRANSCRIPT}
end

def error_for_client_name(name)
  if name.empty?
    'You must enter a name.'
  elsif session[:clients].any? { |client| client[:name] == name }
    'That name is already taken.'
  end
end

def error_for_client_age(years, months)
  if years < 3 || years >= 8 || months < 0 || months > 11
    'Age must be between 3 years and 7 years, 11 months. Enter a value between 3 and 7 for years and a value between 0 and 11 for months.'
  elsif years.to_i != years || months.to_i != months
    'Please enter positive integer values only for age.'
  end
end

get '/' do
  redirect '/clients'
end

get '/clients' do
  erb :home
end

# Render the new client form:
get '/clients/new' do
  require_signed_in_user
  erb :new_client
end

# Add new client
post '/clients' do
  require_signed_in_user

  client_name = params[:client_name]
  years = params[:years]
  months = params[:months]
  error = error_for_client_name(client_name) || error_for_client_age(years.to_f, months.to_f)
  if error
    session[:error] = error
    erb :new_client
  else
    session[:success] = 'The client has been added.'
    session[:clients] << {name: client_name, years: years, months: months, transcript: []}
    redirect '/clients'
  end
end

# Render transcript page for indivdual client
get '/clients/:name/transcript' do
  require_signed_in_user
  @name = params[:name]
  @client = session[:clients].find { |client| client[:name] == @name }
  erb :client
end

# Delete client
post '/clients/:name/destroy' do
  require_signed_in_user

  name = params[:name]
  session[:clients].delete_if { |client| client[:name] == name }
  session[:success] = "Client has been deleted."
  redirect "/clients"
end

# Add new utterance to transcript
post '/clients/:name/transcript' do
  require_signed_in_user

  @name = params[:name]
  utterance = params[:utterance]
  @client = session[:clients].find { |client| client[:name] == @name }
  @client[:transcript] << utterance
  session[:success] = 'Utterance has been added.'
  redirect "/clients/#{@name}/transcript"
end

# Update utterance already in transcript
post '/clients/:name/transcript/:index' do
  require_signed_in_user

  @name = params[:name]
  utterance = params[:utterance]
  index = params[:index].to_i
  @client = session[:clients].find { |client| client[:name] == @name }
  @client[:transcript][index] = utterance
  session[:success] = 'Utterance has been updated.'
  redirect "/clients/#{@name}/transcript"
end

# Delete utterance
post '/clients/:name/transcript/:index/destroy' do
  require_signed_in_user

  @name = params[:name]
  index = params[:index].to_i
  @client = session[:clients].find { |client| client[:name] == @name }
  @client[:transcript].delete_at(index)

  session[:success] = 'Utterance has been deleted.'
  redirect "/clients/#{@name}/transcript"
end

# View language sample analysis
get '/clients/:client/transcript/analysis' do
  require_signed_in_user
  @name = params[:client].to_s
  if @name == "Sample Client"
    @client = retrieve_sample_client
  else
    @client = session[:clients].find { |client| client[:name] == @name }
  end
  @transcript = @client[:transcript]
  @language_analysis = { "Total Number Words (TNW)" => total_word_count(@transcript),
                         "Number of Different Words (NDW)" => total_different_words(@transcript),
                         "Type Token Ratio (TTR)" => type_token_ratio(@transcript),
                         "Mean Length of Utterance (MLU)" => calculate_mlu(@transcript)
                       }
  @mean_mlu = find_mean_mlu_for_age(@client[:years].to_i, @client[:months].to_i)
  erb :analysis
end

#view transcription rules
get '/transcription_guide' do
  erb :transcription_guide
end

#view signin page 
get '/signin' do
  erb :signin
end

#verify credentials
post '/signin' do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

#signout from app 
get '/signout' do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect  "/"
end

