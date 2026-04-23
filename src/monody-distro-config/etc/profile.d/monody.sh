# Enable global menus for GTK applications
export GTK_MODULE_PATH="${GTK_MODULE_PATH:+$GTK_MODULE_PATH:}appmenu-gtk-module"
export GTK_MODULES="${GTK_MODULES:+$GTK_MODULES:}appmenu-gtk-module"
export UBUNTU_MENUPROXY=1

# Ensure Qt5/Qt6 applications pick up the global menu and GTK themes
export QT_QPA_PLATFORMTHEME=gtk2
# Use the appmenu proxy for Qt when possible
export QT_MENUBAR_NO_NATIVE=0

# Enable JAyatana for global menus in Java Swing applications
export _JAVA_OPTIONS="${_JAVA_OPTIONS} -javaagent:/usr/share/java/jayatanaag.jar"
export JAYATANA_FORCE=1
