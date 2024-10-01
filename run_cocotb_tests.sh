#!/bin/bash

# Obtener el nombre del test para informar qué test pasó o falló
TEST_NAME=$3

# Si no se proporciona un nombre de test, se intenta capturar el nombre del archivo en ejecución
if [ -z "$TEST_NAME" ]; then
    # Asume que el archivo de test se está ejecutando desde la ruta relativa a `tests/`
    TEST_NAME=$(basename "$0" .sh)  # Captura el nombre del archivo de este script sin la extensión .sh
fi

# Aquí usamos $TEST_NAME para informar qué test falló
echo "El test que falló es: $TEST_NAME"

# Verificar si se especifica un DUT
if [ ! -z $1 ]; then
    DUT="--dut $1"
fi

# Verificar si se especifica WAVES
if [ ! -z $2 ]; then
    WAVES="--waves"
fi

# Establecer el PYTHONPATH
export PYTHONPATH=tests/

# Ejecutar los tests y verificar el resultado
python3 run_tests.py $DUT $WAVES


if [ $? -ne 0 ]; then
    # Si hay un error, crear un archivo para enviar el mensaje al workflow
    echo "failure_message=El test ${TEST_NAME} ha fallado durante la ejecución." >> $GITHUB_ENV
    exit 1
else
    echo "success_message=El test ${TEST_NAME} ha pasado correctamente." >> $GITHUB_ENV
fi