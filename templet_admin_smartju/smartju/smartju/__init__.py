# Enable PyMySQL shim when using MySQL
try:
	import pymysql
	pymysql.install_as_MySQLdb()
except Exception:
	# pymysql may not be installed in all environments; ignore if missing
	pass

