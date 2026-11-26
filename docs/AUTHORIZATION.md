# Autorización por aplicación

Esta matriz es una base para el diseño; no sustituye permisos de servidor. La
app móvil aún no se conecta a Supabase. Los permisos finales dependen de roles,
políticas RLS y funciones transaccionales aprobadas.

| Perfil / contexto | Acceso objetivo |
|---|---|
| Administrador | Configuración organizacional, perfiles, terminales y aprobaciones |
| Gerente | Dashboard, ventas, reportes, inventario y auditoría según alcance |
| Cajero | Operaciones de caja y venta permitidas en su terminal |
| Cocina / Barra | Comandas de su estación y transiciones autorizadas |
| Cliente | Menú público y sus propios pedidos; sin acceso a datos operativos |
| Tablet de cliente | Menú y pedidos limitados a la sucursal y ubicación vinculadas |

## Reglas obligatorias

- Denegar por defecto y conceder el mínimo privilegio.
- Aplicar la autorización en el backend/RLS y volver a validar en cada mutación.
- Vincular la sesión a organización, sucursal y terminal cuando corresponda.
- Registrar actor, terminal, acción y motivo para operaciones administrativas.
- No elevar permisos confiando en el rol enviado por el cliente.
- Separar la experiencia de autoservicio de las sesiones de personal.

Para la autenticación local actual del POS y la política global, consulta
[SECURITY.md](../SECURITY.md). La configuración remota se mantiene pendiente.
