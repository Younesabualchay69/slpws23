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
    return db.execute("SELECT * FROM users WHERE id = ?", uid).first  #Hämtar data för den inloggade personen
end

get('/') do
    redirect('/products')
end

get('/products') do
    db = grab_db()
    products = db.execute("SELECT * FROM products")
    slim(:"products/index", locals:{user:getAnv(), products:products})
    
end  

get('/products/:id') do
id = params[:id]
db = grab_db()
product = db.execute("SELECT * FROM products WHERE id = ?",id.to_i).first
slim(:"products/show", locals:{user:getAnv(), product:product})
end

get('/products/:id/edit') do
    id = params[:id].to_i
    db = grab_db()
    product = db.execute("SELECT * FROM products WHERE id = ?",id).first
    slim(:"/products/edit",locals:{user:getAnv(), product:product})
  
  end

post('/products/:id/update') do

    id = params[:id]
    db = grab_db()
    product = db.execute("SELECT * FROM products WHERE id = ?",id.to_i).first
   # is_admin = db.execute("SELECT * FROM users WHERE is_admin = 1",id.to_i).first
    name = params[:name]
    db.execute("UPDATE products SET name=? WHERE id = ?",name,id)
    slim(:"products/show", locals:{user:getAnv(), product:product})
    redirect('/products/:id')
end

get('/products/new') do
    slim(:"products/new", locals:{user:getAnv()})
end
  
post('/products/new') do
    db = grab_db()
    name = params[:name]
    id = params[:id].to_i
    p "vi fick ut datan #{name} och #{id}"

    db.execute("INSERT INTO products (name) VALUES ('?')",name)
    redirect('/products')
  
  end


get('/cart') do
    usr = getAnv()
    db = grab_db()
    cart = db.execute("SELECT * FROM cart WHERE user_id=?", usr["id"])
    slim(:"cart/index", locals:{user:getAnv(), cart:cart})
end  


post("/cart") do
    usr_id = session[:id].to_i
    prod_id = params["product_id"]
    db = grab_db()
    result = db.execute("SELECT * FROM cart WHERE user_id=? AND product_id=?", usr_id, prod_id)
    if result.length > 0 then
      db.execute("UPDATE cart SET items = ? WHERE user_id=? AND product_id=?", result[0]["items"] + 1, usr_id, prod_id)
    else
      db.execute("INSERT INTO cart (user_id,product_id) VALUES (?,?)", usr_id, prod_id)
    end
    redirect('/products')
end

post("/cart/delete") do
    usr_id = session[:id].to_i
    prod_id = params["prod_id"]
    db = grab_db()
    result = db.execute("SELECT items FROM cart WHERE user_id=? AND product_id=?", usr_id, prod_id).first
    if result["items"].to_i > 1 then
        db.execute("UPDATE cart SET items=? WHERE user_id=? AND product_id=?", result["items"].to_i - 1, usr_id, prod_id)
    else        
        result = db.execute("DELETE FROM cart WHERE user_id=? AND product_id=?", usr_id, prod_id)
    end
    redirect '/cart'
  end
  
get('/cart/purchase') do 
    db = grab_db()   
    usr = getAnv()
    cart = db.execute("SELECT * FROM cart WHERE user_id=?", usr["id"])
 
    slim(:"cart/purchase", locals:{user:getAnv(), cart:cart})
end

post('/cart/purchase') do
    "Hello World"

    #db = grab_db()
    #name = params[:name]
   # id = params[:id].to_i
  #  p "vi fick ut datan #{name} och #{id}"

   # db.execute("INSERT INTO products (name) VALUES ('?')",name)

end


get('/profile') do 
    usr_id = session[:id].to_i
    prod_id = params["prod_id"]
    reciept = db.execute("SELECT * FROM reciept WHERE user_id=?", usr["id"])
    slim(:"profile/index", locals:{user:getAnv(), profile:reciept})


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



