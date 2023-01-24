require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'


enable :sessions



get('/') do
    slim(:register)
end


get('/showlogin') do
    slim(:login)
end
  
  
post('/login') do

    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new('db/data.db')
    db.results_as_hash = true 
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]

    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id

        redirect('/todos')
    else 
        "fel lösen!"
    end

end
  

post('/users/new') do

    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
  
    if password == password_confirm
      #lägg till användare
      password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new('db/data.db')
      db.execute("INSERT INTO users(username,pwdigest) VALUES (?,?)",username,password_digest)
      redirect("/")
    else 
      #felhantering
    
    end
  
  end