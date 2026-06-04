#!/bin/bash

# --- Script de Automatización de Hosting (Con Sesiones, Dashboard y Logo) ---

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (usando sudo)."
  exit 1
fi

echo "--- NUEVO CLIENTE DE HOSTING ---"
read -p "Introduce el nombre del nuevo usuario (ej. cliente3): " USUARIO

PASSWORD=$(tr -dc 'A-Za-z0-9_@#%*+=' < /dev/urandom | head -c 16)
echo "Generando entorno seguro para $USUARIO..."

# 1. Crear usuario y directorios
if id "$USUARIO" &>/dev/null; then
    echo "¡Error! El usuario ya existe."
    exit 1
fi

useradd -m -d /home/$USUARIO -s /bin/bash $USUARIO
echo "$USUARIO:$PASSWORD" | chpasswd
mkdir -p /home/$USUARIO/site

# 1.1 Copiar el logo al sitio del cliente (Requiere que logo.jpg esté en /root/)
if [ -f "/root/logo.jpg" ]; then
    cp /root/logo.jpg /home/$USUARIO/site/logo.jpg
else
    echo "⚠️ Aviso: No se encontró /root/logo.jpg. El logo no se mostrará en la web."
fi

chown -R $USUARIO:$USUARIO /home/$USUARIO
chmod 755 /home/$USUARIO

# 2. Crear Base de Datos y Usuario MariaDB
DB_NAME="${USUARIO}_db"
mysql -e "CREATE DATABASE ${DB_NAME};"
mysql -e "CREATE USER '${USUARIO}'@'localhost' IDENTIFIED BY '${PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${USUARIO}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ==========================================
# 3A. Crear el Archivo de Login (index.php)
# ==========================================
cat <<EOF > /home/$USUARIO/site/index.php
<?php
session_start();

// Si ya hay sesión iniciada, saltar directo al dashboard
if(isset(\$_SESSION['logged_in']) && \$_SESSION['logged_in'] === true){
    header("Location: dashboard.php");
    exit;
}

\$mensaje = "";

if (\$_SERVER["REQUEST_METHOD"] == "POST") {
    \$input_user = \$_POST['username'];
    \$input_pass = \$_POST['password'];

    mysqli_report(MYSQLI_REPORT_STRICT | MYSQLI_REPORT_ALL ^ MYSQLI_REPORT_INDEX);
    try {
        \$conn = new mysqli("localhost", \$input_user, \$input_pass, "$DB_NAME");
        if (!\$conn->connect_error) {
            // ¡Éxito! Creamos la sesión y redirigimos
            \$_SESSION['logged_in'] = true;
            \$_SESSION['username'] = \$input_user;
            \$_SESSION['db_name'] = "$DB_NAME";
            
            header("Location: dashboard.php");
            exit;
        }
    } catch (Exception \$e) {
        \$mensaje = "<div class='error'><b>Acceso Denegado:</b> Credenciales incorrectas.</div>";
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Acceso Cliente | KingHosting</title>
    <style>
        body { font-family: sans-serif; background-color: #f0f2f5; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); width: 350px; text-align: center; }
        .logo { max-width: 200px; margin-bottom: 20px; }
        input { width: 90%; padding: 10px; margin: 10px 0; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
        button { background-color: #034694; color: white; padding: 10px; border: none; border-radius: 4px; width: 100%; cursor: pointer; margin-top: 10px; font-weight: bold;}
        button:hover { background-color: #022b5e; }
        .error { background-color: #ffe6e6; color: #d8000c; padding: 10px; border-radius: 4px; margin-bottom: 15px; font-size: 14px;}
    </style>
</head>
<body>
    <div class="card">
        <img src="logo.jpg" alt="KingHosting Logo" class="logo" onerror="this.style.display='none'">
        
        <h2 style="color: #034694; margin-top: 0;">Bienvenido al servicio de KingHosting grupo1</h2>
        <?php if (\$mensaje != "") echo \$mensaje; ?>
        <form method="POST">
            <input type="text" name="username" placeholder="Usuario de BD" required>
            <input type="password" name="password" placeholder="Contraseña de BD" required>
            <button type="submit">Iniciar Sesión</button>
        </form>
    </div>
</body>
</html>
EOF

# ==========================================
# 3B. Crear el Panel Dinámico (dashboard.php)
# ==========================================
cat <<EOF > /home/$USUARIO/site/dashboard.php
<?php
session_start();

// Control de seguridad: Si no hay sesión válida, expulsar al index
if(!isset(\$_SESSION['logged_in']) || \$_SESSION['logged_in'] !== true){
    header("Location: index.php");
    exit;
}

// Variables dinámicas recuperadas de la sesión
\$user_activo = \$_SESSION['username'];
\$db_activa = \$_SESSION['db_name'];
\$hora_acceso = date('H:i:s');
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Panel de Control | KingHosting</title>
    <style>
        body { font-family: sans-serif; background-color: #f0f2f5; margin: 0; }
        .navbar { background-color: #034694; color: white; padding: 15px 30px; display: flex; justify-content: space-between; align-items: center; }
        .navbar-brand { display: flex; align-items: center; font-weight: bold; font-size: 18px; }
        .navbar-logo { height: 40px; margin-right: 15px; background: white; padding: 2px; border-radius: 4px; }
        .navbar a { color: white; text-decoration: none; font-weight: bold; background-color: #d11a2a; padding: 8px 15px; border-radius: 4px;}
        .container { padding: 40px; max-width: 800px; margin: 0 auto; }
        .dashboard-card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); text-align: center; }
        .main-logo { max-width: 250px; margin-bottom: 20px; }
        .stat-box { background: #e8f0fe; padding: 15px; border-radius: 6px; margin-top: 20px; border-left: 5px solid #034694; text-align: left; }
        .btn-whatsapp { display: inline-block; background-color: #25D366; color: white; padding: 12px 20px; text-decoration: none; border-radius: 5px; font-weight: bold; margin-top: 30px; }
        .btn-whatsapp:hover { background-color: #128C7E; }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="navbar-brand">
            <img src="logo.jpg" alt="KingHosting" class="navbar-logo" onerror="this.style.display='none'">
            Panel de Administración
        </div>
        <a href="logout.php">Cerrar Sesión</a>
    </div>
    
    <div class="container">
        <div class="dashboard-card">
            <img src="logo.jpg" alt="KingHosting Logo" class="main-logo" onerror="this.style.display='none'">
            
            <h1 style="color: #333; margin-top: 0;">Bienvenido, <?php echo htmlspecialchars(\$user_activo); ?> 👋</h1>
            <p>Has iniciado sesión correctamente validando tus credenciales contra el servidor MariaDB.</p>
            
            <div class="stat-box">
                <h3>Información de tu Entorno:</h3>
                <ul>
                    <li><strong>Base de Datos Asignada:</strong> <?php echo htmlspecialchars(\$db_activa); ?></li>
                    <li><strong>Ruta en el Servidor:</strong> /home/<?php echo htmlspecialchars(\$user_activo); ?>/site</li>
                    <li><strong>Hora de inicio de sesión:</strong> <?php echo \$hora_acceso; ?></li>
                </ul>
            </div>

            <a href="https://wa.me/593967805346?text=Tengo%20un%20problema%20con%20el%20servicio" class="btn-whatsapp" target="_blank">
                💬 Tengo un problema con el servicio
            </a>
        </div>
    </div>
</body>
</html>
EOF

# ==========================================
# 3C. Crear el Archivo de Cierre (logout.php)
# ==========================================
cat <<EOF > /home/$USUARIO/site/logout.php
<?php
session_start();
// Destruir todas las variables de sesión
\$_SESSION = array();
session_destroy();
// Redirigir al inicio
header("Location: index.php");
exit;
?>
EOF

# Ajustar permisos para todos los archivos generados
chown -R $USUARIO:$USUARIO /home/$USUARIO/site/*

# 4. Configurar Nginx (Virtual Host)
CONFIG="/etc/nginx/sites-available/$USUARIO.com"

cat <<EOF > $CONFIG
server {
    listen 80;
    server_name $USUARIO.com;
    root /home/$USUARIO/site;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}
EOF

ln -sf $CONFIG /etc/nginx/sites-enabled/
systemctl reload nginx

echo ""
echo "--- PROCESO COMPLETADO ---"
echo "El cliente $USUARIO ha sido configurado con sistema de sesiones seguro."
echo "La contraseña generada es: $PASSWORD"
echo "URL local de prueba: http://$USUARIO.com"