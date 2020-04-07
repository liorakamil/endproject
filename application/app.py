from flask import Flask, render_template, request, redirect
from flaskext.mysql import MySQL
from config import configure

app = Flask(__name__)

# Configure db
configure(app)

mysql = MySQL()
mysql.init_app(app)


@app.route('/', methods=['POST'])
def index_post():
    #fetch form data
    userDetails = request.form
    print("Details - %s" % userDetails)
    name = userDetails['name']
    email = userDetails['email']
    cur = mysql.get_db().cursor()
    cur.execute("insert into users(name, email) VALUES(%s, %s)",(name,email))
    mysql.get_db().commit()
    cur.close()
    return redirect('/users')


@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


@app.route('/users')
def users():
    cur = mysql.get_db().cursor()
    cur.execute("SELECT * FROM users")
    userDetails = cur.fetchall()
    return render_template('users.html',userDetails=userDetails)
    #return render_template('index.html')


if __name__ == '__main__':
    app.run(debug=True)