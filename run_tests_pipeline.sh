#!/bin/bash

# Lista de archivos de tests en la carpeta 'tests/'
TEST_FILES=$(ls tests/*.py)

for TEST_FILE in $TEST_FILES; do
    # Obtener el nombre del test
    TEST_NAME=$(basename $TEST_FILE .py)

    echo "Ejecutando test: $TEST_NAME"
    
    # Ejecutar el test específico usando el script que ya se tiene
    ./run_cocotb_tests.sh $TEST_NAME

    # Verificar si el test falló
    if [ $? -ne 0 ]; then
        echo "El test $TEST_NAME falló. Deteniendo la ejecución."
        exit 1  # Detener el script si un test falla
    fi
done

echo "Todos los tests han pasado correctamente."
exit 0
