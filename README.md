Este proyecto permite ejecutar minecraft sin cuenta oficial y sin acceso a internet,
El juego usa java 25
se usa dentro de la carpeta ".minecraft" y esta necesita tener todos los archivos del juego

uso
solo linux debian o compatibles
crear carpeta /mnt/raid0/.minecraft
da permisos averiguando el usuario
whoami
id
si sale por ejemplo: esteban
entonces: sudo chown -R esteban:esteban /mnt/raid0/.minecraft
instala version de minecraft con
portablemc --work-dir /mnt/raid0/.minecraft start 26.3 
copia ./minecraft.sh adentro de .minecraft
ejecuta con el comando
./minecraft.sh Esteban 1536m 800 600 26.3
paremetro
Esteban 1536m 800 600 26.3
Usuario  RAM   Resolu. Vercion

