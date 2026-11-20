class PrintingService {
  async printElement(
    htmlContent: string, 
    title: string = 'Documento',
    width: 58 | 80 = 58
  ): Promise<boolean> {
    try {
      // Crear una nueva ventana para impresión
      const printWindow = window.open('', '_blank', 'width=800,height=600')
      
      if (!printWindow) {
        throw new Error('No se puede abrir la ventana de impresión. Verifique si hay un bloqueador de ventanas emergentes.')
      }

      // Escribir el contenido HTML
      printWindow.document.write(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>${title}</title>
          <style>
            @page {
              margin: 0;
              size: ${width}mm auto;
            }
            
            body {
              margin: 0;
              padding: 5px;
              font-family: 'Courier New', monospace;
              background: white;
              color: black;
            }
            
            @media print {
              body {
                print-color-adjust: exact;
                -webkit-print-color-adjust: exact;
              }
            }
          </style>
        </head>
        <body>
          ${htmlContent}
        </body>
        </html>
      `)

      printWindow.document.close()

      // Esperar a que se cargue el contenido
      await new Promise(resolve => setTimeout(resolve, 500))

      // Enfocar la ventana e imprimir
      printWindow.focus()
      
      // Intentar imprimir
      const success = await this.waitForPrint(printWindow)
      
      if (success) {
        // Cerrar la ventana después de imprimir
        setTimeout(() => {
          printWindow.close()
        }, 1000)
      }

      return success
    } catch (error) {
      console.error('Error en printElement:', error)
      return false
    }
  }

  private async waitForPrint(printWindow: Window): Promise<boolean> {
    return new Promise((resolve) => {
      // Verificar que el documento esté listo
      if (printWindow.document.readyState === 'complete') {
        printWindow.print()
        resolve(true)
      } else {
        printWindow.onload = () => {
          printWindow.print()
          resolve(true)
        }
      }

      // Timeout de seguridad
      setTimeout(() => {
        resolve(false)
      }, 5000)
    })
  }

  async printThermalTicket(
    width: 58 | 80, 
    content: string
  ): Promise<boolean> {
    return this.printElement(content, 'Ticket Térmico', width)
  }

  // Función para previsualizar en una nueva pestaña
  previewInNewTab(htmlContent: string, title: string = 'Vista Previa') {
    const previewWindow = window.open('', '_blank', 'width=800,height=600')
    
    if (!previewWindow) {
      throw new Error('No se puede abrir la ventana de previsualización')
    }

    previewWindow.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>${title}</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #f5f5f5;
          }
          
          .preview-container {
            max-width: 400px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          }
          
          .preview-header {
            text-align: center;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #ddd;
          }
          
          .preview-title {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 5px;
          }
          
          .preview-subtitle {
            font-size: 14px;
            color: #666;
          }
          
          .preview-content {
            border: 1px solid #ddd;
            padding: 15px;
            border-radius: 4px;
            background: #fafafa;
          }
          
          .print-button {
            margin-top: 15px;
            padding: 10px 20px;
            background: #007bff;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
          }
          
          .print-button:hover {
            background: #0056b3;
          }
        </style>
      </head>
      <body>
        <div class="preview-container">
          <div class="preview-header">
            <div class="preview-title">${title}</div>
            <div class="preview-subtitle">Vista Previa de Impresión</div>
          </div>
          
          <div class="preview-content">
            ${htmlContent}
          </div>
          
          <button class="print-button" onclick="window.print()">
            Imprimir
          </button>
        </div>
      </body>
      </html>
    `)

    previewWindow.document.close()
  }
}

export default new PrintingService()