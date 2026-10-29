from pathlib import Path
from pypdf import PdfWriter

# Directorio actual
directorio = Path.cwd()

# Nombre del PDF final
archivo_salida = directorio / "Documento_Completo.pdf"

# Buscar todos los PDF en carpetas y subcarpetas
archivos_pdf = sorted(directorio.rglob("*.pdf"))

# Excluir el PDF final para evitar unirlo consigo mismo
archivos_pdf = [
    archivo for archivo in archivos_pdf
    if archivo.resolve() != archivo_salida.resolve()
]

# Verificar que existan archivos PDF
if not archivos_pdf:
    print("No se encontraron archivos PDF.")
    exit()

# Crear el documento final
writer = PdfWriter()

for archivo_pdf in archivos_pdf:
    try:
        writer.append(str(archivo_pdf))
        print(f"Agregado: {archivo_pdf.relative_to(directorio)}")

    except Exception as e:
        print(f"Error al agregar {archivo_pdf}: {e}")

# Guardar el documento completo
with open(archivo_salida, "wb") as archivo:
    writer.write(archivo)

writer.close()

print(f"\n¡PDF generado correctamente!")
print(f"Archivo: {archivo_salida}")