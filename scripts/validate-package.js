import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(__dirname, '..')
const tauriDir = path.join(rootDir, 'src-tauri')
const bundleDir = path.join(tauriDir, 'target', 'release', 'bundle')
const config = JSON.parse(
  fs.readFileSync(path.join(tauriDir, 'tauri.conf.json'), 'utf8')
)

function assertFile(filePath, description, signature) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${description} no encontrado: ${filePath}`)
  }

  const contents = fs.readFileSync(filePath)
  if (contents.length === 0) {
    throw new Error(`${description} está vacío: ${filePath}`)
  }
  if (signature && !signature(contents)) {
    throw new Error(`${description} tiene un formato inválido: ${filePath}`)
  }
}

function listFiles(directory) {
  if (!fs.existsSync(directory)) return []

  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const entryPath = path.join(directory, entry.name)
    return entry.isDirectory() ? listFiles(entryPath) : [entryPath]
  })
}

function validate() {
  if (!config.bundle?.active || !Array.isArray(config.bundle.icon)) {
    throw new Error('El empaquetado Tauri o su lista de iconos no está configurado')
  }

  for (const relativePath of config.bundle.icon) {
    const iconPath = path.join(tauriDir, relativePath)
    const signature = relativePath.endsWith('.ico')
      ? contents => contents.subarray(0, 4).equals(Buffer.from([0, 0, 1, 0]))
      : relativePath.endsWith('.png')
        ? contents => contents.subarray(0, 8).equals(
          Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
        )
        : relativePath.endsWith('.icns')
          ? contents => contents.subarray(0, 4).toString('ascii') === 'icns'
          : undefined
    assertFile(iconPath, 'Icono', signature)
  }

  assertFile(path.join(rootDir, 'dist', 'index.html'), 'Frontend compilado')

  const msiInstallers = listFiles(path.join(bundleDir, 'msi'))
    .filter(filePath => path.extname(filePath).toLowerCase() === '.msi')
  const nsisInstallers = listFiles(path.join(bundleDir, 'nsis'))
    .filter(filePath => path.extname(filePath).toLowerCase() === '.exe')
  if (msiInstallers.length === 0 || nsisInstallers.length === 0) {
    throw new Error(
      `Se esperaban instaladores MSI y NSIS en ${bundleDir}. ` +
      `MSI: ${msiInstallers.length}, NSIS: ${nsisInstallers.length}`
    )
  }

  console.log('Empaquetado Windows validado:')
  msiInstallers.concat(nsisInstallers).forEach(filePath => {
    console.log(`- ${path.relative(rootDir, filePath)}`)
  })
}

try {
  validate()
} catch (error) {
  console.error(`Error validando el paquete: ${error.message}`)
  process.exitCode = 1
}
