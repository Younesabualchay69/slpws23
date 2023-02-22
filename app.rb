require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'


enable :sessions

def grab_db()
    db = SQLite3::Database.new("db/data.db")
    db.results_as_hash = true
    return db
end

def getAnv()
    if session[:id] == nil then
        return nil
    end
    uid = session[:id].to_i
    db = grab_db()
    return db.execute("SELECT * FROM users WHERE id = ?", uid).first
end

get('/') do
    redirect('/products')
end

get('/products') do
    slim(:"products/index", locals:{user:getAnv()})
end    

get('/register') do
    slim(:register, locals:{user:getAnv()})
end


get('/showlogin') do
    slim(:login, locals:{user:getAnv()})
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

        redirect('/')
    else 
        "fel lösen!"
    end

end

get('/logout') do
    session[:id] = nil
    redirect('/')
end
  

get("/todos") do
    id = session[:id].to_i
    db = SQLite3::Database.new('db/data.db')
    db.results_as_hash = true 
    result = db.execute("SELECT * FROM todos WHERE user_id = ?", id)
    p "alla todos från result #{result}"
    slim(:"todos/index",locals:{todos:result})
  
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