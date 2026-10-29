import markdown2
import pdfkit
from pathlib import Path

# Directorio principal donde buscar archivos .md
directorio = Path.cwd()


# Buscar todos los archivos .md en carpetas y subcarpetas
for archivo_md in directorio.rglob("*.md"):

    # Leer el archivo Markdown
    with open(archivo_md, "r", encoding="utf-8") as file:
        markdown_text = file.read()

    # Convertir Markdown a HTML
    html_text = markdown2.markdown(
        markdown_text,
        extras=["tables", "fenced-code-blocks"]
    )

    # Crear el PDF con el mismo nombre y en la misma carpeta
    archivo_pdf = archivo_md.with_suffix(".pdf")

    # Convertir HTML a PDF
    pdfkit.from_string(
        html_text,
        str(archivo_pdf),
        options={
            "enable-local-file-access": None,
            "encoding": "UTF-8"
        }
    )

    print(f"Convertido: {archivo_md} -> {archivo_pdf}")

print("¡Todos los archivos Markdown han sido convertidos!")