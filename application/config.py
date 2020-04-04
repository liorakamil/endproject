import os

mysql_host = os.getenv("MYSQL_HOST")
mysql_user = os.getenv("MYSQL_USER")
mysql_password = os.getenv("MYSQL_PASSWORD")
mysql_db = 'users'


def configure(app):
    app.config['MYSQL_DATABASE_HOST'] = mysql_host
    app.config['MYSQL_DATABASE_USER'] = mysql_user
    app.config['MYSQL_DATABASE_PASSWORD'] = mysql_password
    app.config['MYSQL_DATABASE_DB'] = mysql_db