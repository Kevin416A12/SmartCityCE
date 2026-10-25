psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_schema.sql