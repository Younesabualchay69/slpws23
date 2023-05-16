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

def admin()
    if session[:id]
        db = grab_db()
        uid = session[:id].to_i
        return db.execute("SELECT is_admin FROM users WHERE id = ?", uid).first["is_admin"] == 1
    end
    return false
end  



get('/') do
    redirect('/products')
end

get('/products') do
    db = grab_db()
    products = db.execute("SELECT products.*,suppliers.name as supplier_name FROM products INNER JOIN suppliers ON products.supplier_id = suppliers.id")
    slim(:"products/index", locals:{user:getAnv(),admin:admin(), products:products})
    
end  

get('/products/:id') do
id = params[:id]
db = grab_db()
product = db.execute("SELECT * FROM products WHERE id = ?",id.to_i).first
slim(:"products/show", locals:{user:getAnv(), product:product})
end

get('/not_admin') do
    return "Wallah på gud mannen du får inte vara i mina områden"
end

# match all routes that starts with products, has an id, and ends with something, ex: /products/34/edit
before('/products/*/*') do
    if !admin() then
        redirect("/not_admin")
    end
end
before('/products/new') do
    if !admin() then
        redirect("/not_admin")
    end
end

get('/products/:id/edit') do
    id = params[:id].to_i
    db = grab_db()
    product = db.execute("SELECT * FROM products WHERE id = ?",id).first
    return slim(:"/products/edit",locals:{user:getAnv(), product:product})
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
    cart = db.execute("SELECT cart.*,products.name as product_name FROM cart INNER JOIN products ON cart.product_id=products.id WHERE cart.user_id=?", usr["id"])
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
  
def create_order(uid)
    db = grab_db()
    cart = db.execute("SELECT product_id,items FROM cart WHERE user_id=?", uid);
    if cart.length > 0 then
      db.execute("INSERT INTO orders (user_id,date) VALUES (?,?)", uid, Time.now.to_i)
      order_id = db.last_insert_row_id
      cart.each do |item|
        db.execute("INSERT INTO orders_products (order_id, product_id, items) VALUES (?,?,?)", order_id, item["product_id"], item["items"]);
        db.execute("DELETE FROM cart WHERE user_id=? AND product_id=?", uid, item["product_id"])
      end
      return db.last_insert_row_id
    end
    return -1
end

post('/cart/purchase') do 
    db = grab_db()   
    usr = getAnv()
   
    ret = create_order(usr["id"])
    if ret == -1 then
        return "du måste lägga till varor i din kundkorg!"
    end
    redirect("/orders")
end

# Skapa en hash med element i en array, värdet "id" i varje element kommer att representera nyckeln för varje element i hashen medan elementet kommer att representera värdet i hashen
def by_key(table)
  hash = {}
  for row in table do
    hash[row["id"]] = row
  end
  return hash

end

# Hämta alla products som är inkluderade i alla ordrar från en user från database
#
# @param [Integer] uid är user's ID
#
# @return [Array] en array med matchande products i databasen var och en som en hash

def get_products_linked_orders(uid)
    return grab_db().execute("SELECT products.* FROM ((products INNER JOIN orders_products ON products.id=orders_products.product_id) INNER JOIN orders ON orders_products.order_id=orders.id) WHERE orders.user_id=?", uid)
end

# Få beställningarna märkta som betalda och lägg dem i en hash där varje nyckel är ID för varje beställning
def bykey_get_orders_payed(uid)
    return by_key(grab_db().execute("SELECT * FROM orders WHERE user_id=? AND payed=1", uid))
end

# Få beställningarna markerade som ej betalda och lägg dem i en hash där varje nyckel är ID för varje beställning
def bykey_get_orders_notpayed(uid)
    return by_key(grab_db().execute("SELECT * FROM orders WHERE user_id=? AND payed=0", uid))
  end
  
  # Få en array där varje element är en beställning markerad som betald och en produkt kopplad till den, eftersom en beställning kan ha många produkter kan det finnas fler element än beställningar
  def get_orders_payed_full(uid)
    return grab_db().execute("SELECT orders.*,orders_products.product_id,orders_products.items FROM orders INNER JOIN orders_products ON orders.id=orders_products.order_id WHERE user_id=? AND payed=1", uid)
  end
  
  # Skaffa en array där varje element är en beställning markerad som ej betald och en produkt kopplad till den, eftersom en beställning kan ha många produkter kan det finnas fler element än beställningar
  def get_orders_notpayed_full(uid)
    return grab_db().execute("SELECT orders.*,orders_products.product_id,orders_products.items FROM orders INNER JOIN orders_products ON orders.id=orders_products.order_id WHERE user_id=? AND payed=0", uid)
  end



# Få beställningar vars ID finns i en godkänd array
def get_orders_products_by_ids(ids)
    return grab_db().execute("SELECT * FROM orders_products WHERE order_id IN(#{ids.join(",")})")
  end
  
  # Få en anpassad struktur inklusive betalda beställningar, ej betalda beställningar och alla produkter som ingår i alla beställningar. Varje beställning har också en lista med ID:n som är kopplade till de produkter den innehåller och som finns i produktdatalistan
  def get_orders_struct(uid)
    orders_payed = bykey_get_orders_payed(uid)
    orders_notpayed = bykey_get_orders_notpayed(uid)
    orders = {payed:orders_payed, notpayed:orders_notpayed}
  
    # Lägg till produktlänkar till beställningar
    pf = get_orders_payed_full(uid)
    if pf.length > 0 then
      pf.each do |order|
        if not orders_payed[order["id"]]["products"] then
          orders_payed[order["id"]]["products"] = []
        end
        product = {id:order["product_id"],items:order["items"]}
        orders_payed[order["id"]]["products"].append product
      end
    end
    npf = get_orders_notpayed_full(uid)
    if npf.length > 0 then
      npf.each do |order|
        if not orders_notpayed[order["id"]]["products"] then
          orders_notpayed[order["id"]]["products"] = []
        end
        product = {id:order["product_id"],items:order["items"]}
        orders_notpayed[order["id"]]["products"].append product
      end
    end
  
    products = by_key(get_products_linked_orders(uid))
  
    return {orders:orders, products:products}
  end
  
  # Ställ in beställningen som betald för en beställning
  def order_pay(uid, o_id)
    return grab_db().execute("UPDATE orders SET payed=1 WHERE user_id=? AND id=?", uid, o_id)
  end
  
  get('/orders') do
    uid = session[:id].to_i
    orders_and_products = get_orders_struct(uid)
    slim(:"orders/index", locals:{user:getAnv(), orders:orders_and_products[:orders], products:orders_and_products[:products]})
  end
  
  # Markes an order as payed
  post('/orders/:id/pay') do
    uid = session[:id].to_i
    o_id = params["id"]
  
    order_pay(uid, o_id)
    redirect('/orders')
  end
  
  get('/profile') do 
    db = grab_db()
    usr_id = session[:id].to_i
    prod_id = params["prod_id"]
    reciept = db.execute("SELECT * FROM orders_products WHERE order_id=?", usr_id)
    slim(:"profile/index", locals:{user:getAnv(), profile:reciept})
  end

# Kollar admin priviligeer för alla routes som börjar på all_orders
before("/all_orders*") do
    if !admin() then
        # Om användaren inte är admin skickas man till en annan sida som heter /permission_denied
        redirect("/permission_denied")
    end
end
  
get("/all_orders") do
    # Hämta alla användare som inte är admins
    users = grab_db().execute("SELECT * FROM users WHERE is_admin = 0")
    slim(:"all_orders/index", locals:{user:getAnv(), users:users})
end
  
get("/all_orders/:id") do
    uid = params[:id]
    user = grab_db().execute("SELECT * FROM users WHERE id = ?", uid).first
    orders_and_products = get_orders_struct(uid)
    slim(:"all_orders/user_order", locals:{user:getAnv(), order_user:user, orders:orders_and_products[:orders], products:orders_and_products[:products]})
end

get("/permission_denied") do
    "Här får du inte vara, gå <a href='/'>hem</a>"
end

post("/all_orders/:uid/:oid/delete") do
    uid = params[:uid]
    oid = params[:oid]
    user = grab_db().execute("DELETE FROM orders WHERE user_id=? AND id=?", uid, oid)
    redirect("all_orders/#{uid}")
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
        # login success

        # set id parameter from database to session hash
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



