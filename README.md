# SmartCityCE








probar los tests para SQL
para instalar los datos 
usar scripts/download_datasets.py 


para crear el usuario y la BASE de datos smartcityce (Antes hay que poner la contrasena dentro del script)

bash scripts/setup_database.sh


desde la raiz 
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_schema.sql



cargar datos

python scripts/load_postgresql.py --phase metadata


